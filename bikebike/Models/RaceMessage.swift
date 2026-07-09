//
//  RaceMessage.swift
//  bikebike
//

import Foundation

enum RaceMessageType: String, Codable {
    case joinRequest
    case joinAccept
    case trackPlaced
    case raceStart
    case carPose
    case lapCompleted
    case raceEnd
    case playerLeft
    case playerProfile
    case worldMapChunk
}

struct RaceEnvelope: Codable {
    let version: Int
    let type: RaceMessageType
    let payload: Data
    let senderId: String
    let timestamp: TimeInterval

    init(type: RaceMessageType, payload: Encodable, senderId: String) throws {
        version = 1
        self.type = type
        self.payload = try JSONEncoder().encode(AnyEncodable(payload))
        self.senderId = senderId
        timestamp = Date().timeIntervalSince1970
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: payload)
    }
}

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}

// MARK: - Payloads

struct JoinRequestPayload: Codable {
    let player: PlayerProfile
}

struct JoinAcceptPayload: Codable {
    let player: PlayerProfile
    let allPlayers: [PlayerProfile]
    let config: RaceConfig
}

struct PlayerProfilePayload: Codable {
    let player: PlayerProfile
}

struct TrackPlacedPayload: Codable {
    let presetId: String
    let transform: TransformPacket
    let scale: Float
    let worldMapChunkCount: Int

    init(presetId: String, transform: TransformPacket, scale: Float, worldMapChunkCount: Int = 0) {
        self.presetId = presetId
        self.transform = transform
        self.scale = scale
        self.worldMapChunkCount = worldMapChunkCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        presetId = try container.decode(String.self, forKey: .presetId)
        transform = try container.decode(TransformPacket.self, forKey: .transform)
        scale = try container.decode(Float.self, forKey: .scale)
        worldMapChunkCount = try container.decodeIfPresent(Int.self, forKey: .worldMapChunkCount) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case presetId, transform, scale, worldMapChunkCount
    }
}

struct WorldMapChunkPayload: Codable {
    let chunkIndex: Int
    let totalChunks: Int
    let data: Data
}

struct RaceStartPayload: Codable {
    let startTime: TimeInterval
    let config: RaceConfig
}

struct CarPosePayload: Codable {
    let playerId: String
    let transform: TransformPacket
    let speed: Float
    let boostActive: Bool

    init(playerId: String, transform: TransformPacket, speed: Float, boostActive: Bool = false) {
        self.playerId = playerId
        self.transform = transform
        self.speed = speed
        self.boostActive = boostActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try container.decode(String.self, forKey: .playerId)
        transform = try container.decode(TransformPacket.self, forKey: .transform)
        speed = try container.decode(Float.self, forKey: .speed)
        boostActive = try container.decodeIfPresent(Bool.self, forKey: .boostActive) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case playerId, transform, speed, boostActive
    }
}

struct LapCompletedPayload: Codable {
    let playerId: String
    let lapNumber: Int
    let lapTime: TimeInterval
    let totalTime: TimeInterval
}

struct RaceEndPayload: Codable {
    let leaderboard: [LeaderboardEntry]
    let reason: String
}

struct PlayerLeftPayload: Codable {
    let playerId: String
    let reason: String
}
