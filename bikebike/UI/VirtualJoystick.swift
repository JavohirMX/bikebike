//
//  VirtualJoystick.swift
//  bikebike
//

import Combine
import SwiftUI

struct SteerArrowButtons: View {
    @Binding var steer: Float

    private let steerRampRate: Float = 15.0
    private let tickInterval: TimeInterval = 1.0 / 60.0
    private let buttonSize: CGFloat = 67
    private let iconSize: CGFloat = 29

    @State private var leftPressed = false
    @State private var rightPressed = false

    private var steerTarget: Float {
        if leftPressed, !rightPressed { return -1 }
        if rightPressed, !leftPressed { return 1 }
        return 0
    }

    var body: some View {
        HStack(spacing: 12) {
            BikeBikeIconButton(
                systemImage: "chevron.left",
                style: .yellow,
                size: buttonSize,
                iconSize: iconSize,
                isPressed: leftPressed,
                showsStroke: false,
                onPress: { leftPressed = true },
                onRelease: { leftPressed = false }
            )
            BikeBikeIconButton(
                systemImage: "chevron.right",
                style: .yellow,
                size: buttonSize,
                iconSize: iconSize,
                isPressed: rightPressed,
                showsStroke: false,
                onPress: { rightPressed = true },
                onRelease: { rightPressed = false }
            )
        }
        .onReceive(Timer.publish(every: tickInterval, on: .main, in: .common).autoconnect()) { _ in
            rampSteer(toward: steerTarget, deltaTime: Float(tickInterval))
        }
    }

    private func rampSteer(toward target: Float, deltaTime: Float) {
        if target == 0 {
            steer = 0
        } else {
            if steer < target {
                steer = min(target, steer + steerRampRate * deltaTime)
            } else if steer > target {
                steer = max(target, steer - steerRampRate * deltaTime)
            }
        }
    }
}

struct GasButton: View {
    @Binding var gasPressed: Bool

    var body: some View {
        BikeBikeIconButton(
            systemImage: "chevron.up.2",
            style: .yellow,
            size: 86,
            iconSize: 36,
            isPressed: gasPressed,
            showsStroke: false,
            onPress: { gasPressed = true },
            onRelease: { gasPressed = false }
        )
    }
}

struct LeftDriveControls: View {
    @Binding var gasPressed: Bool
    let boostCooldownProgress: Double
    let boostReady: Bool
    let boostActive: Bool
    let onBoostTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BoostButton(
                cooldownProgress: boostCooldownProgress,
                isReady: boostReady,
                isActive: boostActive,
                onTap: onBoostTap
            )
            .padding(.leading, 14)
            GasButton(gasPressed: $gasPressed)
        }
    }
}

struct BoostButton: View {
    let cooldownProgress: Double
    let isReady: Bool
    let isActive: Bool
    let onTap: () -> Void

    private let boostSize: CGFloat = 53
    private let ringSize: CGFloat = 62

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 3)
                .frame(width: ringSize, height: ringSize)
            Circle()
                .trim(from: 0, to: cooldownProgress)
                .stroke(
                    AngularGradient(
                        colors: [Color(hex: "FF375F") ?? .pink, Color(hex: "FF9500") ?? .orange],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)

            BikeBikeIconButton(
                systemImage: "bolt.fill",
                style: .blue,
                size: boostSize,
                iconSize: 22,
                isEnabled: isReady,
                isPressed: isActive,
                action: onTap
            )
            
        }
        .offset(x: 30, y: 10)
    }
}

#Preview("Race Controls") {
    @Previewable @State var steer: Float = 0
    @Previewable @State var gas = false
    ZStack {
        BikeBikeBackground(blurRadius: 4)
        HStack(alignment: .bottom) {
            LeftDriveControls(
                gasPressed: $gas,
                boostCooldownProgress: 0.6,
                boostReady: true,
                boostActive: false,
                onBoostTap: {}
            )
            Spacer()
            SteerArrowButtons(steer: $steer)
        }
        .padding(40)
    }
}
