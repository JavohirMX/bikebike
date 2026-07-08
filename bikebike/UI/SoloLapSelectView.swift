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

            VStack {
                HStack {
                    BikeBikeBackButton { appState.goHome() }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer()

                BikeBikeModalCard {
                    MultiplayerBanner()
                } content: {
                    VStack(spacing: 20) {
                        Text("Lap Count")
                            .font(BikeBikeTheme.bodyFont(size: 20))
                            .foregroundStyle(BikeBikeTheme.darkBlue)

                        LapCountStepper(
                            value: Binding(
                                get: { appState.raceConfig.lapCount },
                                set: { appState.raceConfig.lapCount = $0 }
                            )
                        )

                        TrackOptionPicker()

                        BikeBikePillButton(title: "Place Track", style: .yellow) {
                            appState.confirmSoloLapSelect()
                        }
                        .padding(.top, 8)
                    }
                }
                .bikeBikeScreenContent(maxWidth: 380)

                Spacer()
            }
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
