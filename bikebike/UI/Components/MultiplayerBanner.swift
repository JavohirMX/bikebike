//
//  MultiplayerBanner.swift
//  bikebike
//

import SwiftUI

struct MultiplayerBanner: View {
    var title: String = "Multiplayer"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 18))
                .foregroundStyle(BikeBikeTheme.yellow)
            Text(title)
                .font(BikeBikeTheme.titleFont(size: 26))
                .foregroundStyle(BikeBikeTheme.yellow)
                .shadow(color: BikeBikeTheme.darkBlue, radius: 0, x: 1, y: 2)
                .shadow(color: BikeBikeTheme.darkBlue.opacity(0.5), radius: 0, x: 2, y: 3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Image(systemName: "star.fill")
                .font(.system(size: 18))
                .foregroundStyle(BikeBikeTheme.yellow)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(BikeBikeTheme.skyBlue)
                .shadow(color: Color(hex: "3A8FD4") ?? .blue, radius: 0, x: 0, y: 4)
        )
    }
}
