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
            if !appState.isLocalPlayerFinished {
                controls
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if appState.isLocalPlayerFinished {
                    Text("Spectating...")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.85))
                        .clipShape(Capsule())
                        .shadow(radius: 4)
                }
                
                if let time = appState.dnfTimeRemaining {
                    Text("Race ends in \(time)s!")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.85))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 72)
        }
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
            let displayLap = min(localLap + 1, appState.raceConfig.lapCount)
            BikeBikeHUDPill(
                title: "Lap \(displayLap)/\(appState.raceConfig.lapCount)",
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

            VStack(spacing: 8) {
                Text("Placing: \(RaceTrackCatalog.option(for: appState.raceConfig.trackId).shortTitle)")
                    .font(BikeBikeTheme.bodyFont(size: 18))
                    .foregroundStyle(BikeBikeTheme.darkBlue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(BikeBikeTheme.cream.opacity(0.92))
                    .clipShape(Capsule())
                    .shadow(color: BikeBikeTheme.panelShadow, radius: 8, y: 4)

                BikeBikePillButton(
                    title: "Confirm Placement",
                    style: .yellow,
                    isEnabled: appState.canConfirmPlacement
                ) {
                    appState.confirmPlacement()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .safeAreaPadding(.bottom, 4)
    }

    private var topBar: some View {
        ZStack {
            MultiplayerBanner(title: "Place Track")
                .frame(height: 64)
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
        let localCar = appState.carStates.first { $0.playerId == appState.raceSession.localPlayerId }
            ?? appState.carStates.first
        let totalTime = localCar?.finishTime ?? localCar?.totalTime ?? appState.leaderboard.first?.totalTime ?? 0
        let lapTimes = localCar?.lapTimes ?? []
        let fastestIndex = lapTimes.enumerated().min(by: { $0.element < $1.element })?.offset
        let driver = DriverCatalog.driver(for: appState.localSelectedDriverId)

        return VStack(spacing: 0) {
            MultiplayerBanner(title: "Food Delivered!")
                .frame(maxWidth: 440)
                .frame(height: 68)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            HStack(alignment: .center, spacing: 28) {
                // Left: driver
                VStack(spacing: 14) {
                    Image(DriverCatalog.resolvedImageName(for: driver))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                    Text(driver.displayName)
                        .font(BikeBikeTheme.titleFont(size: 32))
                        .foregroundStyle(BikeBikeTheme.darkBlue)
                        .shadow(color: .white.opacity(0.7), radius: 2, y: 1)
                }
                .frame(maxWidth: .infinity)

                // Right: times
                VStack(spacing: 10) {
                    VStack(spacing: 2) {
                        Text("Total Time")
                            .font(BikeBikeTheme.bodyFont(size: 15))
                            .foregroundStyle(BikeBikeTheme.darkBlue.opacity(0.75))
                        Text(formatRaceResultTime(totalTime))
                            .font(BikeBikeTheme.titleFont(size: 48))
                            .foregroundStyle(BikeBikeTheme.darkBlue)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }

                    VStack(spacing: 2) {
                        if appState.soloIsNewPersonalBest {
                            Text("New Personal Best")
                                .font(BikeBikeTheme.titleFont(size: 16))
                                .foregroundStyle(BikeBikeTheme.darkBlue)
                        }
                        if let previous = appState.soloPreviousPersonalBestTime {
                            Text("Best: \(formatRaceResultTime(previous))")
                                .font(BikeBikeTheme.bodyFont(size: 14))
                                .foregroundStyle(BikeBikeTheme.darkBlue.opacity(0.7))
                        } else if !appState.soloIsNewPersonalBest, let best = appState.soloPersonalBestTime {
                            Text("Best: \(formatRaceResultTime(best))")
                                .font(BikeBikeTheme.bodyFont(size: 14))
                                .foregroundStyle(BikeBikeTheme.darkBlue.opacity(0.7))
                        }
                    }

                    if !lapTimes.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(Array(lapTimes.enumerated()), id: \.offset) { index, lapTime in
                                let isFastest = index == fastestIndex
                                HStack {
                                    Text("Lap \(index + 1)")
                                        .font(BikeBikeTheme.bodyFont(size: 16))
                                    Spacer(minLength: 8)
                                    Text(formatRaceResultTime(lapTime))
                                        .font(BikeBikeTheme.bodyFont(size: 16))
                                        .monospacedDigit()
                                    if isFastest {
                                        Text("fastest")
                                            .font(BikeBikeTheme.captionFont(size: 12))
                                            .foregroundStyle(BikeBikeTheme.darkBlue)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(BikeBikeTheme.yellow)
                                            .clipShape(Capsule())
                                    }
                                }
                                .foregroundStyle(BikeBikeTheme.darkBlue)
                                .fontWeight(isFastest ? .bold : .semibold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isFastest ? Color.white.opacity(0.65) : Color.white.opacity(0.35))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "DDF2FE") ?? Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .shadow(color: BikeBikeTheme.panelShadow, radius: 12, y: 6)
            }
            .padding(.horizontal, 40)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 32) {
                BikeBikePillButton(title: "Exit", style: .blue) {
                    appState.goHome()
                }
                .frame(width: 140)

                BikeBikePillButton(title: "Play Again", style: .yellow) {
                    appState.playAgain()
                }
                .frame(width: 200)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            Text(entry.status == .dnf ? "DNF" : formatTime(entry.totalTime))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(entry.status == .dnf ? Color.red : (Color(hex: "4A3D31") ?? .black))
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

    private func formatRaceResultTime(_ t: TimeInterval) -> String {
        let minutes = Int(t) / 60
        let seconds = t.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%04.1f", minutes, seconds)
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
            $0.players = [PreviewData.host]
            $0.carStates = [PreviewData.finishedSoloCarState]
            $0.leaderboard = LeaderboardSorter.sort(players: [PreviewData.host], cars: [PreviewData.finishedSoloCarState])
            $0.raceConfig.lapCount = 3
            $0.soloIsNewPersonalBest = true
            $0.soloPersonalBestTime = 83.4
            $0.soloPreviousPersonalBestTime = 85.1
        })
}
