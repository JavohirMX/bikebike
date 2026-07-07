//
//  HostSetupView.swift
//  bikebike
//

import SwiftUI

struct HostSetupView: View {
    @Environment(AppState.self) private var appState

    private var lobbyReady: Bool {
        appState.lobbyReady
    }

    private var joinURLString: String {
        JoinLink.buildURL(hostName: appState.raceSession.localDisplayName)?.absoluteString ?? ""
    }

    var body: some View {
        ZStack {
            BikeBikeBackground(blurRadius: 4)

            VStack(spacing: 0) {
                HStack {
                    BikeBikeBackButton { appState.goHome() }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if let error = appState.sessionErrorMessage {
                    SessionErrorBanner(message: error) {
                        appState.retrySession()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }

                HStack(alignment: .top, spacing: 24) {
                    receiptColumn
                        .frame(maxWidth: .infinity)

                    instructionsColumn
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.showConnectionHelp },
            set: { appState.showConnectionHelp = $0 }
        )) {
            MultiplayerConnectionHelpView()
        }
    }

    private var receiptColumn: some View {
        ReceiptPanel {
            VStack(spacing: 8) {
                Text("Room QR")
                    .font(BikeBikeTheme.bodyFont(size: 18))
                    .foregroundStyle(BikeBikeTheme.darkBlue)

                if !joinURLString.isEmpty {
                    QRCodeView(urlString: joinURLString, size: 140)
                }

                Text("Scan to join the game")
                    .font(BikeBikeTheme.captionFont(size: 13))
                    .foregroundStyle(BikeBikeTheme.darkBlue.opacity(0.7))

                ReceiptDashedDivider()

                Text("Players")
                    .font(BikeBikeTheme.bodyFont(size: 16))
                    .foregroundStyle(BikeBikeTheme.darkBlue)

                if appState.players.isEmpty {
                    Text("Waiting for players...")
                        .font(BikeBikeTheme.captionFont(size: 12))
                        .foregroundStyle(BikeBikeTheme.darkBlue.opacity(0.5))
                } else {
                    PlayerAvatarGrid(players: appState.players)
                }
            }
        }
        .frame(maxHeight: 420)
    }

    private var instructionsColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            MultiplayerBanner()
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 12) {
                instructionRow(1, "Open the app on the other phone")
                instructionRow(2, "Click the join a team option")
                instructionRow(3, "Scan the QR to get in to the group")
                instructionRow(4, "Enter user nickname")
            }

            Spacer(minLength: 0)

            if lobbyReady && !appState.trackPlaced {
                BikeBikePillButton(title: "Place Track", style: .blue) {
                    appState.beginPlacement()
                }
            }

            if appState.trackPlaced {
                BikeBikePillButton(
                    title: "Start Game",
                    style: .yellow,
                    isEnabled: lobbyReady
                ) {
                    appState.hostStartRace()
                }

                if !lobbyReady {
                    Text("Waiting for guest to connect...")
                        .font(BikeBikeTheme.captionFont(size: 12))
                        .foregroundStyle(BikeBikeTheme.darkBlue.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else if lobbyReady {
                Text("Guest connected — place the track to continue")
                    .font(BikeBikeTheme.captionFont(size: 12))
                    .foregroundStyle(BikeBikeTheme.darkBlue.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("Waiting for guest to scan QR...")
                    .font(BikeBikeTheme.captionFont(size: 12))
                    .foregroundStyle(BikeBikeTheme.darkBlue.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxHeight: 420)
    }

    private func instructionRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .font(BikeBikeTheme.bodyFont(size: 16))
                .foregroundStyle(BikeBikeTheme.darkBlue)
                .frame(width: 24, alignment: .leading)
            Text(text)
                .font(BikeBikeTheme.captionFont(size: 15))
                .foregroundStyle(BikeBikeTheme.darkBlue)
        }
    }
}
