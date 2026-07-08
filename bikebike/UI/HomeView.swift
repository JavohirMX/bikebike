//
//  HomeView.swift
//  bikebike
//

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState

    private var buttonsDisabled: Bool {
        appState.homeDeparture != nil
    }

    var body: some View {
        ZStack {
            BikeBikeBackground()

            HomeBikeScene(mode: .parked)
                .padding(.horizontal, 24)

            VStack {
                Spacer()

                VStack(spacing: 20) {
                    BikeBikeLogo(height: 100)
                    VStack(spacing: 14) {
                        BikeBikePillButton(
                            title: "Soloplayer",
                            systemImage: "person.fill",
                            style: .yellow,
                            isEnabled: !buttonsDisabled
                        ) {
                            appState.triggerHomeDeparture(.solo)
                            appState.startSoloPractice()
                        }

                        BikeBikePillButton(
                            title: "Multiplayer",
                            systemImage: "person.3.fill",
                            style: .blue,
                            isEnabled: !buttonsDisabled
                        ) {
                            appState.triggerHomeDeparture(.multiplayer)
                            appState.beginPlayTogether()
                        }
                    }
                    .frame(width: 280)
                }
                .bikeBikeScreenContent(maxWidth: 400)
                .offset(x: 160)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Home", traits: .landscapeLeft) {
    HomeView()
        .environment(PreviewData.appState())
}
