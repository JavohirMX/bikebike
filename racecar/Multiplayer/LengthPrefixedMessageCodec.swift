//
//  LengthPrefixedMessageCodec.swift
//  racecar
//

import Foundation

enum LengthPrefixedMessageCodec {
    private static let lengthFieldSize = MemoryLayout<UInt32>.size
    private static let maxMessageLength = 16 * 1024 * 1024

    static func encode(_ envelope: RaceEnvelope) throws -> Data {
        let body = try JSONEncoder().encode(envelope)
        guard body.count <= maxMessageLength else {
            throw CodecError.messageTooLarge
        }
        var length = UInt32(body.count).bigEndian
        var packet = Data(bytes: &length, count: lengthFieldSize)
        packet.append(body)
        return packet
    }

    /// Returns the next complete message body and remaining buffer, if available.
    static func nextMessage(from buffer: Data) -> (message: Data, remaining: Data)? {
        guard buffer.count >= lengthFieldSize else { return nil }
        let lengthData = buffer.prefix(lengthFieldSize)
        let length = lengthData.withUnsafeBytes { ptr in
            UInt32(bigEndian: ptr.load(as: UInt32.self))
        }
        guard length > 0, Int(length) <= maxMessageLength else { return nil }
        let totalSize = lengthFieldSize + Int(length)
        guard buffer.count >= totalSize else { return nil }
        let message = buffer.subdata(in: lengthFieldSize..<totalSize)
        let remaining = buffer.subdata(in: totalSize..<buffer.count)
        return (message, remaining)
    }

    enum CodecError: Error {
        case messageTooLarge
    }
}
