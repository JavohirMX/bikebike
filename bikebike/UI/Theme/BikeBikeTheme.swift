//
//  BikeBikeTheme.swift
//  bikebike
//

import SwiftUI

enum BikeBikeTheme {
    static let yellow = Color(hex: "F2D516") ?? .yellow
    static let skyBlue = Color(hex: "5DBBFF") ?? .blue
    static let darkBlue = Color(hex: "1A3A6B") ?? .blue
    static let cream = Color(hex: "F5F0DC") ?? Color(red: 0.96, green: 0.94, blue: 0.86)
    static let gold = Color(hex: "FFD700") ?? .yellow
    static let silver = Color(hex: "C0C0C0") ?? .gray
    static let bronze = Color(hex: "CD7F32") ?? .orange

    static let pillRadius: CGFloat = 28
    static let modalRadius: CGFloat = 24
    static let panelShadow = Color.black.opacity(0.18)

    static func titleFont(size: CGFloat = 28) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func buttonFont(size: CGFloat = 20) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func bodyFont(size: CGFloat = 17) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func captionFont(size: CGFloat = 14) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

enum StarRatingCalculator {
    static func stars(for time: TimeInterval, winnerTime: TimeInterval) -> Int {
        guard winnerTime > 0, time > 0 else { return 1 }
        let ratio = time / winnerTime
        switch ratio {
        case ...1.02: return 5
        case ...1.05: return 4
        case ...1.10: return 3
        case ...1.20: return 2
        default: return 1
        }
    }
}
