//
//  GuestSetupView.swift
//  bikebike
//

import SwiftUI

struct GuestSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var showBrowseFallback = false

    var body: some View {
        Group {
            if joinedLobby && appState.trackPlaced && appState.phase != .racing {
                GuestWaitingView()
            } else {
                setupContent
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.showConnectionHelp },
            set: { appState.showConnectionHelp = $0 }
        )) {
            MultiplayerConnectionHelpView()
        }
        .sheet(isPresented: $showBrowseFallback) {
            NavigationStack {
                BrowseSessionsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showBrowseFallback = false }
                        }
                    }
            }
        }
        .onChange(of: appState.isSessionConnected) { _, connected in
            if connected { showBrowseFallback = false }
        }
    }

    private var setupContent: some View {
        MultiplayerSetupShell(
            title: "Join Setup",
            onLeave: { appState.goHome() },
            onHelp: { appState.showConnectionHelp = true },
            banner: {
                Group {
                    if let error = appState.sessionErrorMessage {
                        SessionErrorBanner(message: error) {
                            appState.retrySession()
                        }
                    } else if let lobbyError = appState.lobbySyncErrorMessage {
                        SessionErrorBanner(message: lobbyError) {
                            appState.retrySession()
                        }
                    }
                }
            },
            leftColumn: { leftColumn },
            rightColumn: { rightColumn }
        )
    }

    private var joinedLobby: Bool {
        appState.lobbyReady
    }

    private var guestSteps: [SetupChecklistStep] {
        [
            SetupChecklistStep(
                id: 1,
                title: "Allow local network",
                subtitle: appState.sessionHasStarted ? "Done" : "Pending",
                status: appState.sessionHasStarted ? .done : .pending
            ),
            SetupChecklistStep(
                id: 2,
                title: "Scan host's QR code",
                subtitle: scanSubtitle,
                status: appState.isSessionConnected ? .done : .active
            ),
            SetupChecklistStep(
                id: 3,
                title: "Join lobby",
                subtitle: joinedLobby ? "In lobby" : connectionSubtitle,
                status: joinedLobby ? .done : (appState.isSessionConnected ? .active : (appState.targetHostName != nil ? .active : .pending))
            ),
            SetupChecklistStep(
                id: 4,
                title: "Wait for track",
                subtitle: waitForTrackSubtitle,
                status: appState.trackPlaced ? .done : (appState.isSessionConnected || appState.isRelocalizing ? .active : .pending)
            ),
            SetupChecklistStep(
                id: 5,
                title: "Race starts",
                subtitle: "Host taps Start Race",
                status: appState.phase == .racing ? .done : (appState.trackPlaced ? .active : .pending)
            ),
        ]
    }

    private var scanSubtitle: String {
        if appState.isSessionConnected { return "Done" }
        if let host = appState.targetHostName { return "Looking for \(host)" }
        return "Use scanner on the right"
    }

    private var connectionSubtitle: String {
        if appState.isRelocalizing { return "Aligning AR…" }
        if appState.isSessionConnected { return "Connected" }
        if appState.targetHostName != nil { return "Searching Wi‑Fi…" }
        return "Scan QR first"
    }

    private var waitForTrackSubtitle: String {
        if appState.trackPlaced { return "Track received" }
        if appState.isRelocalizing { return "Aligning to host's table…" }
        return "Host places track"
    }

    @ViewBuilder
    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            SetupChecklistView(steps: guestSteps, compact: true)

            if let joinError = appState.qrJoinErrorMessage {
                Text(joinError)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let lobbyError = appState.lobbySyncErrorMessage, appState.isSessionConnected {
                Text(lobbyError)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if appState.isSessionConnected {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Connected to \(appState.connectedHostName ?? "host")")
                        .font(.caption.bold())
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if joinedLobby {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Text("Joined lobby")
                            .font(.caption.bold())
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Players")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(appState.players) { player in
                        HStack(spacing: 6) {
                            PlayerColorDot(hex: player.carColorHex, size: 8)
                            Text(player.displayName)
                                .font(.caption)
                            if player.isHost {
                                Text("(Host)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("Syncing lobby with host…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Can't scan? Pick from list") {
                showBrowseFallback = true
            }
            .font(.caption)
        }
        .padding(.trailing, 8)
    }

    @ViewBuilder
    private var rightColumn: some View {
        VStack {
            if appState.isRelocalizing {
                Spacer(minLength: 0)
                VStack(spacing: 12) {
                    ProgressView()
                    Text(appState.relocalizationMessage ?? "Aligning to host's table…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Point your phone at the same table as the host.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer(minLength: 0)
            } else if appState.isSessionConnected {
                Spacer(minLength: 0)
                VStack(spacing: 12) {
                    Image(systemName: joinedLobby ? "person.2.fill" : "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(joinedLobby ? .blue : .green)
                    Text(joinedLobby
                         ? (appState.trackPlaced
                            ? "Track placed — waiting for host to start…"
                            : "Joined lobby — waiting for host to place track…")
                         : "Connected — syncing lobby…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer(minLength: 0)
            } else if appState.targetHostName != nil {
                Spacer(minLength: 0)
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Finding \(appState.targetHostName!) on the network…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer(minLength: 0)
            } else {
                QRCodeScannerView { payload in
                    appState.handleScannedJoinLink(payload)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.leading, 8)
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(.secondarySystemBackground).opacity(
            appState.isRelocalizing || appState.isSessionConnected || appState.targetHostName != nil ? 0 : 1
        ))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview("Scanning") {
    GuestSetupView()
        .environment(PreviewData.appState {
            $0.phase = .guestSetup
            $0.role = .guest
        })
}

#Preview("Connected") {
    GuestSetupView()
        .environment(PreviewData.appState {
            $0.phase = .guestSetup
            $0.role = .guest
            $0.isSessionConnected = true
            $0.connectedHostName = "Talin's iPhone"
            $0.players = PreviewData.players
        })
}
