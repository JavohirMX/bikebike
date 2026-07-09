//
//  MultiplayerHostDriverSelectView.swift
//  bikebike
//

import SwiftUI

struct MultiplayerHostDriverSelectView: View {
    @Environment(AppState.self) private var appState
    @State private var controlsOpacity: CGFloat = 0

    private var selectedDriverId: String {
        appState.localSelectedDriverId
    }

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
                    VStack(spacing: 12) {
                        Text("Select Your Driver")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(BikeBikeTheme.skyBlue)
                            .padding(.top, 8)

                        DriverSelectGrid(
                            selectedDriverId: selectedDriverId,
                            takenDriverIds: appState.takenDriverIds,
                            takenByName: appState.takenDriverNames,
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
                            appState.confirmMultiplayerHostDriverSelect()
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
            BikeBikeBackButton { appState.backFromMultiplayerHostDriverSelect() }
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

#Preview("Host Driver Select") {
    MultiplayerHostDriverSelectView()
        .environment(PreviewData.appState {
            $0.phase = .multiplayerHostDriverSelect
            $0.role = .solo
        })
}
