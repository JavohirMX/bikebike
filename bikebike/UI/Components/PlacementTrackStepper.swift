//
//  PlacementTrackStepper.swift
//  bikebike
//

import SwiftUI

struct PlacementTrackStepper: View {
    @Environment(AppState.self) private var appState

    private var options: [TrackOption] {
        RaceTrackCatalog.allOptions
    }

    private var selectedIndex: Int {
        options.firstIndex(where: { $0.id == appState.raceConfig.trackId }) ?? 0
    }

    private var selectedOption: TrackOption {
        options[selectedIndex]
    }

    var body: some View {
        HStack(spacing: 16) {
            stepperButton(systemName: "chevron.left") {
                selectPrevious()
            }
            .disabled(options.count <= 1)

            Text(selectedOption.shortTitle)
                .font(BikeBikeTheme.titleFont(size: 20))
                .foregroundStyle(BikeBikeTheme.darkBlue)
                .frame(minWidth: 100)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            stepperButton(systemName: "chevron.right") {
                selectNext()
            }
            .disabled(options.count <= 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(BikeBikeTheme.cream.opacity(0.92))
        .clipShape(Capsule())
        .shadow(color: BikeBikeTheme.panelShadow, radius: 8, y: 4)
    }

    private func selectPrevious() {
        let index = (selectedIndex - 1 + options.count) % options.count
        appState.selectTrack(options[index].id)
    }

    private func selectNext() {
        let index = (selectedIndex + 1) % options.count
        appState.selectTrack(options[index].id)
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(BikeBikeTheme.darkBlue)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.85))
                .clipShape(Circle())
                .shadow(color: BikeBikeTheme.panelShadow, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
