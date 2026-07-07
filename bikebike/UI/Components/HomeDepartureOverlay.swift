//
//  HomeDepartureOverlay.swift
//  bikebike
//

import SwiftUI

struct HomeDepartureOverlay: View {
    @Environment(AppState.self) private var appState
    let style: HomeDepartureStyle

    private var sceneMode: HomeBikeSceneMode {
        switch style {
        case .solo: .soloMoving
        case .multiplayer: .multiplayerMoving
        }
    }

    var body: some View {
        ZStack {
            BikeBikeBackground(blurRadius: 2)
                .opacity(0.85)

            HomeBikeScene(mode: sceneMode)
                .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1200))
                appState.clearHomeDeparture()
            }
        }
    }
}
