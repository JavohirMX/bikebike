//
//  SoloDriverSelectView.swift
//  bikebike
//

import SwiftUI

struct SoloDriverSelectView: View {
    @Environment(AppState.self) private var appState
    @State private var controlsOpacity: CGFloat = 0

    private var selectedDriverId: String {
        appState.localSelectedDriverId
    }

    var body: some View {
        ZStack {
            BikeBikeBackground()

            if appState.homeDeparture == nil {
                HomeBikeScene(mode: .parked)
                    .padding(.horizontal, 24)
            }

            HStack {
                Spacer()

                BikeBikeModalCard {
                    MultiplayerBanner(title: "Singleplayer")
                } content: {
                    VStack(spacing: 12) {
                        Text("Select Your Driver")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(BikeBikeTheme.skyBlue)
                            .padding(.top, 8)

                        DriverSelectGrid(
                            selectedDriverId: selectedDriverId,
                            takenDriverIds: [],
                            takenByName: [:],
                            compact: true
                        ) { driverId in
                            appState.selectDriver(driverId)
                        }

                        if let error = appState.driverSelectionError {
                            Text(error)
                                .font(BikeBikeTheme.captionFont(size: 13))
                                .foregroundStyle(.red)
                        }

                        BikeBikePillButton(title: "Continue", style: .yellow) {
                            appState.confirmSoloDriverSelect()
                        }
                        .padding(.bottom, 4)
                    }
                }
                .frame(width: 340)
                .padding(.trailing, 72)
                .opacity(controlsOpacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if appState.homeDeparture == nil {
                BikeBikeBackButton { appState.backFromSoloDriverSelect() }
                    .padding(.leading, 32)
                    .padding(.top, 24)
                    .ignoresSafeArea()
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

#Preview("Solo Driver Select") {
    SoloDriverSelectView()
        .environment(PreviewData.appState {
            $0.phase = .soloDriverSelect
            $0.role = .solo
            $0.players = [PreviewData.host]
        })
}
