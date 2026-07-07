//
//  RaceModels.swift
//  racecar
//

import Foundation
import simd

// MARK: - App Phase

enum AppPhase: Equatable {
    case home
    case soloLapSelect
    case multiplayerRolePicker
    case permissionPrimer
    case hostSetup
    case guestSetup
    case browseSessions
    case hostLobby
    case guestLobby
    case placement
    case racing
    case results
}

enum PlayerRole {
    case solo
    case host
    case guest
}

enum PlaneDetectionStatus: Equatable {
    case scanning
    case surfaceFound
    case ready
}

enum ARTrackingQuality: Equatable {
    case normal
    case limited
    case unavailable
}

// MARK: - Race

struct RaceConfig: Codable, Equatable {
    var trackId: String = "oval-loop-procedural"
    var lapCount: Int = 3
}

enum RacePhase: String, Codable {
    case idle
    case lobby
    case placing
    case racing
    case finished
}

enum PlayerStatus: String, Codable {
    case waiting
    case racing
    case finished
    case disconnected
}

// MARK: - Player

struct PlayerProfile: Codable, Identifiable, Equatable {
    var id: String { peerId }
    let peerId: String
    var displayName: String
    var carColorHex: String
    var isHost: Bool

    static func local(peerId: String, name: String, isHost: Bool, colorHex: String = PlayerColors.hostHex) -> PlayerProfile {
        PlayerProfile(peerId: peerId, displayName: name, carColorHex: colorHex, isHost: isHost)
    }
}

/// Distinct car colors per player slot (matches docs/UI-UX.md player palette).
enum PlayerColors {
    static let hostHex = "#FF3B30"
    static let palette = ["#FF3B30", "#007AFF", "#34C759", "#FF9500"]

    static func hex(forSlot slot: Int) -> String {
        palette[slot % palette.count]
    }

    static func assign(to players: inout [PlayerProfile]) {
        let ordered = players.sorted { lhs, rhs in
            if lhs.isHost != rhs.isHost { return lhs.isHost && !rhs.isHost }
            return lhs.displayName < rhs.displayName
        }
        for (index, player) in ordered.enumerated() {
            guard let i = players.firstIndex(where: { $0.peerId == player.peerId }) else { continue }
            players[i].carColorHex = hex(forSlot: index)
        }
    }
}

// MARK: - Transform

struct Vector3Packet: Codable, Equatable {
    var x: Float
    var y: Float
    var z: Float

    init(_ v: SIMD3<Float>) {
        x = v.x; y = v.y; z = v.z
    }

    var simd: SIMD3<Float> { SIMD3(x, y, z) }
}

struct QuaternionPacket: Codable, Equatable {
    var x: Float
    var y: Float
    var z: Float
    var w: Float

    init(_ q: simd_quatf) {
        x = q.vector.x; y = q.vector.y; z = q.vector.z; w = q.vector.w
    }

    var simd: simd_quatf { simd_quatf(vector: SIMD4(x, y, z, w)) }
}

struct TransformPacket: Codable, Equatable {
    var position: Vector3Packet
    var rotation: QuaternionPacket
    var timestamp: TimeInterval

    init(position: SIMD3<Float>, rotation: simd_quatf, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.position = Vector3Packet(position)
        self.rotation = QuaternionPacket(rotation)
        self.timestamp = timestamp
    }
}

// MARK: - Car & Leaderboard

struct CarState: Codable, Identifiable, Equatable {
    var id: String { playerId }
    let playerId: String
    var transform: TransformPacket
    var speed: Float
    var currentLap: Int
    var lastLapTime: TimeInterval?
    var totalTime: TimeInterval
    var finished: Bool
    var finishTime: TimeInterval?
    var status: PlayerStatus
}

struct LeaderboardEntry: Codable, Identifiable, Equatable {
    var id: String { playerId }
    let rank: Int
    let playerId: String
    let displayName: String
    let currentLap: Int
    let lastLapTime: TimeInterval?
    let totalTime: TimeInterval
    let status: PlayerStatus
}

struct SessionInfo: Codable, Identifiable, Equatable {
    let sessionId: String
    let hostName: String
    let trackId: String
    let lapCount: Int
    let playerCount: Int
    let maxPlayers: Int
    let phase: RacePhase
    let peerID: String

    var id: String { sessionId }
}

// MARK: - Leaderboard sorting

enum LeaderboardSorter {
    static func sort(players: [PlayerProfile], cars: [CarState]) -> [LeaderboardEntry] {
        let sorted = cars.sorted { a, b in
            if a.finished != b.finished { return a.finished && !b.finished }
            if a.finished && b.finished {
                return (a.finishTime ?? .infinity) < (b.finishTime ?? .infinity)
            }
            if a.currentLap != b.currentLap { return a.currentLap > b.currentLap }
            return a.totalTime < b.totalTime
        }
        return sorted.enumerated().map { index, car in
            let name = players.first { $0.peerId == car.playerId }?.displayName ?? "Player"
            return LeaderboardEntry(
                rank: index + 1,
                playerId: car.playerId,
                displayName: name,
                currentLap: car.currentLap,
                lastLapTime: car.lastLapTime,
                totalTime: car.totalTime,
                status: car.status
            )
        }
    }
}
