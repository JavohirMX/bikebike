//
//  MultiplayerNicknameView.swift
//  bikebike
//

import SwiftUI

struct MultiplayerNicknameView: View {
    @Environment(AppState.self) private var appState
    @State private var nickname = ""
    @State private var controlsOpacity: CGFloat = 0

    private var isValid: Bool {
        NicknameValidator.isValid(nickname)
    }

    private var primaryButtonTitle: String {
        switch appState.pendingMultiplayerRole {
        case .host:
            "Create Game"
        case .guest:
            "Scan QR Code"
        default:
            "Continue"
        }
    }

    var body: some View {
        ZStack {
            BikeBikeBackground()

            HomeBikeScene(mode: .multiplayerParked)
                .padding(.horizontal, 24)

            HStack {
                Spacer()

                BikeBikeModalCard {
                    MultiplayerBanner(title: "Let's Play!")
                } content: {
                    VStack(spacing: 28) {
                        BikeBikeNicknameField(text: $nickname) {
                            confirmIfValid()
                        }
                        .padding(.top, 32)

                        BikeBikePillButton(
                            title: primaryButtonTitle,
                            style: .yellow,
                            isEnabled: isValid
                        ) {
                            confirmIfValid()
                        }
                        .padding(.bottom, 8)
                    }
                }
                .frame(width: 380)
                .padding(.trailing, 40)
                .opacity(controlsOpacity)
            }
        }
        .overlay(alignment: .topLeading) {
            BikeBikeBackButton {
                appState.backFromMultiplayerNickname()
            }
            .padding(.leading, 32)
            .padding(.top, 24)
            .ignoresSafeArea()
        }
        .onAppear {
            nickname = appState.savedPlayerNickname()
            fadeInControls()
        }
    }

    private func confirmIfValid() {
        guard isValid else { return }
        appState.confirmMultiplayerNickname(nickname)
    }

    private func fadeInControls() {
        controlsOpacity = 0
        withAnimation(.easeOut(duration: 0.35)) {
            controlsOpacity = 1
        }
    }
}

#Preview("Host Nickname", traits: .landscapeLeft) {
    MultiplayerNicknameView()
        .environment(PreviewData.appState {
            $0.selectMultiplayerRole(.host)
        })
}

#Preview("Guest Nickname", traits: .landscapeLeft) {
    MultiplayerNicknameView()
        .environment(PreviewData.appState {
            $0.selectMultiplayerRole(.guest)
        })
}
