//
//  TrackOptionPicker.swift
//  bikebike
//

import SwiftUI

struct TrackOptionPicker: View {
    @Environment(AppState.self) private var appState

    private var selectedOption: TrackOption {
        RaceTrackCatalog.option(for: appState.raceConfig.trackId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Track")
                .font(BikeBikeTheme.bodyFont(size: 18))
                .foregroundStyle(BikeBikeTheme.darkBlue)

            ViewThatFits {
                segmentedTrackPicker
                menuTrackPicker
            }
            .frame(maxWidth: .infinity)

            Text(selectedOption.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var segmentedTrackPicker: some View {
        trackPicker
            .pickerStyle(.segmented)
    }

    private var menuTrackPicker: some View {
        trackPicker
            .pickerStyle(.menu)
    }

    private var trackPicker: some View {
        Picker(
            "Track",
            selection: Binding(
                get: { appState.raceConfig.trackId },
                set: { appState.selectTrack($0) }
            )
        ) {
            ForEach(RaceTrackCatalog.allOptions) { option in
                Text(option.shortTitle).tag(option.id)
            }
        }
    }
}
