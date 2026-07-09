//
//  ReceiptPanel.swift
//  bikebike
//

import SwiftUI

struct ReceiptPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            Image("receipt-panel")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()

            ScrollView(showsIndicators: false) {
                content()
                    .padding(.horizontal, 48)
                    .padding(.bottom, 24)
            }
            .padding(.top, 64)
        }
        .frame(maxHeight: .infinity)
        .shadow(color: BikeBikeTheme.panelShadow, radius: 8, y: 4)
    }
}

struct ReceiptDashedDivider: View {
    var body: some View {
        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .foregroundStyle(BikeBikeTheme.darkBlue.opacity(0.3))
            .frame(height: 1)
            .padding(.vertical, 8)
    }
}

struct PlayerAvatarGrid: View {
    let players: [PlayerProfile]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(players) { player in
                HStack(spacing: 8) {
                    Image(DriverCatalog.resolvedImageName(forDriverId: player.driverId))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.displayName)
                            .font(BikeBikeTheme.captionFont(size: 13))
                            .foregroundStyle(BikeBikeTheme.darkBlue)
                            .lineLimit(1)
                        Text(DriverCatalog.driver(for: player.driverId).displayName)
                            .font(BikeBikeTheme.captionFont(size: 11))
                            .foregroundStyle(BikeBikeTheme.darkBlue.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

#Preview("Receipt Panel") {
    ReceiptPanel {
        VStack(spacing: 8) {
            Text("Race Receipt")
                .font(.headline)
            ReceiptDashedDivider()
            PlayerAvatarGrid(players: PreviewData.players)
        }
    }
    .frame(width: 320)
    .padding()
}
