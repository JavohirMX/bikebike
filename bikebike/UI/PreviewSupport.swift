//
//  PreviewSupport.swift
//  bikebike
//
//  Shared sample data used by SwiftUI #Preview blocks across the UI layer.
//

import SwiftUI
import simd

@MainActor
enum PreviewData {
    /// Builds a fresh `AppState`, applying an optional configuration closure so
    /// each preview can drive the view into a specific phase/state.
    static func appState(_ configure: (AppState) -> Void = { _ in }) -> AppState {
        let state = AppState()
        configure(state)
        return state
    }

    static func appStateForNickname(role: PlayerRole) -> AppState {
        appState { $0.selectMultiplayerRole(role) }
    }

    static var host: PlayerProfile {
        .local(peerId: "host-1", name: "Talin", isHost: true, driverId: "talin")
    }

    static var guest: PlayerProfile {
        .local(peerId: "guest-1", name: "Ish", isHost: false, driverId: "ish")
    }

    static var players: [PlayerProfile] { [host, guest] }

    static var sessions: [SessionInfo] {
        [
            SessionInfo(
                sessionId: "room-1",
                hostName: "Talin's iPhone",
                trackId: RaceTrackCatalog.defaultTrackId,
                lapCount: 3,
                playerCount: 1,
                maxPlayers: MultiplayerConstants.maxPlayers,
                phase: .lobby,
                peerID: "host-1"
            ),
            SessionInfo(
                sessionId: "room-2",
                hostName: "Ish's iPad",
                trackId: RaceTrackCatalog.defaultTrackId,
                lapCount: 5,
                playerCount: 2,
                maxPlayers: MultiplayerConstants.maxPlayers,
                phase: .lobby,
                peerID: "host-2"
            )
        ]
    }

    static func transform() -> TransformPacket {
        TransformPacket(position: .zero, rotation: simd_quatf(angle: 0, axis: SIMD3(0, 1, 0)))
    }

    static var carStates: [CarState] {
        [
            CarState(playerId: "host-1", transform: transform(), speed: 3.2, currentLap: 2, trackProgress: 0.72,
                     lastLapTime: 11.8, fastestLapTime: 11.8, totalTime: 42.3, finished: false, finishTime: nil, status: .racing),
            CarState(playerId: "guest-1", transform: transform(), speed: 2.7, currentLap: 1, trackProgress: 0.41,
                     lastLapTime: 13.4, fastestLapTime: 13.4, totalTime: 40.1, finished: false, finishTime: nil, status: .racing)
        ]
    }

    static var leaderboard: [LeaderboardEntry] {
        LeaderboardSorter.sort(players: players, cars: carStates)
    }

    static var finishedLeaderboard: [LeaderboardEntry] {
        [
            LeaderboardEntry(rank: 1, playerId: "host-1", displayName: "Talin", currentLap: 3,
                             lastLapTime: 11.2, fastestLapTime: 11.2, totalTime: 35.6, status: .finished),
            LeaderboardEntry(rank: 2, playerId: "guest-1", displayName: "Ish", currentLap: 3,
                             lastLapTime: 12.9, fastestLapTime: 12.9, totalTime: 39.4, status: .finished),
            LeaderboardEntry(rank: 3, playerId: "guest-2", displayName: "Ana", currentLap: 3,
                             lastLapTime: 13.1, fastestLapTime: 13.1, totalTime: 42.1, status: .finished),
            LeaderboardEntry(rank: 4, playerId: "guest-3", displayName: "TheNoder", currentLap: 3,
                             lastLapTime: 14.5, fastestLapTime: 14.5, totalTime: 45.8, status: .finished)
        ]
    }

    static var checklistSteps: [SetupChecklistStep] {
        [
            SetupChecklistStep(id: 1, title: "Scan host's QR code", subtitle: "Point at the host screen", status: .done),
            SetupChecklistStep(id: 2, title: "Connect to the session", subtitle: "Joining Talin's iPhone…", status: .active),
            SetupChecklistStep(id: 3, title: "Align your track", subtitle: "Match the host's view", status: .pending)
        ]
    }
}
