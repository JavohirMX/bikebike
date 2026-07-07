//
//  WorldMapTransfer.swift
//  racecar
//

import ARKit
import Foundation

enum WorldMapTransfer {
    static let chunkSize = 512 * 1024

    static func serialize(_ worldMap: ARWorldMap) throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
    }

    static func deserialize(_ data: Data) throws -> ARWorldMap {
        guard let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            throw WorldMapTransferError.invalidData
        }
        return map
    }

    static func chunk(data: Data) -> [Data] {
        guard !data.isEmpty else { return [] }
        var chunks: [Data] = []
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            chunks.append(data.subdata(in: offset..<end))
            offset = end
        }
        return chunks
    }

    static func assemble(chunks: [Int: Data], totalChunks: Int) -> Data? {
        guard totalChunks > 0, chunks.count == totalChunks else { return nil }
        var data = Data()
        for index in 0..<totalChunks {
            guard let chunk = chunks[index] else { return nil }
            data.append(chunk)
        }
        return data
    }
}

enum WorldMapTransferError: Error {
    case invalidData
}
