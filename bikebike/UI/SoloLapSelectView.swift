//
//  SoloLapSelectView.swift
//  bikebike
//

import SwiftUI

struct SoloLapSelectView: View {
    @Environment(AppState.self) private var appState
    @State private var controlsOpacity: CGFloat = 0

    var body: some View {
        ZStack {
            BikeBikeBackground()

            HomeBikeScene(mode: .parked)
                .padding(.horizontal, 24)

            HStack {
                Spacer()
                
                BikeBikeModalCard {
                    MultiplayerBanner(title: "Singleplayer")
                } content: {
                    VStack(spacing: 28) {
                        Text("Lap Count")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(BikeBikeTheme.skyBlue)
                            .padding(.top, 24) // Increased top padding

                        LapCountStepper(
                            value: Binding(
                                get: { appState.raceConfig.lapCount },
                                set: { appState.raceConfig.lapCount = $0 }
                            )
                        )

                        BikeBikePillButton(title: "Place Track", style: .yellow) {
                            appState.confirmSoloLapSelect()
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
            BikeBikeBackButton { appState.goHome() }
                .padding(.leading, 32)
                .padding(.top, 24)
                .ignoresSafeArea()
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

#Preview("Solo Lap Select") {
    SoloLapSelectView()
        .environment(PreviewData.appState {
            $0.phase = .soloLapSelect
            $0.role = .solo
        })
}
