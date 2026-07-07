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
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(BikeBikeTheme.darkBlue)
                .frame(width: 44, height: 44)
                .background(BikeBikeTheme.cream)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: BikeBikeTheme.panelShadow, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
