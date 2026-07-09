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

    private var duration: Duration {
        switch style {
        case .solo: .milliseconds(2200)
        case .multiplayer: .milliseconds(2700)
        }
    }

    var body: some View {
        ZStack {
            BikeBikeBackground()

            HomeBikeScene(mode: sceneMode)
                .padding(.horizontal, 24)
        }
        .allowsHitTesting(false)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: duration)
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
