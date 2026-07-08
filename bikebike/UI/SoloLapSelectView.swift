//
//  SoloLapSelectView.swift
//  bikebike
//

import SwiftUI

struct SoloLapSelectView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            BikeBikeBackground(blurRadius: 6)

            HStack {
                Spacer()
                
                BikeBikeModalCard {
                    HeadingBanner(title: "Singleplayer")
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
            }
        }
        .overlay(alignment: .topLeading) {
            BikeBikeBackButton { appState.goHome() }
                .padding(.leading, 32)
                .padding(.top, 24)
                .ignoresSafeArea()
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
