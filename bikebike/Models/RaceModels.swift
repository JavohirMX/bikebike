//
//  RaceModels.swift
//  bikebike
//

import Foundation
import simd

// MARK: - App Phase

enum AppPhase: Equatable {
    case home
    case soloDriverSelect
    case soloLapSelect
    case multiplayerRolePicker
    case multiplayerNickname
    case multiplayerHostDriverSelect
    case permissionPrimer
    case multiplayerLapSelect
    case hostSetup
    case guestSetup
    case browseSessions
    case hostLobby
    case guestLobby
    case placement
    case countdown
    case racing
    case results
}

struct BoostState: Equatable {
    var isActive: Bool = false
    var durationRemaining: TimeInterval = 0
    var cooldownRemaining: TimeInterval = 0

    static let activeDuration: TimeInterval = 3.0
    static let cooldownDuration: TimeInterval = 10.0
    static let speedMultiplier: Float = 1.5

    var isReady: Bool { !isActive && cooldownRemaining <= 0 }

    var cooldownProgress: Double {
        guard cooldownRemaining > 0 else { return 1 }
        return 1 - (cooldownRemaining / Self.cooldownDuration)
    }
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
    var trackId: String = RaceTrackCatalog.defaultTrackId
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
    case dnf
    case disconnected
}

// MARK: - Player

struct PlayerProfile: Codable, Identifiable, Equatable {
    var id: String { peerId }
    let peerId: String
    var displayName: String
    var carColorHex: String
    var driverId: String
    var isHost: Bool

    init(peerId: String, displayName: String, carColorHex: String, driverId: String, isHost: Bool) {
        self.peerId = peerId
        self.displayName = displayName
        self.carColorHex = carColorHex
        self.driverId = driverId
        self.isHost = isHost
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        peerId = try container.decode(String.self, forKey: .peerId)
        displayName = try container.decode(String.self, forKey: .displayName)
        carColorHex = try container.decode(String.self, forKey: .carColorHex)
        driverId = try container.decodeIfPresent(String.self, forKey: .driverId) ?? DriverCatalog.default.id
        isHost = try container.decode(Bool.self, forKey: .isHost)
    }

    static func local(
        peerId: String,
        name: String,
        isHost: Bool,
        colorHex: String? = nil,
        driverId: String = DriverCatalog.loadPersistedDriverId()
    ) -> PlayerProfile {
        let resolvedDriver = DriverCatalog.driver(for: driverId)
        return PlayerProfile(
            peerId: peerId,
            displayName: name,
            carColorHex: colorHex ?? resolvedDriver.accentColorHex,
            driverId: resolvedDriver.id,
            isHost: isHost
        )
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

enum MultiplayerConstants {
    static let maxPlayers = 6
    static var maxGuestConnections: Int { maxPlayers - 1 }
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
