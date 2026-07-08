//
//  BikeBikeModalCard.swift
//  bikebike
//

import SwiftUI

struct BikeBikeModalCard<Header: View, Content: View>: View {
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
                .padding(.horizontal, 24)
                .padding(.top, 36) // extra padding for floating header
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
                .background(BikeBikeTheme.cream)
                .clipShape(RoundedRectangle(cornerRadius: BikeBikeTheme.modalRadius))
                .shadow(color: BikeBikeTheme.panelShadow, radius: 12, y: 6)
        }
        .overlay(alignment: .top) {
            header()
                .offset(y: -24)
        }
        .padding(.top, 24) // offset for the header to not clip
    }
}

#Preview("Modal Card") {
    BikeBikeModalCard {
        HeadingBanner(title: "Preview")
    } content: {
        VStack(spacing: 12) {
            Text("Card body content goes here.")
            BikeBikePillButton(title: "Continue", style: .blue) {}
        }
    }
    .frame(width: 340)
    .padding()
}
