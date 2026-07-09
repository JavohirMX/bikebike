//
//  BikeBikePillButton.swift
//  bikebike
//

import SwiftUI

enum BikeBikePillStyle {
    case yellow
    case blue
}

struct BikeBikePillButton: View {
    let title: String
    var systemImage: String? = nil
    var style: BikeBikePillStyle = .yellow
    var isEnabled: Bool = true
    /// Controls when the inner highlight sweep plays.
    var glowMode: SpinningInnerGlow.Mode = .welcomeThenIdle(interval: 6)
    /// Delay before the first sweep — use to stagger multiple buttons.
    var glowStartDelay: Double = 0
    let action: () -> Void

    private var fillColor: Color {
        switch style {
        case .yellow: BikeBikeTheme.yellow
        case .blue: BikeBikeTheme.skyBlue
        }
    }

    private var shadowColor: Color {
        switch style {
        case .yellow: Color(hex: "C9A800") ?? .orange
        case .blue: Color(hex: "3A8FD4") ?? .blue
        }
    }

    private var strokeColor: Color {
        switch style {
        case .yellow: Color(hex: "00AEEF") ?? BikeBikeTheme.skyBlue
        case .blue: Color(hex: "21A8E0") ?? .blue
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .bold))
                }
                Text(title)
                    .font(BikeBikeTheme.buttonFont(size: 29))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 20)
            .background(
                Capsule()
                    .fill(fillColor)
                    .shadow(color: shadowColor.opacity(0.45), radius: 6, x: 0, y: 3)
                    .overlay(
                        SpinningInnerGlow(
                            isActive: isEnabled,
                            mode: glowMode,
                            startDelay: glowStartDelay
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(strokeColor, lineWidth: 1)
                    )
                    .clipShape(Capsule())
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

/// A subtle FIFA-style highlight that sweeps around the inside edge of a capsule.
///
/// Each sweep is a single soft pass of light that fades in and out. When it
/// plays is controlled by `Mode`:
/// - `.welcome`: one sweep shortly after appearing, then still.
/// - `.idleNudge`: a sweep every `interval` seconds of stillness.
/// - `.welcomeThenIdle`: a welcome sweep, then idle nudges afterwards.
/// - `.occasional`: a repeating shimmer with no separate welcome beat.
///
/// Use `startDelay` to stagger several buttons so they sweep in sequence.
struct SpinningInnerGlow: View {
    enum Mode: Equatable {
        case welcome
        case idleNudge(interval: Double)
        case welcomeThenIdle(interval: Double)
        case occasional(interval: Double)
    }

    var isActive: Bool = true
    var mode: Mode = .welcomeThenIdle(interval: 6)
    /// Delay before the first sweep — use to stagger multiple buttons.
    var startDelay: Double = 0
    /// Seconds for one sweep around the capsule.
    var sweepDuration: Double = 1.8
    /// Peak opacity of the moving highlight (kept low for subtlety).
    var intensity: Double = 0.55
    var lineWidth: CGFloat = 4

    @State private var angle: Angle = .degrees(0)
    @State private var glowOpacity: Double = 0
    @State private var timer: Timer?
    @State private var startWork: DispatchWorkItem?

    var body: some View {
        Capsule()
            .stroke(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(0), location: 0.0),
                        .init(color: .white.opacity(0), location: 0.30),
                        .init(color: .white.opacity(intensity), location: 0.5),
                        .init(color: .white.opacity(0), location: 0.70),
                        .init(color: .white.opacity(0), location: 1.0),
                    ]),
                    center: .center,
                    angle: angle
                ),
                lineWidth: lineWidth
            )
            .blur(radius: 5)
            .padding(1)
            .blendMode(.plusLighter)
            .opacity(glowOpacity)
            .onAppear { schedule() }
            .onDisappear { cancelAll() }
            .onChange(of: isActive) { _, _ in schedule() }
    }

    private func schedule() {
        cancelAll()
        guard isActive else {
            glowOpacity = 0
            return
        }
        let work = DispatchWorkItem { begin() }
        startWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay, execute: work)
    }

    private func begin() {
        switch mode {
        case .welcome:
            sweepOnce()
        case .idleNudge(let interval):
            startNudging(interval: interval, sweepFirst: false)
        case .welcomeThenIdle(let interval):
            sweepOnce()
            startNudging(interval: interval, sweepFirst: false)
        case .occasional(let interval):
            startNudging(interval: interval, sweepFirst: true)
        }
    }

    /// Fires a sweep every `sweepDuration + interval` seconds (i.e. `interval`
    /// seconds of stillness between passes).
    private func startNudging(interval: Double, sweepFirst: Bool) {
        if sweepFirst { sweepOnce() }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: sweepDuration + interval, repeats: true) { _ in
            sweepOnce()
        }
    }

    private func sweepOnce() {
        // Start with the highlight on the RIGHT edge (angle 180 -> hot spot at
        // 0°). The pass fades in/out at its start and end, so keeping those
        // moments on the right — where there's no icon — lets the light reach
        // full brightness as it crosses the left side mid-sweep.
        angle = .degrees(180)
        glowOpacity = 0
        withAnimation(.linear(duration: sweepDuration)) {
            angle = .degrees(540)
        }
        withAnimation(.easeOut(duration: sweepDuration * 0.15)) {
            glowOpacity = 1
        }
        withAnimation(.easeIn(duration: sweepDuration * 0.15).delay(sweepDuration * 0.85)) {
            glowOpacity = 0
        }
    }

    private func cancelAll() {
        startWork?.cancel()
        startWork = nil
        timer?.invalidate()
        timer = nil
    }
}

#Preview("Pill Buttons") {
    VStack(spacing: 16) {
        BikeBikePillButton(title: "Soloplayer", systemImage: "person.fill", style: .yellow) {}
        BikeBikePillButton(title: "Multiplayer", systemImage: "person.3.fill", style: .blue) {}
        BikeBikePillButton(title: "Disabled", systemImage: "lock.fill", style: .yellow, isEnabled: false) {}
    }
    .frame(width: 280)
    .padding()
}
