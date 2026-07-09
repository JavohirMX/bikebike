//
//  VirtualJoystick.swift
//  bikebike
//

import Combine
import SwiftUI

struct SteerArrowButtons: View {
    @Binding var steer: Float

    private let steerRampRate: Float = 2.5
    private let tickInterval: TimeInterval = 1.0 / 60.0

    @State private var leftPressed = false
    @State private var rightPressed = false

    private var steerTarget: Float {
        if leftPressed, !rightPressed { return -1 }
        if rightPressed, !leftPressed { return 1 }
        return 0
    }

    var body: some View {
        HStack(spacing: 12) {
            steerButton(systemName: "chevron.left", active: leftPressed) {
                leftPressed = true
            } onRelease: {
                leftPressed = false
            }
            steerButton(systemName: "chevron.right", active: rightPressed) {
                rightPressed = true
            } onRelease: {
                rightPressed = false
            }
        }
        .onReceive(Timer.publish(every: tickInterval, on: .main, in: .common).autoconnect()) { _ in
            rampSteer(toward: steerTarget, deltaTime: Float(tickInterval))
        }
    }

    private func rampSteer(toward target: Float, deltaTime: Float) {
        if steer < target {
            steer = min(target, steer + steerRampRate * deltaTime)
        } else if steer > target {
            steer = max(target, steer - steerRampRate * deltaTime)
        }
    }

    private func steerButton(
        systemName: String,
        active: Bool,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemName)
            .font(.title2.bold())
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
