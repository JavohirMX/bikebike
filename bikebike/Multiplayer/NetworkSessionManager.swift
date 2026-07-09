//
//  NetworkSessionManager.swift
//  bikebike
//

import Foundation
import Network
import UIKit

@MainActor
protocol RaceSessionDelegate: AnyObject {
    func sessionDidDiscover(_ session: SessionInfo)
    func sessionDidLose(_ sessionId: String)
    func sessionPeerConnected(_ peerId: String)
    func sessionPeerDisconnected(_ peerId: String)
    func sessionDidReceive(_ envelope: RaceEnvelope, from peerId: String)
    func sessionDidFailToStart(error: Error)
}

@MainActor
final class NetworkSessionManager {
    static let serviceType = "bikebike"
    private static let bonjourType = "_bikebike._tcp"
    private static let peerIdKey = "bikebike.localPeerId"

    weak var delegate: RaceSessionDelegate?

    private(set) var isHost = false
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [ObjectIdentifier: PeerConnection] = [:]
    private var discoveredEndpoints: [String: NWEndpoint] = [:]
    private var announcedSessionIds = Set<String>()
    private var connectedPeerIdSet = Set<String>()
    private var activeConnectSessionId: String?
    private var maxGuestConnections = MultiplayerConstants.maxGuestConnections
    private var bonjourTXT: NWTXTRecord?

    private let localPeerId: String
    private var deviceDisplayName: String

    /// Unique player identity used in game messages and car state.
    var localPlayerId: String { localPeerId }
    /// Device name used for Bonjour discovery and QR codes.
    var localDisplayName: String { deviceDisplayName }

    @discardableResult
    func setPlayerDisplayName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        deviceDisplayName = trimmed
        return true
    }
    var connectedPeerIds: [String] { Array(connectedPeerIdSet) }
    var isBrowsing: Bool { browser != nil }

    var isConnectingToHost: Bool {
        !isHost && !connections.isEmpty && !connections.values.contains(where: \.isReady)
    }

    var hasPendingGuestConnection: Bool {
        isHost && connections.values.contains { $0.peerId.hasPrefix("guest-") }
    }

    init() {
        deviceDisplayName = UIDevice.current.name
        localPeerId = Self.loadOrCreatePeerId()
    }

    func startHosting(sessionInfo: SessionInfo) {
        stopAll()
        isHost = true
        maxGuestConnections = sessionInfo.maxPlayers - 1

        let parameters = tcpParameters()
        do {
            let listener = try NWListener(using: parameters)
            var txt = NWTXTRecord()
            txt["host"] = sessionInfo.hostName
            txt["laps"] = "\(sessionInfo.lapCount)"
            txt["track"] = sessionInfo.trackId
            txt["peerId"] = sessionInfo.peerID
            txt["maxPlayers"] = "\(sessionInfo.maxPlayers)"
            txt["players"] = "\(sessionInfo.playerCount)"
            bonjourTXT = txt
            listener.service = NWListener.Service(name: nil, type: Self.bonjourType, domain: nil, txtRecord: txt)

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let manager = self else { return }
                    if case .failed(let error) = state {
                        manager.delegate?.sessionDidFailToStart(error: error)
                    }
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.acceptIncoming(connection)
                }
            }

            listener.start(queue: .main)
            self.listener = listener
        } catch {
            delegate?.sessionDidFailToStart(error: error)
        }
    }

    func startBrowsing() {
        stopBrowsing()
        let parameters = tcpParameters()
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: Self.bonjourType, domain: nil), using: parameters)
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let manager = self else { return }
                if case .failed(let error) = state {
                    manager.delegate?.sessionDidFailToStart(error: error)
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.handleBrowseResults(results)
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func refreshBrowsing() {
        startBrowsing()
    }

    func connect(to session: SessionInfo) {
        guard !isHost else { return }
        guard let endpoint = discoveredEndpoints[session.sessionId] else { return }

        if activeConnectSessionId == session.sessionId {
            if connections.values.contains(where: { $0.isReady && $0.peerId == session.hostName }) {
                return
            }
            if connections.values.contains(where: { !$0.isReady }) {
                return
            }
        }

        guard connections.isEmpty else { return }

        activeConnectSessionId = session.sessionId
        let connection = NWConnection(to: endpoint, using: tcpParameters())
        attachConnection(connection, peerId: session.hostName, announceConnect: true)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    func stopAll() {
        listener?.cancel()
        listener = nil
        stopBrowsing()
        for connection in connections.values {
            connection.nwConnection.cancel()
        }
        connections.removeAll()
        discoveredEndpoints.removeAll()
        announcedSessionIds.removeAll()
        connectedPeerIdSet.removeAll()
        activeConnectSessionId = nil
        isHost = false
        maxGuestConnections = MultiplayerConstants.maxGuestConnections
        bonjourTXT = nil
    }

    func updateAdvertisedPlayerCount(_ count: Int) {
        guard isHost, let listener, var txt = bonjourTXT else { return }
        txt["players"] = "\(count)"
        bonjourTXT = txt
        listener.service = NWListener.Service(name: nil, type: Self.bonjourType, domain: nil, txtRecord: txt)
    }

    func send(_ envelope: RaceEnvelope, reliable: Bool, to peerId: String) {
        guard let data = try? LengthPrefixedMessageCodec.encode(envelope) else { return }
        guard let connection = connections.values.first(where: { $0.peerId == peerId && $0.isReady }) else { return }
        sendData(data, on: connection.nwConnection, coalesce: !reliable)
    }

    func send(_ envelope: RaceEnvelope, reliable: Bool, excluding excludedPeerId: String? = nil) {
        guard let data = try? LengthPrefixedMessageCodec.encode(envelope) else { return }
        for connection in connections.values where connection.peerId != excludedPeerId && connection.isReady {
            sendData(data, on: connection.nwConnection, coalesce: !reliable)
        }
    }

    func sendToHost(_ envelope: RaceEnvelope, reliable: Bool) {
        guard let data = try? LengthPrefixedMessageCodec.encode(envelope) else { return }
        guard let hostConnection = connections.values.first(where: \.isReady) else { return }
        sendData(data, on: hostConnection.nwConnection, coalesce: !reliable)
    }

    func encode<T: Encodable>(type: RaceMessageType, payload: T) throws -> RaceEnvelope {
        try RaceEnvelope(type: type, payload: payload, senderId: localPlayerId)
    }

    func updatePeerId(for connection: NWConnection, to peerId: String) {
        let key = ObjectIdentifier(connection)
        guard var state = connections[key] else { return }
        let oldPeerId = state.peerId
        if oldPeerId != peerId {
            connectedPeerIdSet.remove(oldPeerId)
            state.peerId = peerId
            connections[key] = state
            connectedPeerIdSet.insert(peerId)
        }
    }

    // MARK: - Private

    private static func loadOrCreatePeerId() -> String {
        if let existing = UserDefaults.standard.string(forKey: peerIdKey), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: peerIdKey)
        return id
    }

    private func tcpParameters() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        return parameters
    }

    private func acceptIncoming(_ connection: NWConnection) {
        let placeholderId = "guest-\(UUID().uuidString.prefix(8))"
        attachConnection(connection, peerId: placeholderId, announceConnect: false)
    }

    private func attachConnection(_ connection: NWConnection, peerId: String, announceConnect: Bool) {
        if isHost {
            if connections.count >= maxGuestConnections {
                connection.cancel()
                return
            }
        } else if !connections.isEmpty {
            connection.cancel()
            return
        }

        let key = ObjectIdentifier(connection)
        connections[key] = PeerConnection(
            peerId: peerId,
            nwConnection: connection,
            receiveBuffer: Data(),
            isReady: false,
            pendingCoalescedData: nil,
            isSendInFlight: false
        )

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let manager = self else { return }
                switch state {
                case .ready:
                    manager.markConnectionReady(connection)
                    if announceConnect {
                        manager.markConnected(peerId: peerId)
                        manager.delegate?.sessionPeerConnected(peerId)
                    }
                    manager.receiveLoop(connection: connection)
                case .failed, .cancelled:
                    manager.removeConnection(connection)
                default:
                    break
                }
            }
        }
        connection.start(queue: .main)
    }

    private func markConnectionReady(_ connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        guard var state = connections[key] else { return }
        state.isReady = true
        connections[key] = state
    }

    private func markConnected(peerId: String) {
        connectedPeerIdSet.insert(peerId)
    }

    private func receiveLoop(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let manager = self else { return }
                if let data, !data.isEmpty {
                    manager.handleReceived(data, connection: connection)
                }
                if isComplete || error != nil {
                    manager.removeConnection(connection)
                    return
                }
                manager.receiveLoop(connection: connection)
            }
        }
    }

    private func handleReceived(_ data: Data, connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        guard var state = connections[key] else { return }
        state.receiveBuffer.append(data)

        while let (message, remaining) = LengthPrefixedMessageCodec.nextMessage(from: state.receiveBuffer) {
            state.receiveBuffer = remaining
            connections[key] = state
            guard let envelope = try? JSONDecoder().decode(RaceEnvelope.self, from: message) else { continue }

            if isHost, envelope.type == .joinRequest,
               let payload = try? envelope.decode(JoinRequestPayload.self) {
                let guestId = payload.player.peerId
                let wasPlaceholder = state.peerId.hasPrefix("guest-")
                updatePeerId(for: connection, to: guestId)
                state = connections[key] ?? state
                if wasPlaceholder {
                    markConnected(peerId: guestId)
                    delegate?.sessionPeerConnected(guestId)
                }
                delegate?.sessionDidReceive(envelope, from: guestId)
            } else {
                let peerId = connections[key]?.peerId ?? envelope.senderId
                delegate?.sessionDidReceive(envelope, from: peerId)
            }
        }
        connections[key] = state
    }

    private func removeConnection(_ connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        guard let state = connections.removeValue(forKey: key) else { return }
        connectedPeerIdSet.remove(state.peerId)
        if connections.isEmpty {
            activeConnectSessionId = nil
        }
        if !state.peerId.hasPrefix("guest-") {
            delegate?.sessionPeerDisconnected(state.peerId)
        }
        connection.cancel()
    }

    private func sendData(_ data: Data, on connection: NWConnection, coalesce: Bool) {
        if coalesce {
            enqueueCoalescedSend(data, on: connection)
        } else {
            connection.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    private func enqueueCoalescedSend(_ data: Data, on connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        guard var state = connections[key] else { return }
        state.pendingCoalescedData = data
        connections[key] = state
        flushCoalescedSend(on: connection)
    }

    private func flushCoalescedSend(on connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        guard var state = connections[key], !state.isSendInFlight, let data = state.pendingCoalescedData else { return }
        state.isSendInFlight = true
        state.pendingCoalescedData = nil
        connections[key] = state

        connection.send(content: data, completion: .contentProcessed { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let manager = self else { return }
                let key = ObjectIdentifier(connection)
                guard var state = manager.connections[key] else { return }
                state.isSendInFlight = false
                manager.connections[key] = state
                manager.flushCoalescedSend(on: connection)
            }
        })
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        var activeIds = Set<String>()

        for result in results {
            guard case .service = result.endpoint else { continue }
            let txt = txtRecord(from: result.metadata)
            let hostName = txt["host"] ?? result.endpoint.debugDescription
            let sessionId = hostName
            activeIds.insert(sessionId)
            discoveredEndpoints[sessionId] = result.endpoint

            let session = SessionInfo(
                sessionId: sessionId,
                hostName: hostName,
                trackId: txt["track"] ?? RaceTrackCatalog.defaultTrackId,
                lapCount: Int(txt["laps"] ?? "3") ?? 3,
                playerCount: Int(txt["players"] ?? "1") ?? 1,
                maxPlayers: Int(txt["maxPlayers"] ?? "") ?? MultiplayerConstants.maxPlayers,
                phase: .lobby,
                peerID: txt["peerId"] ?? hostName
            )

            if !announcedSessionIds.contains(sessionId) {
                announcedSessionIds.insert(sessionId)
                delegate?.sessionDidDiscover(session)
            }
        }

        let lost = announcedSessionIds.subtracting(activeIds)
        for sessionId in lost {
            announcedSessionIds.remove(sessionId)
            discoveredEndpoints.removeValue(forKey: sessionId)
            delegate?.sessionDidLose(sessionId)
        }
    }

    private func txtRecord(from metadata: NWBrowser.Result.Metadata) -> [String: String] {
        guard case .bonjour(let record) = metadata else { return [:] }
        var values: [String: String] = [:]
        for key in record.dictionary.keys {
            if let value = record[key] {
                values[key] = value
            }
        }
        return values
    }
}

private struct PeerConnection {
    var peerId: String
    let nwConnection: NWConnection
    var receiveBuffer: Data
    var isReady: Bool
    var pendingCoalescedData: Data?
    var isSendInFlight: Bool
}
