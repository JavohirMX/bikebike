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
            header()
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .background(BikeBikeTheme.skyBlue)
                .overlay(alignment: .bottom) {
                    BikeBikeWaveShape()
                        .fill(BikeBikeTheme.cream)
                        .frame(height: 16)
                }

            content()
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
                .background(BikeBikeTheme.cream)
        }
        .clipShape(RoundedRectangle(cornerRadius: BikeBikeTheme.modalRadius))
        .shadow(color: BikeBikeTheme.panelShadow, radius: 12, y: 6)
    }
}

private struct BikeBikeWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        path.move(to: CGPoint(x: 0, y: midY))
        let step = rect.width / 6
        for i in 0..<6 {
            let x0 = CGFloat(i) * step
            let x1 = x0 + step / 2
            let x2 = x0 + step
            path.addQuadCurve(
                to: CGPoint(x: x1, y: rect.maxY),
                control: CGPoint(x: x0 + step / 4, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: x2, y: midY),
                control: CGPoint(x: x1 + step / 4, y: rect.maxY)
            )
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}

#Preview("Modal Card") {
    BikeBikeModalCard {
        Text("Header")
            .font(.title2.bold())
            .foregroundStyle(.white)
    } content: {
        VStack(spacing: 12) {
            Text("Card body content goes here.")
            BikeBikePillButton(title: "Continue", style: .blue) {}
        }
    }
    .frame(width: 340)
    .padding()
}
