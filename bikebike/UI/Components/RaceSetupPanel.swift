//
//  RaceSetupPanel.swift
//  bikebike
//

import SwiftUI

struct RaceSetupPanel: View {
    @Environment(AppState.self) private var appState

    let continueTitle: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Select Track")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(BikeBikeTheme.skyBlue)
                .padding(.top, 16)

            TrackSelectGrid(
                selectedTrackId: appState.raceConfig.trackId,
                compact: true
            ) { trackId in
                appState.selectTrack(trackId)
            }

            Text("Lap Count")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(BikeBikeTheme.skyBlue)

            LapCountStepper(
                value: Binding(
                    get: { appState.raceConfig.lapCount },
                    set: { appState.setLapCount($0) }
                )
            )

            BikeBikePillButton(title: continueTitle, style: .yellow, action: onContinue)
                .padding(.bottom, 8)
        }
    }
}
