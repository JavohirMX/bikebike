//
//  HostSetupView.swift
//  racecar
//

import SwiftUI

struct HostSetupView: View {
    @Environment(AppState.self) private var appState

    private var lobbyReady: Bool {
        appState.lobbyReady
    }

    private var guestConnected: Bool {
        lobbyReady
    }

    private var joinURLString: String {
        JoinLink.buildURL(hostName: appState.raceSession.localDisplayName)?.absoluteString ?? ""
    }

    var body: some View {
        MultiplayerSetupShell(
            title: "Host Setup",
            onLeave: { appState.goHome() },
            onHelp: { appState.showConnectionHelp = true },
            banner: {
                Group {
                    if let error = appState.sessionErrorMessage {
                        SessionErrorBanner(message: error) {
                            appState.retrySession()
                        }
                    }
                }
            },
            leftColumn: { leftColumn },
            rightColumn: { rightColumn }
        )
        .sheet(isPresented: Binding(
            get: { appState.showConnectionHelp },
            set: { appState.showConnectionHelp = $0 }
        )) {
            MultiplayerConnectionHelpView()
        }
    }

    private var hostSteps: [SetupChecklistStep] {
        [
            SetupChecklistStep(
                id: 1,
                title: "Allow local network",
                subtitle: appState.sessionHasStarted ? "Done" : "Tap Continue first",
                status: appState.sessionHasStarted ? .done : .pending
            ),
            SetupChecklistStep(
                id: 2,
                title: "Friend scans your code",
                subtitle: "Show QR on the right",
                status: guestConnected ? .done : .active
            ),
            SetupChecklistStep(
                id: 3,
                title: "Guest connected",
                subtitle: guestConnected ? "Ready" : "Waiting…",
                status: guestConnected ? .done : (appState.sessionHasStarted ? .active : .pending)
            ),
            SetupChecklistStep(
                id: 4,
                title: "Place track",
                subtitle: appState.trackPlaced ? "Done" : "After guest joins",
                status: appState.trackPlaced ? .done : (guestConnected ? .active : .pending)
            ),
            SetupChecklistStep(
                id: 5,
                title: "Start race",
                subtitle: "When track is placed",
                status: appState.phase == .racing ? .done : (appState.trackPlaced ? .active : .pending)
            ),
        ]
    }

    @ViewBuilder
    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            SetupChecklistView(steps: hostSteps, compact: true)

            if !appState.players.isEmpty {
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
            }

            if appState.raceSession.hasPendingGuestConnection && !lobbyReady {
                Text("Guest connecting…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if appState.isSessionConnected && !lobbyReady {
                Text("Waiting for guest to join lobby…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Stepper(
                "Laps: \(appState.raceConfig.lapCount)",
                value: Binding(
                    get: { appState.raceConfig.lapCount },
                    set: { appState.raceConfig.lapCount = $0 }
                ),
                in: 1...10
            )
            .font(.caption)

            if lobbyReady && !appState.trackPlaced {
                Button("Place Track") {
                    appState.beginPlacement()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if appState.trackPlaced {
                Button("Start Race") {
                    appState.hostStartRace()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!lobbyReady)

                if !lobbyReady {
                    Text("Waiting for guest to connect…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button("Resend Track") {
                    appState.resendTrack()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.trailing, 8)
    }

    @ViewBuilder
    private var rightColumn: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            if !joinURLString.isEmpty {
                VStack(spacing: 10) {
                    QRCodeView(urlString: joinURLString, size: 160)
                    Text("Friend taps I'm joining → scans this code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
    }
}
