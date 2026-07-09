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
            Spacer()
            controls
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var topBar: some View {
        HStack {
            BikeBikeHUDPill(
                title: "Back",
                systemImage: "chevron.left",
                showsStroke: false,
                action: { appState.exitRace() }
            )

            Spacer()

            let localLap = appState.carStates.first { $0.playerId == appState.raceSession.localPlayerId }?.currentLap ?? 0
            BikeBikeHUDPill(
                title: "Lap \(localLap)/\(appState.raceConfig.lapCount)",
                showsStroke: false,
                action: nil
            )

            Spacer()

            BikeBikeHUDPill(
                title: formatTime(appState.elapsedTime),
                showsStroke: false,
                monospacedDigits: true,
                action: nil
            )
        }
    }

    private var controls: some View {
        HStack(alignment: .bottom) {
            LeftDriveControls(
                gasPressed: Bindable(appState).gasPressed,
                boostCooldownProgress: appState.boostState.cooldownProgress,
                boostReady: appState.boostState.isReady,
                boostActive: appState.boostState.isActive,
                onBoostTap: { appState.requestBoost() }
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

            if appState.role == .solo {
                soloResultsPanel
            } else {
                multiplayerResultsPanel
            }
        }
    }

    private var soloResultsPanel: some View {
        VStack(spacing: 0) {
            // Top Header Banner
            MultiplayerBanner(title: "Food Delivered!")
                .frame(height: 75)
                .padding(.bottom, -12) // overlap the body
                .zIndex(1)

            // Body Container
            VStack(spacing: 8) {
                Text("Your fastest lap time")
                    .font(BikeBikeTheme.bodyFont(size: 18))
                    .foregroundStyle(BikeBikeTheme.darkBlue)
                    .padding(.top, 48)

                Text(formatSoloTime(appState.elapsedTime))
                    .font(BikeBikeTheme.titleFont(size: 64))
                    .foregroundStyle(BikeBikeTheme.darkBlue)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "seal.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(BikeBikeTheme.skyBlue)
                    .rotationEffect(.degrees(15))
                    .offset(x: 20, y: 20)
            }
            .background(Color(hex: "DDF2FE") ?? Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .padding(.bottom, 44) // Space for buttons
        }
        .bikeBikeScreenContent(maxWidth: 480)
        .shadow(color: BikeBikeTheme.panelShadow, radius: 12, y: 6)
        .overlay(alignment: .bottom) {
            HStack(spacing: 40) {
                BikeBikePillButton(title: "Exit", style: .blue) {
                    appState.goHome()
                }
                .frame(width: 120)

                BikeBikePillButton(title: "Play Again", style: .yellow) {
                    appState.playAgain()
                }
                .frame(width: 180)
            }
            .offset(y: 24)
        }
    }

    private var multiplayerResultsPanel: some View {
        VStack(spacing: 0) {
            // Top Header Banner
            MultiplayerBanner(title: "Food Delivered")
                .frame(height: 75) // Limit height so it doesn't span full width, making leaderboard look bigger
                .padding(.bottom, -12) // slight overlap
                .zIndex(1)

            // Table Header
            tableHeader
                .zIndex(0)

            // Body Section
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(appState.leaderboard) { entry in
                        tableRow(entry)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 48) // Extra space so last row isn't hidden by buttons
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 220)
            .background(Color(hex: "EADAC2") ?? Color.white)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 24, bottomTrailingRadius: 24, topTrailingRadius: 0))
        }
        .bikeBikeScreenContent(maxWidth: 520)
        .shadow(color: BikeBikeTheme.panelShadow, radius: 12, y: 6)
        .overlay(alignment: .bottom) {
            HStack(spacing: 40) {
                BikeBikePillButton(title: "Exit", style: .blue) {
                    appState.goHome()
                }
                .frame(width: 120)

                BikeBikePillButton(title: "Play Again", style: .yellow) {
                    appState.playAgain()
                }
                .frame(width: 180)
            }
            .offset(y: 24)
        }
    }

    private var tableHeader: some View {
        HStack {
            Text("#")
                .frame(width: 36, alignment: .center)
            Text("Player")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
            Text("Rating")
                .frame(width: 100, alignment: .center)
            Text("Time")
                .frame(width: 100, alignment: .center)
        }
        .font(BikeBikeTheme.titleFont(size: 20))
        .foregroundStyle(.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(BikeBikeTheme.skyBlue)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 20))
    }

    private func tableRow(_ entry: LeaderboardEntry) -> some View {
        let stars = StarRatingCalculator.stars(for: entry.totalTime, winnerTime: winnerTime)

        return HStack {
            RankBadge(rank: entry.rank)
                .frame(width: 36, alignment: .center)

            Text(entry.displayName)
                .font(BikeBikeTheme.bodyFont(size: 18))
                .foregroundStyle(Color(hex: "4A3D31") ?? .black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)

            StarRatingView(rating: stars)
                .frame(width: 100, alignment: .center)

            Text(formatTime(entry.totalTime))
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(Color(hex: "4A3D31") ?? .black)
                .frame(width: 100, alignment: .center)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.55))
        .clipShape(Capsule())
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func formatSoloTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02dm", minutes, seconds)
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

#Preview("Multiplayer Results") {
    ResultsView()
        .environment(PreviewData.appState {
            $0.phase = .results
            $0.role = .host // or guest
            $0.players = PreviewData.players
            $0.leaderboard = PreviewData.finishedLeaderboard
        })
}

#Preview("Solo Results") {
    ResultsView()
        .environment(PreviewData.appState {
            $0.phase = .results
            $0.role = .solo
            $0.elapsedTime = 733.0 // 12:13m
        })
}
