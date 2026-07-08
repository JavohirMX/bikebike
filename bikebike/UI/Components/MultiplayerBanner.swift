//
//  MultiplayerBanner.swift
//  bikebike
//

import SwiftUI

struct MultiplayerBanner: View {
    var title: String = "Multiplayer"

    private let aspectRatio: CGFloat = 404.0 / 92.0

    var body: some View {
        Image("StarBanner")
            .resizable()
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(
                GeometryReader { proxy in
                    Text(title)
                        .font(BikeBikeTheme.titleFont(size: proxy.size.height * 0.55))
                        .foregroundStyle(BikeBikeTheme.yellow)
                        .shadow(color: BikeBikeTheme.darkBlue, radius: 0, x: 1, y: 2)
                        .shadow(color: BikeBikeTheme.darkBlue.opacity(0.5), radius: 0, x: 2, y: 3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        // Keep the text clear of the stars on each side.
                        .padding(.horizontal, proxy.size.width * 0.24)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            )
    }
}

#Preview("Multiplayer Banner") {
    VStack(spacing: 16) {
        MultiplayerBanner()
        MultiplayerBanner(title: "Host Setup")
    }
    .padding()
}
