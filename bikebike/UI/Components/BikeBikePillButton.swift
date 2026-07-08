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

    private var strokeColor: Color {
        switch style {
        case .yellow: Color(hex: "00AEEF") ?? BikeBikeTheme.skyBlue
        case .blue: Color(hex: "21A8E0") ?? .blue
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .bold))
                }
                Text(title)
                    .font(BikeBikeTheme.buttonFont(size: 29))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 20)
            .background(
                Capsule()
                    .fill(fillColor)
                    .shadow(color: shadowColor.opacity(0.45), radius: 6, x: 0, y: 3)
                    .overlay(
                        Capsule()
                            .stroke(strokeColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

#Preview("Pill Buttons") {
    VStack(spacing: 16) {
        BikeBikePillButton(title: "Soloplayer", systemImage: "person.fill", style: .yellow) {}
        BikeBikePillButton(title: "Multiplayer", systemImage: "person.3.fill", style: .blue) {}
        BikeBikePillButton(title: "Disabled", systemImage: "lock.fill", style: .yellow, isEnabled: false) {}
    }
    .frame(width: 280)
    .padding()
}
