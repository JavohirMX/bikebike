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
    private var enginePlayer: AVAudioPlayer?
    private var isEngineRunning = false

    private init() {
        configureSession()
        preloadSounds()
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

    func play(_ sound: RaceSound) {
        if let player = players[sound] {
            player.currentTime = 0
            player.play()
            return
        }
        playSystemFallback(for: sound)
    }

    func setEngineActive(_ active: Bool, speed: Float = 0) {
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

    func stopAll() {
        setEngineActive(false)
        players.values.forEach { $0.stop() }
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
