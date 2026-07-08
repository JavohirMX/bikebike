//
//  VirtualJoystick.swift
//  bikebike
//

import SwiftUI

struct VirtualJoystick: View {
    @Binding var steer: Float

    private let size: CGFloat = 120
    private let knobSize: CGFloat = 48
    private let deadZone: Float = 0.08

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.45))
                .frame(width: size, height: size)
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: size - 6, height: size - 6)
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: knobSize, height: knobSize)
                .offset(dragOffset)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let maxRadius = (size - knobSize) / 2
                    let dx = value.translation.width
                    let clampedX = max(-maxRadius, min(maxRadius, dx))
                    dragOffset = CGSize(width: clampedX, height: 0)
                    var nx = Float(clampedX / maxRadius)
                    if abs(nx) < deadZone { nx = 0 }
                    steer = max(-1, min(1, nx))
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                    steer = 0
                }
        )
    }
}

struct GasBrakeControls: View {
    @Binding var gasPressed: Bool
    @Binding var brake: Float

    var body: some View {
        VStack(spacing: 16) {
            controlButton(label: "GAS", active: gasPressed) {
                gasPressed = true
            } onRelease: {
                gasPressed = false
            }
            controlButton(label: "BRK", active: brake > 0) {
                brake = 1
            } onRelease: {
                brake = 0
            }
        }
    }

    private func controlButton(label: String, active: Bool, onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        Text(label)
            .font(.headline.bold())
            .frame(width: 64, height: 64)
            .background(active ? Color.orange : Color.black.opacity(0.45))
            .foregroundStyle(.white)
            .clipShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

#Preview("Race Controls") {
    @Previewable @State var steer: Float = 0
    @Previewable @State var gas = false
    @Previewable @State var brake: Float = 0
    ZStack {
        Color.gray
        HStack {
            GasBrakeControls(gasPressed: $gas, brake: $brake)
            Spacer()
            VirtualJoystick(steer: $steer)
        }
        .padding(40)
    }
}
