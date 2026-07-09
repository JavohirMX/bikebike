//
//  BikeBikeIconButton.swift
//  bikebike
//

import SwiftUI

enum BikeBikeCapsuleStyle {
    case yellow
    case blue

    var fillColor: Color {
        switch self {
        case .yellow: BikeBikeTheme.yellow
        case .blue: BikeBikeTheme.skyBlue
        }
    }

    var shadowColor: Color {
        switch self {
        case .yellow: Color(hex: "C9A800") ?? .orange
        case .blue: Color(hex: "3A8FD4") ?? .blue
        }
    }

    var strokeColor: Color {
        switch self {
        case .yellow: Color(hex: "00AEEF") ?? BikeBikeTheme.skyBlue
        case .blue: Color(hex: "21A8E0") ?? .blue
        }
    }
}

struct BikeBikeCapsuleSurface: View {
    var style: BikeBikeCapsuleStyle = .yellow
    var showsStroke: Bool = true
    var isPressed: Bool = false

    var body: some View {
        Capsule()
            .fill(style.fillColor)
            .shadow(
                color: style.shadowColor.opacity(isPressed ? 0.65 : 0.55),
                radius: 0,
                x: 0,
                y: isPressed ? 1 : 3
            )
            .overlay {
                if showsStroke {
                    Capsule()
                        .stroke(style.strokeColor, lineWidth: 2)
                }
            }
    }
}

struct BikeBikeHUDPill: View {
    let title: String
    var systemImage: String? = nil
    var style: BikeBikeCapsuleStyle = .yellow
    var showsStroke: Bool = true
    var monospacedDigits: Bool = false
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    label
                }
                .buttonStyle(.plain)
            } else {
                label
            }
        }
    }

    private var label: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .heavy))
            }
            Text(title)
                .font(monospacedDigits
                    ? .system(size: 14, weight: .semibold, design: .monospaced)
                    : BikeBikeTheme.captionFont(size: 14))
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 2)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(BikeBikeCapsuleSurface(style: style, showsStroke: showsStroke))
    }
}

struct BikeBikeIconButton: View {
    let systemImage: String
    var style: BikeBikeCapsuleStyle = .yellow
    var size: CGFloat = 56
    var iconSize: CGFloat = 24
    var isEnabled: Bool = true
    var isPressed: Bool = false
    var showsStroke: Bool = true
    var action: (() -> Void)?
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    var body: some View {
        Group {
            if onPress != nil || onRelease != nil {
                holdButton
            } else {
                tapButton
            }
        }
        .opacity(isEnabled ? 1 : 0.5)
        .scaleEffect(isPressed ? 0.95 : 1)
        .animation(.easeOut(duration: 0.12), value: isPressed)
    }

    private var buttonLabel: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: .heavy))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 2)
            .frame(width: size, height: size)
            .background(BikeBikeCapsuleSurface(style: style, showsStroke: showsStroke, isPressed: isPressed))
    }

    private var tapButton: some View {
        Button {
            guard isEnabled else { return }
            action?()
        } label: {
            buttonLabel
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var holdButton: some View {
        buttonLabel
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled else { return }
                        onPress?()
                    }
                    .onEnded { _ in
                        onRelease?()
                    }
            )
            .allowsHitTesting(isEnabled)
    }
}

#Preview("Icon Buttons") {
    HStack(spacing: 16) {
        BikeBikeIconButton(systemImage: "arrowtriangle.up.fill", showsStroke: false) {}
        BikeBikeIconButton(systemImage: "bolt.fill", style: .blue) {}
        BikeBikeIconButton(systemImage: "chevron.left", showsStroke: false) {}
    }
    .padding()
}

#Preview("HUD Pills") {
    HStack(spacing: 12) {
        BikeBikeHUDPill(title: "Back", systemImage: "chevron.left", showsStroke: false, action: {})
        BikeBikeHUDPill(title: "Lap 2/3", showsStroke: false, action: nil)
        BikeBikeHUDPill(title: "1:23.4", showsStroke: false, action: nil)
    }
    .padding()
}
