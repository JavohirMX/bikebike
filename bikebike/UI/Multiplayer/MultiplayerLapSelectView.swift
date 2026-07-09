//
//  MultiplayerLapSelectView.swift
//  bikebike
//

import SwiftUI

struct MultiplayerLapSelectView: View {
    @Environment(AppState.self) private var appState
    @State private var controlsOpacity: CGFloat = 0

    var body: some View {
        ZStack {
            BikeBikeBackground()

            HomeBikeScene(mode: .multiplayerParked)
                .padding(.horizontal, 24)

            HStack {
                Spacer()
                
                BikeBikeModalCard {
                    MultiplayerBanner(title: "Multiplayer")
                } content: {
                    VStack(spacing: 28) {
                        Text("Lap Count")
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .foregroundStyle(BikeBikeTheme.skyBlue)
                            .padding(.top, 32)

                        LapCountStepper(
                            value: Binding(
                                get: { appState.raceConfig.lapCount },
                                set: { appState.raceConfig.lapCount = $0 }
                            )
                        )

                        BikeBikePillButton(title: "Continue", style: .yellow) {
                            appState.confirmMultiplayerLapSelect()
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
                appState.backFromMultiplayerLapSelect()
            }
            .padding(.leading, 32)
            .padding(.top, 24)
            .ignoresSafeArea()
        }
        .onAppear {
            fadeInControls()
        }
    }

    private func fadeInControls() {
        controlsOpacity = 0
        withAnimation(.easeOut(duration: 0.35)) {
            controlsOpacity = 1
        }
    }
}

#Preview("Multiplayer Lap Select") {
    MultiplayerLapSelectView()
        .environment(PreviewData.appState {
            $0.phase = .multiplayerLapSelect
            $0.role = .host
        })
}
