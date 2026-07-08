//
//  MultiplayerRolePickerView.swift
//  bikebike
//

import SwiftUI

struct MultiplayerRolePickerView: View {
    @Environment(AppState.self) private var appState
    @State private var controlsOpacity: CGFloat = 0

    var body: some View {
        ZStack {
            BikeBikeBackground()

            HomeBikeScene(mode: .multiplayerParked)
                .padding(.horizontal, 24)

            VStack {
                HStack {
                    BikeBikeBackButton { appState.goHome() }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer()

                VStack(spacing: 20) {
                    MultiplayerBanner(title: "Multiplayer")

                    VStack(spacing: 14) {
                        BikeBikePillButton(title: "Create Game", style: .yellow) {
                            appState.selectMultiplayerRole(.host)
                        }

                        BikeBikePillButton(title: "Join Game", style: .blue) {
                            appState.selectMultiplayerRole(.guest)
                        }
                    }
                    .frame(width: 280)
                }
                .bikeBikeScreenContent(maxWidth: 400)
                .offset(x: 160, y: -40)
                .opacity(controlsOpacity)

                Spacer()
            }
        }
        .onAppear {
            if appState.homeDeparture == nil {
                fadeInControls()
            }
        }
        .onChange(of: appState.homeDeparture) { _, departure in
            if departure == nil {
                fadeInControls()
            } else {
                controlsOpacity = 0
            }
        }
    }

    private func fadeInControls() {
        controlsOpacity = 0
        withAnimation(.easeOut(duration: 0.35)) {
            controlsOpacity = 1
        }
    }
}

#Preview("Role Picker", traits: .landscapeLeft) {
    MultiplayerRolePickerView()
        .environment(PreviewData.appState { $0.phase = .multiplayerRolePicker })
}
