//
//  HeadingBanner.swift
//  bikebike
//

import SwiftUI

struct HeadingBanner: View {
    var title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 32))
                .foregroundStyle(BikeBikeTheme.yellow)
                .rotationEffect(.degrees(-10))
                .shadow(color: Color.black.opacity(0.1), radius: 2, y: 2)
            
            Text(title)
                .font(BikeBikeTheme.titleFont(size: 30))
                .foregroundStyle(BikeBikeTheme.yellow)
                .shadow(color: BikeBikeTheme.skyBlue, radius: 1)
                .shadow(color: Color(hex: "3A8FD4") ?? .blue, radius: 0, x: 0, y: 2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Image(systemName: "star.fill")
                .font(.system(size: 32))
                .foregroundStyle(BikeBikeTheme.yellow)
                .rotationEffect(.degrees(10))
                .shadow(color: Color.black.opacity(0.1), radius: 2, y: 2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(BikeBikeTheme.skyBlue)
                .shadow(color: Color(hex: "3A8FD4") ?? .blue, radius: 0, x: 0, y: 4)
        )
    }
}

#Preview("Heading Banner") {
    VStack(spacing: 32) {
        HeadingBanner(title: "Singleplayer")
        HeadingBanner(title: "Multiplayer")
        HeadingBanner(title: "Leaderboard")
    }
    .padding()
}
