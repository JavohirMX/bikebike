//
//  HostLobbyView.swift
//  bikebike
//

import SwiftUI

struct HostLobbyView: View {
  @Environment(AppState.self) private var appState

    var body: some View {
        lobbyContent(
            title: "Host Lobby",
            showPlaceTrack: !appState.trackPlaced && appState.lobbyReady,
            showStart: appState.trackPlaced,
            hostHint: "Have your friend tap Join Nearby on the same Wi‑Fi or Personal Hotspot while you stay here.",
            onPlace: { appState.beginPlacement() },
            onStart: { appState.hostStartRace() },
            onResend: { appState.resendTrack() }
        )
    }
}

struct GuestLobbyView: View {
  @Environment(AppState.self) private var appState

    var body: some View {
        lobbyContent(
            title: "Guest Lobby",
            showPlaceTrack: false,
            showStart: false,
            hostHint: nil,
            onPlace: {},
            onStart: {},
            onResend: {}
        )
        .overlay(alignment: .top) {
            connectionStatusBanner
                .padding(.top, 56)
        }
        .overlay(alignment: .bottom) {
            if appState.trackPlaced {
                Text("Track placed — waiting for host to start…")
                    .font(.subheadline)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
            } else {
                Text("Waiting for host to place track…")
                    .font(.subheadline)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var connectionStatusBanner: some View {
        if appState.isSessionConnected, let host = appState.connectedHostName {
            Text("Connected to \(host)")
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.green.opacity(0.15))
                .clipShape(Capsule())
        } else {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("Connecting to host…")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
    }
}

private func lobbyContent(
    title: String,
    showPlaceTrack: Bool,
    showStart: Bool,
    hostHint: String?,
    onPlace: @escaping () -> Void,
    onStart: @escaping () -> Void,
    onResend: @escaping () -> Void
) -> some View {
    LobbyShell(title: title, showPlaceTrack: showPlaceTrack, showStart: showStart, hostHint: hostHint, onPlace: onPlace, onStart: onStart, onResend: onResend)
}

private struct LobbyShell: View {
  @Environment(AppState.self) private var appState
    let title: String
    let showPlaceTrack: Bool
    let showStart: Bool
    let hostHint: String?
    let onPlace: () -> Void
    let onStart: () -> Void
    let onResend: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Leave") { appState.goHome() }
                Spacer()
                Text(title).font(.headline)
                Spacer()
                Color.clear.frame(width: 50)
            }
            .padding()

            if let hostHint, appState.role == .host {
                Text(hostHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Stepper(
                "Laps: \(appState.raceConfig.lapCount)",
                value: Binding(
                    get: { appState.raceConfig.lapCount },
                    set: { appState.setLapCount($0) }
                ),
                in: 1...10
            )
                .padding(.horizontal)
                .disabled(appState.role != .host)

            Text("Players (\(appState.players.count)/\(MultiplayerConstants.maxPlayers))")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            List(appState.players) { player in
                HStack {
                    PlayerColorDot(hex: DriverCatalog.accentColorHex(for: player.driverId), size: 12)
                    Text(player.displayName)
                    Text("· \(DriverCatalog.driver(for: player.driverId).displayName)")
                        .foregroundStyle(.secondary)
                    if player.isHost { Text("(Host)").foregroundStyle(.secondary) }
                }
            }
            .listStyle(.plain)

            if appState.role == .host || appState.role == .guest {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Driver")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DriverSelectGrid(
                        selectedDriverId: appState.localSelectedDriverId,
                        takenDriverIds: appState.takenDriverIds,
                        takenByName: appState.takenDriverNames,
                        compact: true
                    ) { driverId in
                        appState.selectDriver(driverId)
                    }
                    .padding(.horizontal)

                    if let error = appState.driverSelectionError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
            }

            if showPlaceTrack {
                Button("Place Track", action: onPlace)
                    .buttonStyle(.borderedProminent)
            } else if appState.role == .host && !appState.trackPlaced && appState.isSessionConnected && !appState.lobbyReady {
                Text("Waiting for guest to connect…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if appState.trackPlaced && appState.role == .host {
                Button("Resend Track (debug)", action: onResend)
                    .font(.caption)
            }
            if showStart {
                Button("Start Race", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.players.count < 2)
            }
            if showStart && appState.players.count < 2 {
                Text("Waiting for guest to connect…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .bikeBikeScreenContent(maxWidth: 520)
        .background(Color(.systemBackground))
    }
}

#Preview("Host Lobby") {
    HostLobbyView()
        .environment(PreviewData.appState {
            $0.phase = .hostLobby
            $0.role = .host
            $0.players = PreviewData.players
            $0.isSessionConnected = true
        })
}

#Preview("Host Lobby – Track Placed") {
    HostLobbyView()
        .environment(PreviewData.appState {
            $0.phase = .hostLobby
            $0.role = .host
            $0.players = PreviewData.players
            $0.isSessionConnected = true
            $0.trackPlaced = true
        })
}

#Preview("Guest Lobby") {
    GuestLobbyView()
        .environment(PreviewData.appState {
            $0.phase = .guestLobby
            $0.role = .guest
            $0.players = PreviewData.players
            $0.isSessionConnected = true
            $0.connectedHostName = "Talin's iPhone"
        })
}
