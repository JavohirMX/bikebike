//
//  HomeView.swift
//  bikebike
//

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showsSettings = false

    private var buttonsDisabled: Bool {
        appState.homeDeparture != nil
    }

    var body: some View {
        ZStack {
            BikeBikeBackground()

            HomeBikeScene(mode: .parked)
                .padding(.horizontal, 24)

            VStack {
                HStack {
                    Spacer()
                    BikeBikeIconButton(
                        systemImage: "gearshape.fill",
                        style: .blue,
                        size: 48,
                        iconSize: 22,
                        isEnabled: !buttonsDisabled,
                        action: {
                            showsSettings = true
                        }
                    )
                }
                .padding(.trailing, 24)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 20) {
                    BikeBikeLogo(height: 100)
                    VStack(spacing: 14) {
                        BikeBikePillButton(
                            title: "Singleplayer",
                            systemImage: "person.fill",
                            style: .yellow,
                            isEnabled: !buttonsDisabled,
                            glowStartDelay: 0.3
                        ) {
                            appState.triggerHomeDeparture(.solo)
                            appState.startSoloPractice()
                        }

                        BikeBikePillButton(
                            title: "Multiplayer",
                            systemImage: "person.3.fill",
                            style: .blue,
                            isEnabled: !buttonsDisabled,
                            glowStartDelay: 0.85
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
        .sheet(isPresented: $showsSettings) {
            SettingsView()
                .environment(appState)
        }
    }
}

#Preview("Home", traits: .landscapeLeft) {
    HomeView()
        .environment(PreviewData.appState())
}
