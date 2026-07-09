//
//  AppState.swift
//  bikebike
//

import Foundation
import ARKit
import Observation

enum HomeDepartureStyle: Equatable {
    case solo
    case multiplayer
}

@MainActor @Observable
final class AppState: RaceSessionDelegate {
    var phase: AppPhase = .home
    var role: PlayerRole = .solo
    var homeDeparture: HomeDepartureStyle?
    var raceConfig = RaceConfig()
    var players: [PlayerProfile] = []
    var carStates: [CarState] = []
    var leaderboard: [LeaderboardEntry] = []
    var discoveredSessions: [SessionInfo] = []
    var isSessionConnected = false
    var connectedHostName: String?
    var showConnectionHelp = false
    var sessionErrorMessage: String?
    var sessionHasStarted = false
    var targetHostName: String?
    var qrJoinErrorMessage: String?
    var lobbySyncErrorMessage: String?
    var trackPlaced = false
    var isRelocalizing = false
    var relocalizationMessage: String?
    private var lastTrackTransform: TransformPacket?
    private var lastTrackScale: Float = 1.0
    private var lastTrackPresetId: String = RaceTrackCatalog.defaultTrackId
    private var worldMapChunks: [Int: Data] = [:]
    private var expectedWorldMapChunks = 0
    private var pendingTrackPayload: TrackPlacedPayload?
    private var relocalizationTimeoutTask: Task<Void, Never>?
    var raceStartTime: Date?
    var elapsedTime: TimeInterval = 0

    var pendingPlacementStart = false
    var placementError: String?
    var placementScale: Float = 1.0
    var planeDetectionStatus: PlaneDetectionStatus = .scanning
    var hasDetectedPlane = false
    var trackingQuality: ARTrackingQuality = .normal

    var canConfirmPlacement: Bool {
        arController.canConfirmPlacement
    }

    let raceSession = NetworkSessionManager()
    let arController = ARSceneController()
    var arSession: ARSession = ARSession()

    // Input state
    var steerInput: Float = 0
    var gasPressed: Bool = false
    var brakeInput: Float = 0

    private var poseTimer: Timer?
    private var elapsedTimer: Timer?
    private var lastLapCrossTime: [String: Date] = [:]
    private var browseHelpTask: Task<Void, Never>?
    private var qrJoinTimeoutTask: Task<Void, Never>?
    private var lobbySyncTask: Task<Void, Never>?
    private var pendingMultiplayerRole: PlayerRole?
    private var pendingRaceStart = false
    private var lastRemotePoseTimestamp: [String: TimeInterval] = [:]

    var lobbyReady: Bool { players.count >= 2 }

    init() {
        raceSession.delegate = self
        arController.setSelectedTrack(id: raceConfig.trackId)
        arController.onLapCrossed = { [weak self] playerId in
            self?.handleLapCrossed(playerId: playerId)
        }
        arController.onPlaneStateUpdated = { [weak self] status, hasPlane, tracking in
            self?.planeDetectionStatus = status
            self?.hasDetectedPlane = hasPlane
            self?.trackingQuality = tracking
        }
        arController.onRelocalizationReady = { [weak self] in
            self?.onRelocalizationComplete()
        }
        Task { await CarModelLoader.preload() }
    }

    // MARK: - Navigation

    func exitRace() {
        stopTimers()
        steerInput = 0
        gasPressed = false
        brakeInput = 0
        arController.removeAllCars()
        carStates = []
        leaderboard = []
        raceStartTime = nil
        elapsedTime = 0

        switch role {
        case .solo:
            goHome()
        case .host:
            phase = .hostSetup
        case .guest:
            phase = .guestSetup
        }
    }

    func goHome() {
        stopTimers()
        raceSession.stopAll()
        arController.teardown()
        phase = .home
        role = .solo
        players = []
        carStates = []
        leaderboard = []
        discoveredSessions = []
        isSessionConnected = false
        connectedHostName = nil
        sessionErrorMessage = nil
        sessionHasStarted = false
        targetHostName = nil
        qrJoinErrorMessage = nil
        lobbySyncErrorMessage = nil
        pendingMultiplayerRole = nil
        cancelBrowseHelpTimer()
        cancelQRJoinTimeout()
        cancelLobbySync()
        trackPlaced = false
        lastTrackTransform = nil
        lastTrackScale = 1.0
        lastTrackPresetId = RaceTrackCatalog.defaultTrackId
        raceConfig = RaceConfig(trackId: RaceTrackCatalog.defaultTrackId, lapCount: 3)
        arController.setSelectedTrack(id: raceConfig.trackId)
        placementScale = 1.0
        resetWorldMapState()
        pendingRaceStart = false
        pendingPlacementStart = false
        placementError = nil
        raceStartTime = nil
        elapsedTime = 0
        lastRemotePoseTimestamp = [:]
        homeDeparture = nil
    }

    func triggerHomeDeparture(_ style: HomeDepartureStyle) {
        homeDeparture = style
    }

    func clearHomeDeparture() {
        homeDeparture = nil
    }

    func beginPlayTogether() {
        phase = .multiplayerRolePicker
    }

    func selectMultiplayerRole(_ selectedRole: PlayerRole) {
        pendingMultiplayerRole = selectedRole
        continueFromPermissionPrimer()
    }

    func backFromPermissionPrimer() {
        pendingMultiplayerRole = nil
        phase = .multiplayerRolePicker
    }

    func backFromMultiplayerLapSelect() {
        raceSession.stopAll()
        isSessionConnected = false
        sessionErrorMessage = nil
        phase = .multiplayerRolePicker
    }

    func backFromHostSetup() {
        phase = .multiplayerLapSelect
    }

    func backFromGuestSetup() {
        stopTimers()
        raceSession.stopAll()
        isSessionConnected = false
        sessionErrorMessage = nil
        targetHostName = nil
        phase = .multiplayerRolePicker
    }

    func continueFromPermissionPrimer() {
        guard let pending = pendingMultiplayerRole else { return }
        sessionErrorMessage = nil
        qrJoinErrorMessage = nil
        lobbySyncErrorMessage = nil
        pendingMultiplayerRole = nil

        switch pending {
        case .host:
            activateHosting()
            phase = .multiplayerLapSelect
        case .guest:
            activateBrowsing()
            phase = .guestSetup
            if targetHostName != nil {
                startQRJoinTimeout()
            }
        default:
            break
        }
    }

    func confirmMultiplayerLapSelect() {
        phase = .hostSetup
    }

    func retrySession() {
        sessionErrorMessage = nil
        qrJoinErrorMessage = nil
        lobbySyncErrorMessage = nil
        switch role {
        case .host:
            activateHosting()
        case .guest:
            activateBrowsing()
            tryAutoJoinDiscoveredSessions()
        default:
            break
        }
    }

    func handleScannedJoinLink(_ payload: String) {
        guard let url = URL(string: payload), let host = JoinLink.parse(url) else {
            qrJoinErrorMessage = "That QR code isn't a race invite."
            return
        }
        targetHostName = host
        qrJoinErrorMessage = nil
        startQRJoinTimeout()
        tryAutoJoinDiscoveredSessions()
    }

    func handleJoinURL(_ url: URL) {
        guard let host = JoinLink.parse(url) else { return }
        targetHostName = host
        qrJoinErrorMessage = nil
        if phase == .home {
            pendingMultiplayerRole = .guest
            phase = .permissionPrimer
        } else if phase == .guestSetup {
            startQRJoinTimeout()
            tryAutoJoinDiscoveredSessions()
        }
    }

    func startSoloPractice() {
        role = .solo
        raceConfig = RaceConfig(trackId: RaceTrackCatalog.defaultTrackId, lapCount: 3)
        arController.setSelectedTrack(id: raceConfig.trackId)
        players = [localPlayer(isHost: true)]
        placementError = nil
        placementScale = 1.0
        phase = .soloLapSelect
    }

    func confirmSoloLapSelect() {
        arController.setSelectedTrack(id: raceConfig.trackId)
        pendingPlacementStart = true
        phase = .placement
    }

    func playAgain() {
        stopTimers()
        steerInput = 0
        gasPressed = false
        brakeInput = 0
        arController.removeAllCars()
        carStates = []
        leaderboard = []
        raceStartTime = nil
        elapsedTime = 0
        trackPlaced = false
        lastTrackTransform = nil
        lastTrackPresetId = raceConfig.trackId
        placementScale = 1.0
        placementError = nil

        switch role {
        case .solo:
            phase = .soloLapSelect
        case .host:
            phase = .hostSetup
        case .guest:
            phase = .guestSetup
        }
    }

    func startHosting() {
        activateHosting()
        phase = .hostLobby
    }

    private func activateHosting() {
        role = .host
        players = [localPlayer(isHost: true)]
        syncPlayerColors()
        trackPlaced = false
        sessionHasStarted = true
        let info = SessionInfo(
            sessionId: raceSession.localDisplayName,
            hostName: raceSession.localDisplayName,
            trackId: raceConfig.trackId,
            lapCount: raceConfig.lapCount,
            playerCount: 1,
            maxPlayers: 2,
            phase: .lobby,
            peerID: raceSession.localPlayerId
        )
        raceSession.startHosting(sessionInfo: info)
    }

    func startBrowsing() {
        activateBrowsing()
        phase = .browseSessions
        startBrowseHelpTimer()
    }

    private func activateBrowsing() {
        role = .guest
        discoveredSessions = []
        isSessionConnected = false
        connectedHostName = nil
        sessionHasStarted = true
        raceSession.startBrowsing()
    }

    func refreshBrowsing() {
        discoveredSessions = []
        raceSession.refreshBrowsing()
        startBrowseHelpTimer()
        tryAutoJoinDiscoveredSessions()
    }

    func dismissConnectionHelp() {
        showConnectionHelp = false
    }

    func cancelBrowseHelpTimerOnLeave() {
        cancelBrowseHelpTimer()
    }

    func joinSession(_ session: SessionInfo) {
        cancelBrowseHelpTimer()
        cancelQRJoinTimeout()
        qrJoinErrorMessage = nil
        lobbySyncErrorMessage = nil
        raceSession.connect(to: session)
        if phase == .guestSetup || phase == .browseSessions {
            phase = phase == .browseSessions ? .guestLobby : .guestSetup
        } else {
            phase = .guestLobby
        }
    }

    func beginPlacement() {
        placementError = nil
        placementScale = 1.0
        arController.setSelectedTrack(id: raceConfig.trackId)
        pendingPlacementStart = true
        phase = .placement
    }

    func onARViewReady() {
        arController.setSelectedTrack(id: raceConfig.trackId)
        arController.flushPendingState(session: arSession)
        tryApplyPendingTrackPlacement()
        if pendingPlacementStart {
            pendingPlacementStart = false
            placementScale = 1.0
            arController.startPlacementPreview()
        }
        if phase == .racing {
            Task { await respawnAllCars() }
        }
    }

    func cancelPlacement() {
        pendingPlacementStart = false
        placementError = nil
        placementScale = 1.0
        arController.cancelPlacementPreview()
        if role == .host {
            phase = .hostSetup
        } else {
            goHome()
        }
    }

    func confirmPlacement() {
        guard arController.canConfirmPlacement else {
            placementError = "No surface detected yet. Keep scanning the table."
            return
        }
        guard let result = arController.confirmPlacement() else {
            placementError = "Could not place track — scan the surface again."
            return
        }
        placementError = nil
        trackPlaced = true
        lastTrackTransform = result.transform
        lastTrackScale = result.scale
        lastTrackPresetId = result.presetId
        raceConfig.trackId = result.presetId
        arController.setSelectedTrack(id: result.presetId)
        placementScale = result.scale
        if role == .host {
            phase = .hostSetup
            Task {
                await broadcastTrackPlacedWithWorldMap(transform: result.transform, scale: result.scale, presetId: result.presetId)
            }
        } else {
            Task { await startRace() }
        }
    }

    func setPlacementScale(_ scale: Float) {
        arController.setPlacementScale(scale)
        placementScale = arController.placementScale
    }

    func startRace() async {
        guard trackPlaced else { return }
        phase = .racing
        raceStartTime = Date()
        elapsedTime = 0
        lastRemotePoseTimestamp = [:]
        await spawnAllCars()

        if role == .host {
            let payload = RaceStartPayload(startTime: Date().timeIntervalSince1970, config: raceConfig)
            if let envelope = try? raceSession.encode(type: .raceStart, payload: payload) {
                raceSession.send(envelope, reliable: true)
            }
        }

        startTimers()
        refreshLeaderboard()
    }

    func hostStartRace() {
        Task { await startRace() }
    }

    func resendTrack() {
        guard role == .host, trackPlaced, let transform = lastTrackTransform else { return }
        Task {
            await broadcastTrackPlacedWithWorldMap(transform: transform, scale: lastTrackScale, presetId: lastTrackPresetId)
        }
    }

    func selectTrack(_ trackId: String) {
        let normalized = RaceTrackCatalog.normalizedTrackId(trackId)
        raceConfig.trackId = normalized
        if !trackPlaced {
            arController.setSelectedTrack(id: normalized)
        }
    }

    func applyInputTick(deltaTime: Float) {
        guard phase == .racing else { return }
        let localId = raceSession.localPlayerId
        arController.applyInput(
            playerId: localId,
            steer: steerInput,
            gasPressed: gasPressed,
            brake: brakeInput,
            deltaTime: deltaTime
        )
        arController.tickRemoteCars(deltaTime: deltaTime, now: Date().timeIntervalSince1970)
        updateLocalCarState()
    }

    // MARK: - RaceSessionDelegate

    func sessionDidDiscover(_ session: SessionInfo) {
        if !discoveredSessions.contains(where: { $0.sessionId == session.sessionId }) {
            discoveredSessions.append(session)
            cancelBrowseHelpTimer()
        }
        tryAutoJoinDiscoveredSessions()
    }

    func sessionDidFailToStart(error: Error) {
        let nsError = error as NSError
        if nsError.domain == NetService.errorDomain && nsError.code == -72008 {
            sessionErrorMessage = "Tap Try Again. If it keeps failing, delete and reinstall the app, tap Allow when prompted, or enable BikeBike under Settings → Privacy & Security → Local Network."
        } else {
            sessionErrorMessage = error.localizedDescription
        }
    }

    func sessionDidLose(_ sessionId: String) {
        discoveredSessions.removeAll { $0.sessionId == sessionId }
    }

    func sessionPeerConnected(_ peerId: String) {
        if role == .guest {
            startLobbySync()
        }
        updateSessionConnectionState()
        if role == .guest && isSessionConnected {
            cancelQRJoinTimeout()
            qrJoinErrorMessage = nil
        }
    }

    func sessionPeerDisconnected(_ peerId: String) {
        cancelLobbySync()
        players.removeAll { $0.peerId == peerId }
        carStates.removeAll { $0.playerId == peerId }
        arController.removeCar(playerId: peerId)
        if role == .guest && phase == .racing {
            goHome()
        }
        updateSessionConnectionState()
    }

    func sessionDidReceive(_ envelope: RaceEnvelope, from peerId: String) {
        switch envelope.type {
        case .joinRequest:
            guard role == .host, let payload = try? envelope.decode(JoinRequestPayload.self) else { return }
            upsertPlayer(payload.player)
            sendJoinAccept(forGuestPeerId: payload.player.peerId)

        case .joinAccept:
            guard let payload = try? envelope.decode(JoinAcceptPayload.self) else { return }
            players = payload.allPlayers
            raceConfig = payload.config
            arController.setSelectedTrack(id: raceConfig.trackId)
            cancelLobbySync()
            lobbySyncErrorMessage = nil

        case .trackPlaced:
            guard let payload = try? envelope.decode(TrackPlacedPayload.self) else { return }
            handleTrackPlaced(payload)

        case .worldMapChunk:
            guard let payload = try? envelope.decode(WorldMapChunkPayload.self) else { return }
            worldMapChunks[payload.chunkIndex] = payload.data
            expectedWorldMapChunks = payload.totalChunks
            tryApplyPendingTrackPlacement()

        case .raceStart:
            guard let payload = try? envelope.decode(RaceStartPayload.self) else { return }
            raceConfig = payload.config
            if phase == .racing { return }
            if trackPlaced {
                Task { await startRace() }
            } else {
                pendingRaceStart = true
            }

        case .carPose:
            guard let payload = try? envelope.decode(CarPosePayload.self) else { return }
            if payload.playerId != raceSession.localPlayerId {
                let timestamp = payload.transform.timestamp
                if let last = lastRemotePoseTimestamp[payload.playerId], timestamp < last {
                    return
                }
                lastRemotePoseTimestamp[payload.playerId] = timestamp
                Task { await ensureRemoteCarSpawned(playerId: payload.playerId) }
                arController.setRemoteCarTarget(
                    playerId: payload.playerId,
                    transform: payload.transform,
                    speed: payload.speed
                )
                updateCarState(from: payload)
                if role == .host {
                    relayCarPose(payload, excluding: peerId)
                }
            }

        case .lapCompleted:
            guard let payload = try? envelope.decode(LapCompletedPayload.self) else { return }
            applyLapUpdate(payload)

        case .raceEnd:
            guard let payload = try? envelope.decode(RaceEndPayload.self) else { return }
            leaderboard = payload.leaderboard
            stopTimers()
            phase = .results

        case .playerLeft:
            guard let payload = try? envelope.decode(PlayerLeftPayload.self) else { return }
            players.removeAll { $0.peerId == payload.playerId }
            carStates.removeAll { $0.playerId == payload.playerId }

        case .playerProfile:
            guard let payload = try? envelope.decode(PlayerProfilePayload.self) else { return }
            upsertPlayer(payload.player)
        }
    }

    // MARK: - Private

    private func tryAutoJoinDiscoveredSessions() {
        guard role == .guest, let target = targetHostName, !isSessionConnected, !raceSession.isConnectingToHost else { return }
        guard let session = discoveredSessions.first(where: { sessionMatchesTarget($0, target: target) }) else { return }
        joinSession(session)
    }

    private func sessionMatchesTarget(_ session: SessionInfo, target: String) -> Bool {
        session.hostName == target || session.sessionId == target || session.peerID == target
    }

    private func startQRJoinTimeout() {
        qrJoinTimeoutTask?.cancel()
        qrJoinTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, role == .guest, !isSessionConnected, let target = targetHostName else { return }
            qrJoinErrorMessage = "Couldn't find \(target). Make sure you're on the same Wi‑Fi, then tap Try Again or pick from the list."
        }
    }

    private func cancelQRJoinTimeout() {
        qrJoinTimeoutTask?.cancel()
        qrJoinTimeoutTask = nil
    }

    private func sendJoinRequest() {
        guard role == .guest else { return }
        upsertPlayer(localPlayer(isHost: false))
        let payload = JoinRequestPayload(player: localPlayer(isHost: false))
        if let envelope = try? raceSession.encode(type: .joinRequest, payload: payload) {
            raceSession.sendToHost(envelope, reliable: true)
        }
    }

    private func startLobbySync() {
        cancelLobbySync()
        lobbySyncErrorMessage = nil
        sendJoinRequest()
        lobbySyncTask = Task {
            for _ in 0..<10 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, role == .guest else { return }
                if lobbyReady {
                    cancelLobbySync()
                    return
                }
                guard isSessionConnected else {
                    cancelLobbySync()
                    return
                }
                sendJoinRequest()
            }
            guard !Task.isCancelled, role == .guest, isSessionConnected, !lobbyReady else { return }
            lobbySyncErrorMessage = "Connected but couldn't join lobby. Tap Try Again."
        }
    }

    private func cancelLobbySync() {
        lobbySyncTask?.cancel()
        lobbySyncTask = nil
    }

    private func startBrowseHelpTimer() {
        browseHelpTask?.cancel()
        showConnectionHelp = false
        browseHelpTask = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, phase == .browseSessions, discoveredSessions.isEmpty else { return }
            showConnectionHelp = true
        }
    }

    private func cancelBrowseHelpTimer() {
        browseHelpTask?.cancel()
        browseHelpTask = nil
        showConnectionHelp = false
    }

    private func updateSessionConnectionState() {
        isSessionConnected = !raceSession.connectedPeerIds.isEmpty
        if role == .guest {
            connectedHostName = raceSession.connectedPeerIds.first
        } else {
            connectedHostName = nil
        }
        reconcileConnectedPeers()
    }

    private func upsertPlayer(_ profile: PlayerProfile) {
        var updated = players
        if let idx = updated.firstIndex(where: { $0.peerId == profile.peerId }) {
            if updated[idx].isHost != profile.isHost {
                updated.append(profile)
            } else {
                updated[idx].displayName = profile.displayName
                if !updated[idx].isHost {
                    updated[idx].carColorHex = profile.carColorHex
                }
            }
        } else {
            updated.append(profile)
        }
        players = updated
        if role == .host { syncPlayerColors() }
    }

    private func registerGuestPeer(_ peerId: String) {
        guard role == .host else { return }
        guard peerId != raceSession.localPlayerId, !peerId.hasPrefix("guest-") else { return }
        upsertPlayer(PlayerProfile.local(peerId: peerId, name: peerId, isHost: false))
    }

    private func reconcileConnectedPeers() {
        guard role == .host else { return }
        for peerId in raceSession.connectedPeerIds where peerId != raceSession.localPlayerId {
            if !players.contains(where: { $0.peerId == peerId }) {
                registerGuestPeer(peerId)
            }
        }
    }

    private func sendJoinAccept(forGuestPeerId guestPeerId: String) {
        guard role == .host else { return }
        syncPlayerColors()
        let guest = players.first { $0.peerId == guestPeerId }
            ?? PlayerProfile.local(peerId: guestPeerId, name: guestPeerId, isHost: false)
        let accept = JoinAcceptPayload(player: guest, allPlayers: players, config: raceConfig)
        if let reply = try? raceSession.encode(type: .joinAccept, payload: accept) {
            raceSession.send(reply, reliable: true)
        }
        if trackPlaced { resendTrack() }
    }

    private func spawnAllCars() async {
        carStates.removeAll()
        for (index, player) in players.enumerated() {
            await arController.spawnCar(playerId: player.peerId, colorHex: player.carColorHex, gridIndex: index)
            carStates.append(CarState(
                playerId: player.peerId,
                transform: TransformPacket(position: .zero, rotation: simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))),
                speed: 0,
                currentLap: 0,
                lastLapTime: nil,
                totalTime: 0,
                finished: false,
                finishTime: nil,
                status: .racing
            ))
        }
    }

    private func respawnAllCars() async {
        guard phase == .racing, trackPlaced else { return }
        arController.removeAllCars()
        await spawnAllCars()
    }

    private func localPlayer(isHost: Bool, colorHex: String? = nil) -> PlayerProfile {
        PlayerProfile.local(
            peerId: raceSession.localPlayerId,
            name: raceSession.localDisplayName,
            isHost: isHost,
            colorHex: colorHex ?? PlayerColors.hostHex
        )
    }

    private func syncPlayerColors() {
        guard role == .host else { return }
        PlayerColors.assign(to: &players)
    }

    private func broadcastTrackPlaced(transform: TransformPacket, scale: Float, presetId: String, worldMapChunkCount: Int) {
        let payload = TrackPlacedPayload(
            presetId: presetId,
            transform: transform,
            scale: scale,
            worldMapChunkCount: worldMapChunkCount
        )
        if let envelope = try? raceSession.encode(type: .trackPlaced, payload: payload) {
            raceSession.send(envelope, reliable: true)
        }
    }

    private func broadcastTrackPlacedWithWorldMap(transform: TransformPacket, scale: Float, presetId: String) async {
        var chunkCount = 0
        if let mapData = await captureWorldMapData() {
            let chunks = WorldMapTransfer.chunk(data: mapData)
            chunkCount = chunks.count
            for (index, chunk) in chunks.enumerated() {
                let payload = WorldMapChunkPayload(chunkIndex: index, totalChunks: chunks.count, data: chunk)
                if let envelope = try? raceSession.encode(type: .worldMapChunk, payload: payload) {
                    raceSession.send(envelope, reliable: true)
                }
            }
        }
        broadcastTrackPlaced(transform: transform, scale: scale, presetId: presetId, worldMapChunkCount: chunkCount)
    }

    private func captureWorldMapData() async -> Data? {
        await withCheckedContinuation { continuation in
            arSession.getCurrentWorldMap { worldMap, error in
                guard let worldMap, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let data = try? WorldMapTransfer.serialize(worldMap)
                continuation.resume(returning: data)
            }
        }
    }

    private func handleTrackPlaced(_ payload: TrackPlacedPayload) {
        pendingTrackPayload = payload
        worldMapChunks = [:]
        expectedWorldMapChunks = payload.worldMapChunkCount
        if payload.worldMapChunkCount == 0 {
            applyTrackPlacement(payload)
        } else {
            isRelocalizing = true
            relocalizationMessage = "Aligning to host's table…"
            startRelocalizationTimeout()
            tryApplyPendingTrackPlacement()
        }
    }

    private func tryApplyPendingTrackPlacement() {
        guard let payload = pendingTrackPayload else { return }
        guard payload.worldMapChunkCount > 0 else {
            applyTrackPlacement(payload)
            return
        }
        guard arController.isARViewAttached else { return }
        guard worldMapChunks.count == payload.worldMapChunkCount,
              let data = WorldMapTransfer.assemble(chunks: worldMapChunks, totalChunks: payload.worldMapChunkCount),
              let worldMap = try? WorldMapTransfer.deserialize(data) else { return }

        arController.applyWorldMap(worldMap, session: arSession)
        startRelocalizationTimeout()
    }

    private func applyTrackPlacement(_ payload: TrackPlacedPayload) {
        cancelRelocalizationTimeout()
        isRelocalizing = false
        relocalizationMessage = nil
        raceConfig.trackId = RaceTrackCatalog.normalizedTrackId(payload.presetId)
        lastTrackPresetId = raceConfig.trackId
        arController.setSelectedTrack(id: raceConfig.trackId)
        arController.placeTrackFromSync(transform: payload.transform, scale: payload.scale, presetId: raceConfig.trackId)
        trackPlaced = true
        lastTrackTransform = payload.transform
        lastTrackScale = payload.scale
        placementScale = payload.scale
        pendingTrackPayload = nil
        worldMapChunks = [:]
        expectedWorldMapChunks = 0

        if pendingRaceStart {
            pendingRaceStart = false
            if phase != .racing {
                Task { await startRace() }
            }
        } else if phase == .racing {
            Task { await respawnAllCars() }
        }
    }

    private func applyTrackPlacementFallback(_ payload: TrackPlacedPayload) {
        relocalizationMessage = "Could not align — track placed approximately. Point both phones at the same table."
        applyTrackPlacement(payload)
    }

    private func onRelocalizationComplete() {
        guard isRelocalizing, let payload = pendingTrackPayload else { return }
        applyTrackPlacement(payload)
    }

    private func startRelocalizationTimeout() {
        relocalizationTimeoutTask?.cancel()
        relocalizationTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, isRelocalizing, let payload = pendingTrackPayload else { return }
            applyTrackPlacementFallback(payload)
        }
    }

    private func cancelRelocalizationTimeout() {
        relocalizationTimeoutTask?.cancel()
        relocalizationTimeoutTask = nil
    }

    private func resetWorldMapState() {
        cancelRelocalizationTimeout()
        isRelocalizing = false
        relocalizationMessage = nil
        pendingTrackPayload = nil
        worldMapChunks = [:]
        expectedWorldMapChunks = 0
    }

    private func ensureRemoteCarSpawned(playerId: String) async {
        guard phase == .racing, !arController.hasCar(playerId: playerId) else { return }
        guard let index = players.firstIndex(where: { $0.peerId == playerId }) else { return }
        let player = players[index]
        await arController.spawnCar(playerId: player.peerId, colorHex: player.carColorHex, gridIndex: index)
        if !carStates.contains(where: { $0.playerId == playerId }) {
            carStates.append(CarState(
                playerId: player.peerId,
                transform: TransformPacket(position: .zero, rotation: simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))),
                speed: 0,
                currentLap: 0,
                lastLapTime: nil,
                totalTime: 0,
                finished: false,
                finishTime: nil,
                status: .racing
            ))
        }
    }

    private func relayCarPose(_ payload: CarPosePayload, excluding peerId: String) {
        guard let envelope = try? raceSession.encode(type: .carPose, payload: payload) else { return }
        raceSession.send(envelope, reliable: false, excluding: peerId)
    }

    private func handleLapCrossed(playerId: String) {
        guard phase == .racing else { return }
        let now = Date()

        if role == .host || role == .solo {
            recordLap(for: playerId)
        } else {
            guard let car = carStates.first(where: { $0.playerId == playerId }) else { return }
            let payload = LapCompletedPayload(
                playerId: playerId,
                lapNumber: car.currentLap + 1,
                lapTime: now.timeIntervalSince(lastLapCrossTime[playerId] ?? raceStartTime ?? now),
                totalTime: now.timeIntervalSince(raceStartTime ?? now)
            )
            if let envelope = try? raceSession.encode(type: .lapCompleted, payload: payload) {
                raceSession.sendToHost(envelope, reliable: true)
            }
        }
    }

    private func recordLap(for playerId: String) {
        guard let idx = carStates.firstIndex(where: { $0.playerId == playerId }) else { return }
        let now = Date()
        let lapStart = lastLapCrossTime[playerId] ?? raceStartTime ?? now
        let lapTime = now.timeIntervalSince(lapStart)
        lastLapCrossTime[playerId] = now

        carStates[idx].currentLap += 1
        carStates[idx].lastLapTime = lapTime
        carStates[idx].totalTime = now.timeIntervalSince(raceStartTime ?? now)

        let payload = LapCompletedPayload(
            playerId: playerId,
            lapNumber: carStates[idx].currentLap,
            lapTime: lapTime,
            totalTime: carStates[idx].totalTime
        )

        if role == .host {
            if let envelope = try? raceSession.encode(type: .lapCompleted, payload: payload) {
                raceSession.send(envelope, reliable: true)
            }
        }

        if carStates[idx].currentLap >= raceConfig.lapCount {
            carStates[idx].finished = true
            carStates[idx].finishTime = carStates[idx].totalTime
            carStates[idx].status = .finished
            checkRaceEnd()
        }
        refreshLeaderboard()
    }

    private func applyLapUpdate(_ payload: LapCompletedPayload) {
        guard let idx = carStates.firstIndex(where: { $0.playerId == payload.playerId }) else { return }
        carStates[idx].currentLap = payload.lapNumber
        carStates[idx].lastLapTime = payload.lapTime
        carStates[idx].totalTime = payload.totalTime
        if payload.lapNumber >= raceConfig.lapCount {
            carStates[idx].finished = true
            carStates[idx].finishTime = payload.totalTime
            carStates[idx].status = .finished
        }
        refreshLeaderboard()
        if role == .host { checkRaceEnd() }
    }

    private func checkRaceEnd() {
        let racing = carStates.filter { $0.status == .racing }
        if racing.isEmpty && !carStates.isEmpty {
            endRace()
        }
    }

    private func endRace() {
        refreshLeaderboard()
        stopTimers()
        let payload = RaceEndPayload(leaderboard: leaderboard, reason: "allFinished")
        if role == .host, let envelope = try? raceSession.encode(type: .raceEnd, payload: payload) {
            raceSession.send(envelope, reliable: true)
        }
        phase = .results
    }

    private func updateLocalCarState() {
        guard let transform = arController.carTransform(playerId: raceSession.localPlayerId) else { return }
        let speed = arController.carSpeed(playerId: raceSession.localPlayerId)
        if let idx = carStates.firstIndex(where: { $0.playerId == raceSession.localPlayerId }) {
            carStates[idx].transform = transform
            carStates[idx].speed = speed
        }
    }

    private func updateCarState(from payload: CarPosePayload) {
        if let idx = carStates.firstIndex(where: { $0.playerId == payload.playerId }) {
            carStates[idx].transform = payload.transform
            carStates[idx].speed = payload.speed
        }
        refreshLeaderboard()
    }

    private func refreshLeaderboard() {
        leaderboard = LeaderboardSorter.sort(players: players, cars: carStates)
    }

    private func startTimers() {
        stopTimers()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateElapsedTime()
            }
        }
        poseTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.broadcastPose()
            }
        }
    }

    private func updateElapsedTime() {
        guard let start = raceStartTime else { return }
        elapsedTime = Date().timeIntervalSince(start)
    }

    private func stopTimers() {
        poseTimer?.invalidate()
        poseTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func broadcastPose() {
        guard phase == .racing else { return }
        guard let transform = arController.carTransform(playerId: raceSession.localPlayerId) else { return }
        let speed = arController.carSpeed(playerId: raceSession.localPlayerId)
        let payload = CarPosePayload(playerId: raceSession.localPlayerId, transform: transform, speed: speed)
        guard let envelope = try? raceSession.encode(type: .carPose, payload: payload) else { return }
        if role == .host {
            raceSession.send(envelope, reliable: false)
        } else if role == .guest {
            raceSession.sendToHost(envelope, reliable: false)
        }
    }
}

import simd
