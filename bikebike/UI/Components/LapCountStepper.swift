//
//  LapCountStepper.swift
//  bikebike
//

import SwiftUI

struct LapCountStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...10
    
    // A little dark bluish tint as requested
    private let textTint = Color(hex: "2B5A8F") ?? .blue

    var body: some View {
        HStack(spacing: 8) {
            stepperButton(systemName: "minus") {
                if value > range.lowerBound { value -= 1 }
            }

            Text("\(value)")
                .font(BikeBikeTheme.titleFont(size: 28))
                .foregroundStyle(textTint)
                .frame(width: 60, height: 60)
                .background(BikeBikeTheme.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(BikeBikeTheme.skyBlue, lineWidth: 1.5)
                )

            stepperButton(systemName: "plus") {
                if value < range.upperBound { value += 1 }
            }
        }
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(textTint)
                .frame(width: 60, height: 60)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(BikeBikeTheme.skyBlue, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Lap Count Stepper") {
    @Previewable @State var laps = 3
    LapCountStepper(value: $laps)
        .padding()
}
