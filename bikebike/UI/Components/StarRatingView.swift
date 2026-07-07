//
//  StarRatingView.swift
//  bikebike
//

import SwiftUI

struct StarRatingView: View {
    let rating: Int
    var maxRating: Int = 5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundStyle(index <= rating ? BikeBikeTheme.yellow : Color.gray.opacity(0.35))
            }
        }
    }
}

struct RankBadge: View {
    let rank: Int

    private var color: Color {
        switch rank {
        case 1: BikeBikeTheme.gold
        case 2: BikeBikeTheme.silver
        case 3: BikeBikeTheme.bronze
        default: BikeBikeTheme.darkBlue.opacity(0.2)
        }
    }

    var body: some View {
        Text("\(rank)")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(rank <= 3 ? .white : BikeBikeTheme.darkBlue)
            .frame(width: 28, height: 28)
            .background(Circle().fill(color))
    }
}
