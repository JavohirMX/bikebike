//
//  RaceHUDView.swift
//  racecar
//

import SwiftUI

struct RaceHUDView: View {
  @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            topBar
            leaderboardPanel
            Spacer()
            controls
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var topBar: some View {
        HStack {
            Button {
                appState.exitRace()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.45))
            .clipShape(Capsule())

            Spacer()

            let localLap = appState.carStates.first { $0.playerId == appState.raceSession.localPlayerId }?.currentLap ?? 0
            Text("Lap \(localLap)/\(appState.raceConfig.lapCount)")
                .font(.system(.title3, design: .rounded).bold())

            Spacer()

            Text(formatTime(appState.elapsedTime))
                .font(.system(.title3, design: .monospaced).bold())
        }
        .padding(12)
        .background(Color.black.opacity(0.55))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var leaderboardPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(appState.leaderboard.prefix(4)) { entry in
                HStack {
                    Text("\(entry.rank).")
                        .frame(width: 20, alignment: .leading)
                    if let hex = appState.players.first(where: { $0.peerId == entry.playerId })?.carColorHex {
                        PlayerColorDot(hex: hex, size: 8)
                    }
                    Text(entry.displayName)
                    Spacer()
                    Text("L\(entry.currentLap)")
                    if let lap = entry.lastLapTime {
                        Text(formatTime(lap))
                            .monospacedDigit()
                    }
                }
                .font(.caption.bold())
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.55))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: 220, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        HStack(alignment: .bottom) {
            GasBrakeControls(
                throttle: Bindable(appState).throttleInput,
                brake: Bindable(appState).brakeInput
            )
            Spacer()
            VirtualJoystick(
                steer: Bindable(appState).steerInput,
                throttle: Bindable(appState).throttleInput
            )
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let minutes = Int(t) / 60
        let seconds = t.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%04.1f", minutes, seconds)
    }
}

struct PlacementOverlay: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Cancel") {
                    appState.cancelPlacement()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                Spacer()
                statusPill
            }

            if appState.trackingQuality == .limited {
                trackingBanner("Keep the table in view — tracking is limited")
            } else if appState.trackingQuality == .unavailable {
                trackingBanner("Move your device slowly to restore tracking")
            }

            Spacer()

            VStack(spacing: 10) {
                Text(placementGuidance)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let error = appState.placementError {
                    Text(error)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if appState.planeDetectionStatus == .ready {
                    VStack(spacing: 8) {
                        Text("Scale: \(Int(appState.placementScale * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Slider(
                            value: Binding(
                                get: { Double(appState.placementScale) },
                                set: { appState.setPlacementScale(Float($0)) }
                            ),
                            in: 0.6...1.4,
                            step: 0.05
                        )
                        .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Button("Confirm Placement") {
                appState.confirmPlacement()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!appState.canConfirmPlacement)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var placementGuidance: String {
        switch appState.planeDetectionStatus {
        case .scanning:
            return "Move your phone slowly across a flat table to find a surface."
        case .surfaceFound:
            return "Flat surface detected. Hold steady while tracking improves."
        case .ready:
            return "Surface ready — drag to move, pinch to resize, twist to rotate, then Confirm."
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        let (text, color): (String, Color) = {
            switch appState.planeDetectionStatus {
            case .scanning:
                return ("Scanning…", .orange)
            case .surfaceFound:
                return ("Surface found", .yellow)
            case .ready:
                return ("Ready", .green)
            }
        }()
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.85))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private func trackingBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.yellow.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ResultsView: View {
  @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            Text("Race Complete")
                .font(.title.bold())
            VStack(spacing: 10) {
                ForEach(appState.leaderboard) { entry in
            HStack {
                Text("#\(entry.rank)")
                    .frame(width: 36, alignment: .leading)
                if let hex = appState.players.first(where: { $0.peerId == entry.playerId })?.carColorHex {
                    PlayerColorDot(hex: hex, size: 10)
                }
                Text(entry.displayName)
                        Spacer()
                        Text(formatTime(entry.totalTime))
                            .monospacedDigit()
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            Button("Home") { appState.goHome() }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func formatTime(_ t: TimeInterval) -> String {
        String(format: "%.1fs", t)
    }
}
