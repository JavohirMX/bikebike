//
//  LapCountStepper.swift
//  bikebike
//

import SwiftUI

struct LapCountStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...10

    var body: some View {
        HStack(spacing: 16) {
            stepperButton(systemName: "minus") {
                if value > range.lowerBound { value -= 1 }
            }

            Text("\(value)")
                .font(BikeBikeTheme.titleFont(size: 32))
                .foregroundStyle(BikeBikeTheme.darkBlue)
                .frame(width: 64, height: 64)
                .background(BikeBikeTheme.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: BikeBikeTheme.panelShadow, radius: 4, y: 2)

            stepperButton(systemName: "plus") {
                if value < range.upperBound { value += 1 }
            }
        }
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(BikeBikeTheme.darkBlue)
                .frame(width: 56, height: 56)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: BikeBikeTheme.panelShadow, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
