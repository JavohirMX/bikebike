//
//  VirtualJoystick.swift
//  racecar
//

import SwiftUI

struct VirtualJoystick: View {
    @Binding var steer: Float
    @Binding var throttle: Float

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
                    let dy = value.translation.height
                    let dist = sqrt(dx * dx + dy * dy)
                    let clampedDist = min(dist, maxRadius)
                    let angle = atan2(dy, dx)
                    dragOffset = CGSize(
                        width: cos(angle) * clampedDist,
                        height: sin(angle) * clampedDist
                    )
                    var nx = Float(dx / maxRadius)
                    var ny = Float(-dy / maxRadius)
                    if abs(nx) < deadZone { nx = 0 }
                    if abs(ny) < deadZone { ny = 0 }
                    steer = max(-1, min(1, nx))
                    throttle = max(0, min(1, ny))
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                    steer = 0
                    throttle = 0
                }
        )
    }
}

struct GasBrakeControls: View {
    @Binding var throttle: Float
    @Binding var brake: Float

    var body: some View {
        VStack(spacing: 16) {
            controlButton(label: "GAS", active: throttle > 0) {
                throttle = 1
            } onRelease: {
                throttle = 0
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
