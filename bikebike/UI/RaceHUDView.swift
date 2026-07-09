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
            SteerArrowButtons(
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
        VStack(spacing: 0) {
            topBar

            if appState.trackingQuality == .limited {
                trackingBanner("Keep the table in view — tracking is limited")
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            } else if appState.trackingQuality == .unavailable {
                trackingBanner("Move your device slowly to restore tracking")
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }

            Spacer()

            VStack(spacing: 12) {
                PlacementTrackStepper()

                BikeBikePillButton(
                    title: "Confirm Placement",
                    style: .yellow,
                    isEnabled: appState.canConfirmPlacement
                ) {
                    appState.confirmPlacement()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .safeAreaPadding(.bottom, 8)
    }

    private var topBar: some View {
        ZStack {
            MultiplayerBanner(title: "Place Track")
                .padding(.horizontal, 48)

            HStack {
                BikeBikeBackButton {
                    appState.cancelPlacement()
                }
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private func trackingBanner(_ message: String) -> some View {
        Text(message)
            .font(BikeBikeTheme.captionFont(size: 13))
            .foregroundStyle(BikeBikeTheme.darkBlue)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(BikeBikeTheme.yellow.opacity(0.92))
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
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(BikeBikeTheme.yellow)
                        Text("Food Delivered")
                            .font(BikeBikeTheme.titleFont(size: 26))
                            .foregroundStyle(BikeBikeTheme.yellow)
                            .shadow(color: BikeBikeTheme.darkBlue, radius: 0, x: 1, y: 2)
                        Image(systemName: "star.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(BikeBikeTheme.yellow)
                    }
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
