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
                    RaceSetupPanel(continueTitle: "Continue") {
                        appState.confirmMultiplayerLapSelect()
                    }
                }
                .frame(width: 420)
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
