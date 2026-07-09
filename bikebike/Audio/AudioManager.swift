//
//  AudioManager.swift
//  bikebike
//

import AVFoundation
import AudioToolbox

enum RaceSound: String {
    case countdownBeep
    case goHorn
    case boost
    case collision
    case finishFanfare
    case engineLoop
}

@MainActor
final class AudioManager {
    static let shared = AudioManager()

    private var players: [RaceSound: AVAudioPlayer] = [:]
    private var boostPlayers: [String: AVAudioPlayer] = [:]
    private var enginePlayer: AVAudioPlayer?
    private var isEngineRunning = false

    private let bgmTrackNames = ["bikebike-rap", "bikebike-british-rap"]
    private var bgmPlayers: [AVAudioPlayer] = []
    private var currentBGMIndex = 0
    private var isBGMPlaying = false
    private var bgmFadeTask: Task<Void, Never>?
    private let bgmDelegate = BGMPlaybackDelegate()
    private let bgmVolume: Float = 0.5
    private let fadeDuration: TimeInterval = 0.4

    private init() {
        bgmDelegate.onTrackFinished = { [weak self] in
            Task { @MainActor in
                self?.playNextBackgroundTrack()
            }
        }
        configureSession()
        preloadSounds()
        preloadBoostSounds()
        preloadBackgroundMusic()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func preloadSounds() {
        for sound in RaceSound.allCases where sound != .engineLoop {
            if let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav", subdirectory: "Audio")
                ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") {
                players[sound] = try? AVAudioPlayer(contentsOf: url)
                players[sound]?.prepareToPlay()
            }
        }
        if let url = Bundle.main.url(forResource: RaceSound.engineLoop.rawValue, withExtension: "wav", subdirectory: "Audio")
            ?? Bundle.main.url(forResource: RaceSound.engineLoop.rawValue, withExtension: "wav") {
            enginePlayer = try? AVAudioPlayer(contentsOf: url)
            enginePlayer?.numberOfLoops = -1
            enginePlayer?.volume = 0.35
            enginePlayer?.prepareToPlay()
        }
    }

    private func preloadBoostSounds() {
        for driver in DriverCatalog.all where driver.id != "ivan" {
            let resourceName = "boost-\(driver.id)"
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: "m4a")
                ?? Bundle.main.url(forResource: resourceName, withExtension: "m4a", subdirectory: "audio") else {
                continue
            }
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                boostPlayers[driver.id] = player
            }
        }
    }

    private func preloadBackgroundMusic() {
        bgmPlayers = bgmTrackNames.compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "mp3")
                ?? Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "audio") else {
                return nil
            }
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
            player.delegate = bgmDelegate
            player.numberOfLoops = 0
            player.volume = bgmVolume
            player.prepareToPlay()
            return player
        }
    }

    func play(_ sound: RaceSound) {
        guard AudioPreferences.isSFXEnabled else { return }
        if let player = players[sound] {
            player.currentTime = 0
            player.play()
            return
        }
        playSystemFallback(for: sound)
    }

    func playBoost(for driverId: String) {
        guard AudioPreferences.isSFXEnabled else { return }
        if let player = boostPlayers[driverId] {
            player.currentTime = 0
            player.play()
            return
        }
        playSystemFallback(for: .boost)
    }

    func setEngineActive(_ active: Bool, speed: Float = 0) {
        guard AudioPreferences.isSFXEnabled else {
            if isEngineRunning {
                enginePlayer?.stop()
                enginePlayer?.currentTime = 0
                isEngineRunning = false
            }
            return
        }
        guard let enginePlayer else {
            return
        }
        if active {
            let normalized = min(1, max(0, speed / BikeMovementModel.maxSpeed))
            enginePlayer.rate = 0.85 + normalized * 0.65
            enginePlayer.enableRate = true
            if !isEngineRunning {
                enginePlayer.play()
                isEngineRunning = true
            }
        } else if isEngineRunning {
            enginePlayer.stop()
            enginePlayer.currentTime = 0
            isEngineRunning = false
        }
    }

    func stopRaceAudio() {
        setEngineActive(false)
        players.values.forEach { $0.stop() }
        boostPlayers.values.forEach { $0.stop() }
    }

    func startBackgroundMusic() {
        guard AudioPreferences.isMusicEnabled else { return }
        guard !bgmPlayers.isEmpty else { return }
        guard !isBGMPlaying else { return }

        bgmFadeTask?.cancel()
        let player = bgmPlayers[currentBGMIndex]
        player.currentTime = 0
        player.volume = 0
        player.play()
        isBGMPlaying = true
        bgmFadeTask = fadeVolume(player: player, to: bgmVolume)
    }

    func stopBackgroundMusic(fade: Bool) {
        guard isBGMPlaying else { return }

        bgmFadeTask?.cancel()
        let player = bgmPlayers[currentBGMIndex]

        if fade {
            bgmFadeTask = Task {
                await fadeVolumeSync(player: player, to: 0, duration: fadeDuration)
                guard !Task.isCancelled else { return }
                player.stop()
                player.currentTime = 0
                isBGMPlaying = false
            }
        } else {
            player.stop()
            player.currentTime = 0
            player.volume = bgmVolume
            isBGMPlaying = false
        }
    }

    func syncBackgroundMusic(for phase: AppPhase) {
        if phase.playsBackgroundMusic {
            startBackgroundMusic()
        } else {
            stopBackgroundMusic(fade: true)
        }
    }

    private func playNextBackgroundTrack() {
        guard isBGMPlaying else { return }
        guard !bgmPlayers.isEmpty else { return }

        currentBGMIndex = (currentBGMIndex + 1) % bgmPlayers.count
        let player = bgmPlayers[currentBGMIndex]
        player.currentTime = 0
        player.volume = bgmVolume
        player.play()
    }

    private func fadeVolume(player: AVAudioPlayer, to target: Float) -> Task<Void, Never> {
        Task {
            await fadeVolumeSync(player: player, to: target, duration: fadeDuration)
        }
    }

    private func fadeVolumeSync(player: AVAudioPlayer, to target: Float, duration: TimeInterval) async {
        let steps = 20
        let stepDuration = duration / Double(steps)
        let start = player.volume
        let delta = (target - start) / Float(steps)

        for step in 1...steps {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            player.volume = start + delta * Float(step)
        }
        player.volume = target
    }

    private func playSystemFallback(for sound: RaceSound) {
        let id: SystemSoundID
        switch sound {
        case .countdownBeep: id = 1104
        case .goHorn: id = 1005
        case .boost: id = 1520
        case .collision: id = 1521
        case .finishFanfare: id = 1025
        case .engineLoop: return
        }
        AudioServicesPlaySystemSound(id)
    }
}

extension RaceSound: CaseIterable {}

private final class BGMPlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    var onTrackFinished: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else { return }
        onTrackFinished?()
    }
}
