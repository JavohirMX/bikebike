//
//  HostSetupView.swift
//  bikebike
//

import SwiftUI

struct HostSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var showReceipt = false

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
                Spacer()
                
                if let error = appState.sessionErrorMessage {
                    SessionErrorBanner(message: error) {
                        appState.retrySession()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }

                AdaptiveColumnLayout(
                    leftRatio: 0.5,
                    columnSpacing: 40,
                    left: { 
                        if showReceipt {
                            receiptColumn
                                .transition(.move(edge: .bottom))
                        }
                    },
                    right: { instructionsColumn }
                )
            }
            .bikeBikeScreenContent(maxWidth: 760)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .overlay(alignment: .topLeading) {
            BikeBikeBackButton { appState.backFromHostSetup() }
                .padding(.leading, 32)
                .padding(.top, 24)
                .ignoresSafeArea()
        }
        .sheet(isPresented: Binding(
            get: { appState.showConnectionHelp },
            set: { appState.showConnectionHelp = $0 }
        )) {
            MultiplayerConnectionHelpView()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showReceipt = true
            }
            await CarModelLoader.preloadAll()
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
    }

    private var instructionsColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            MultiplayerBanner(title: "Multiplayer")
                .frame(maxWidth: 380, alignment: .center)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 12) {
                instructionRow(1, "Join the same wifi as the host")
                instructionRow(2, "Open the app on the other phone")
                instructionRow(3, "Click the Join Game option")
                instructionRow(4, "Scan the QR to get in to the group")
                instructionRow(5, "Guest picks their driver after joining")
            }
            .padding(.top, 8)

            Spacer(minLength: 0)

            BikeBikePillButton(
                title: "Start Game",
                style: .yellow,
                isEnabled: lobbyReady
            ) {
                if appState.trackPlaced {
                    appState.hostStartRace()
                } else {
                    appState.beginPlacement()
                }
            }
        }
        .padding(.bottom, 24)
    }

    private func instructionRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(BikeBikeTheme.darkBlue)
                .frame(width: 24, alignment: .leading)
            Text(text)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(BikeBikeTheme.darkBlue)
        }
    }
}

#Preview("Waiting for Guest") {
    HostSetupView()
        .environment(PreviewData.appState {
            $0.phase = .hostSetup
            $0.role = .host
            $0.players = [PreviewData.host]
        })
}

#Preview("Guest Connected") {
    HostSetupView()
        .environment(PreviewData.appState {
            $0.phase = .hostSetup
            $0.role = .host
            $0.players = PreviewData.players
        })
}
