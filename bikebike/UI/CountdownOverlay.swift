//
//  CountdownOverlay.swift
//  bikebike
//

import SwiftUI

struct CountdownOverlay: View {
    @Environment(AppState.self) private var appState

    @State private var pulse = false

    var body: some View {
        ZStack {
            if let label = appState.countdownLabel {
                Text(label)
                    .font(.system(size: label == "GO!" ? 72 : 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(label == "GO!" ? Color(hex: "34C759") ?? .green : .white)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                    .scaleEffect(pulse ? 1.25 : 1.0)
                    .animation(.easeOut(duration: 0.3), value: pulse)
                    .onChange(of: label) { _, _ in
                        pulse = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            pulse = false
                        }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview("Countdown") {
    ZStack {
        Color.black
        CountdownOverlay()
    }
    .environment(PreviewData.appState {
        $0.phase = .countdown
        $0.raceBeginTimestamp = Date().timeIntervalSince1970 + 2.2
    })
}
