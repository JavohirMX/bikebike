//
//  RaceHUDView.swift
//  bikebike
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
                gasPressed: Bindable(appState).gasPressed,
                brake: Bindable(appState).brakeInput
            )
            Spacer()
            VirtualJoystick(
                steer: Bindable(appState).steerInput
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

    private var winnerTime: TimeInterval {
        appState.leaderboard.first?.totalTime ?? 0
    }

    var body: some View {
        ZStack {
            BikeBikeBackground(blurRadius: 6)

            VStack(spacing: 20) {
                Spacer()

                BikeBikeModalCard {
                    HeadingBanner(title: "Leaderboard")
                } content: {
                    VStack(spacing: 0) {
                        tableHeader

                        ForEach(appState.leaderboard) { entry in
                            tableRow(entry)
                        }
                    }
                }
                .bikeBikeScreenContent(maxWidth: 520)

                ViewThatFits {
                    HStack(spacing: 16) {
                        BikeBikePillButton(title: "Exit", style: .blue) {
                            appState.goHome()
                        }
                        .frame(width: 200)

                        BikeBikePillButton(title: "Play Again", style: .yellow) {
                            appState.playAgain()
                        }
                        .frame(width: 200)
                    }

                    VStack(spacing: 12) {
                        BikeBikePillButton(title: "Exit", style: .blue) {
                            appState.goHome()
                        }

                        BikeBikePillButton(title: "Play Again", style: .yellow) {
                            appState.playAgain()
                        }
                    }
                }
                .bikeBikeScreenContent(maxWidth: 520)

                Spacer()
            }
        }
    }

    private var tableHeader: some View {
        HStack {
            Text("#")
                .frame(width: 36, alignment: .center)
            Text("Player")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Rating")
                .frame(width: 90, alignment: .center)
            Text("Time")
                .frame(width: 80, alignment: .trailing)
        }
        .font(BikeBikeTheme.captionFont(size: 13))
        .foregroundStyle(.white)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(BikeBikeTheme.skyBlue)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 8)
    }

    private func tableRow(_ entry: LeaderboardEntry) -> some View {
        let stars = StarRatingCalculator.stars(for: entry.totalTime, winnerTime: winnerTime)

        return HStack {
            RankBadge(rank: entry.rank)
                .frame(width: 36, alignment: .center)

            Text(entry.displayName)
                .font(BikeBikeTheme.captionFont(size: 15))
                .foregroundStyle(BikeBikeTheme.darkBlue)
                .frame(maxWidth: .infinity, alignment: .leading)

            StarRatingView(rating: stars)
                .frame(width: 90, alignment: .center)

            Text(formatTime(entry.totalTime))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(BikeBikeTheme.darkBlue)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview("Race HUD") {
    ZStack {
        Color.gray
        RaceHUDView()
    }
    .environment(PreviewData.appState {
        $0.phase = .racing
        $0.players = PreviewData.players
        $0.carStates = PreviewData.carStates
        $0.leaderboard = PreviewData.leaderboard
        $0.raceConfig.lapCount = 3
        $0.elapsedTime = 42.3
    })
}

#Preview("Placement Overlay") {
    ZStack {
        Color.gray
        PlacementOverlay()
    }
    .environment(PreviewData.appState {
        $0.phase = .placement
        $0.planeDetectionStatus = .ready
        $0.placementScale = 1.0
    })
}

#Preview("Results") {
    ResultsView()
        .environment(PreviewData.appState {
            $0.phase = .results
            $0.players = PreviewData.players
            $0.leaderboard = PreviewData.finishedLeaderboard
        })
}
