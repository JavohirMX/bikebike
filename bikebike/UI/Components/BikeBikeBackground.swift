//
//  BikeBikeBackground.swift
//  bikebike
//

import SwiftUI

struct BikeBikeBackground: View {
    var blurRadius: CGFloat = 0

    var body: some View {
        Image("bg-tropical")
            .resizable()
            .scaledToFill()
            .blur(radius: blurRadius)
            .ignoresSafeArea()
    }
}

struct BikeBikeLogo: View {
    var height: CGFloat = 80

    var body: some View {
        Image("logo-bikebike")
            .resizable()
            .scaledToFit()
            .frame(height: height)
    }
}

struct BikeBikeBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    Capsule()
                        .fill(BikeBikeTheme.yellow)
                        .shadow(color: (Color(hex: "C9A800") ?? .orange).opacity(0.55), radius: 0, x: 0, y: 3)
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: "00AEEF") ?? BikeBikeTheme.skyBlue, lineWidth: 2)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Background") {
    ZStack {
        BikeBikeBackground(blurRadius: 2)
        VStack(spacing: 20) {
            BikeBikeLogo(height: 72)
            BikeBikeBackButton {}
        }
    }
}
