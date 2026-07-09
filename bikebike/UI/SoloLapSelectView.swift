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

            if appState.homeDeparture == nil {
                HomeBikeScene(mode: .parked)
                    .padding(.horizontal, 24)
            }

            HStack {
                Spacer()
                
                BikeBikeModalCard {
                    MultiplayerBanner(title: "Singleplayer")
                } content: {
                    RaceSetupPanel(continueTitle: "Place Track") {
                        appState.confirmSoloLapSelect()
                    }
                }
                .frame(width: 420)
                .padding(.trailing, 40)
                .opacity(controlsOpacity)
            }
        }
        .overlay(alignment: .topLeading) {
            BikeBikeBackButton { appState.backFromSoloLapSelect() }
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
