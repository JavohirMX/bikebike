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
            BikeBikeBackground()
                .opacity(0.85)

            HomeBikeScene(mode: sceneMode)
                .padding(.horizontal, 24)
        }
        .allowsHitTesting(false)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1200))
                appState.clearHomeDeparture()
            }
        }
    }
}

#Preview("Solo Departure") {
    HomeDepartureOverlay(style: .solo)
        .environment(PreviewData.appState())
}

#Preview("Multiplayer Departure") {
    HomeDepartureOverlay(style: .multiplayer)
        .environment(PreviewData.appState())
}
