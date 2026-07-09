//
//  ARLeaderboardPanelView.swift
//  bikebike
//

import SwiftUI

struct ARLeaderboardPanelView: View {
    let entries: [LeaderboardEntry]
    let localPlayerId: String
    let lapCount: Int
    var useSimplifiedRendering: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if useSimplifiedRendering {
                simplifiedHeader
            } else {
                MultiplayerBanner(title: "Race Standings")
                    .frame(height: 44)
            }

            VStack(spacing: 4) {
                ForEach(entries) { entry in
                    row(entry)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(hex: "EADAC2") ?? Color(white: 0.92))
        }
        .frame(width: 320, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var simplifiedHeader: some View {
        ZStack {
            BikeBikeTheme.skyBlue
            Text("Race Standings")
                .font(BikeBikeTheme.titleFont(size: 20))
                .foregroundStyle(BikeBikeTheme.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 16)
        }
        .frame(height: 44)
    }

    private func row(_ entry: LeaderboardEntry) -> some View {
        let isLocal = entry.playerId == localPlayerId

        return HStack(spacing: 6) {
            RankBadge(rank: entry.rank)
                .frame(width: 28)

            Text(entry.displayName)
                .font(BikeBikeTheme.bodyFont(size: 14))
                .foregroundStyle(Color(hex: "4A3D31") ?? .black)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(lapText(entry))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "4A3D31") ?? .black)
                .frame(width: 44, alignment: .center)

            Text(timeText(entry))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(entry.status == .dnf ? .red : (Color(hex: "4A3D31") ?? .black))
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isLocal ? BikeBikeTheme.yellow.opacity(0.5) : Color.white.opacity(0.55))
        .clipShape(Capsule())
    }

    private func lapText(_ entry: LeaderboardEntry) -> String {
        let lap = min(entry.currentLap + 1, lapCount)
        return "L\(lap)/\(lapCount)"
    }

    private func timeText(_ entry: LeaderboardEntry) -> String {
        switch entry.status {
        case .dnf:
            return "DNF"
        case .finished:
            return formatRaceTime(entry.totalTime)
        default:
            return entry.totalTime > 0 ? formatRaceTime(entry.totalTime) : "--"
        }
    }

    private func formatRaceTime(_ time: TimeInterval) -> String {
        let total = Int(time)
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview("AR Leaderboard Panel") {
    ARLeaderboardPanelView(
        entries: PreviewData.leaderboard,
        localPlayerId: "host-1",
        lapCount: 3
    )
    .padding()
}
