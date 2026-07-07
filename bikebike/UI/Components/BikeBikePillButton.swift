//
//  BikeBikePillButton.swift
//  bikebike
//

import SwiftUI

enum BikeBikePillStyle {
    case yellow
    case blue
}

struct BikeBikePillButton: View {
    let title: String
    var systemImage: String? = nil
    var style: BikeBikePillStyle = .yellow
    var isEnabled: Bool = true
    let action: () -> Void

    private var fillColor: Color {
        switch style {
        case .yellow: BikeBikeTheme.yellow
        case .blue: BikeBikeTheme.skyBlue
        }
    }

    private var shadowColor: Color {
        switch style {
        case .yellow: Color(hex: "C9A800") ?? .orange
        case .blue: Color(hex: "3A8FD4") ?? .blue
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .bold))
                }
                Text(title)
                    .font(BikeBikeTheme.buttonFont())
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(
                Capsule()
                    .fill(fillColor)
                    .shadow(color: shadowColor.opacity(0.6), radius: 0, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}
