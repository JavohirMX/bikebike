//
//  HomeBikeScene.swift
//  bikebike
//

import SwiftUI

enum HomeBikeSceneMode: Equatable {
    case parked
    case soloMoving
    case multiplayerMoving
}

struct HomeBikeScene: View {
    let mode: HomeBikeSceneMode

    @State private var leadProgress: CGFloat = 0
    @State private var joinProgress: CGFloat = 0
    @State private var idleBob: CGFloat = 0
    @State private var hasStarted = false

    private let bikeHeight: CGFloat = 90

    var body: some View {
        GeometryReader { geometry in
            let roadY = geometry.size.height * 0.72
            let parkedX = geometry.size.width * 0.22
            let laneOffset: CGFloat = 18

            ZStack {
                if mode == .parked || mode == .soloMoving || mode == .multiplayerMoving {
                    bikeImage("rider-ish")
                        .frame(height: bikeHeight)
                        .position(
                            x: leadBikeX(in: geometry, parkedX: parkedX),
                            y: roadY + (mode == .parked ? idleBob : 0)
                        )
                }

                if mode == .multiplayerMoving {
                    bikeImage("rider-talin")
                        .frame(height: bikeHeight)
                        .position(
                            x: joinBikeX(in: geometry, parkedX: parkedX, laneOffset: laneOffset),
                            y: roadY + laneOffset
                        )
                        .opacity(joinProgress > 0 ? 1 : 0)
                }
            }
        }
        .onAppear {
            switch mode {
            case .parked:
                startIdleBob()
            case .soloMoving, .multiplayerMoving:
                startDeparture()
            }
        }
        .onChange(of: mode) { _, newMode in
            leadProgress = 0
            joinProgress = 0
            hasStarted = false
            switch newMode {
            case .parked:
                startIdleBob()
            case .soloMoving, .multiplayerMoving:
                startDeparture()
            }
        }
    }

    private func bikeImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
    }

    private func leadBikeX(in geometry: GeometryProxy, parkedX: CGFloat) -> CGFloat {
        switch mode {
        case .parked:
            return parkedX
        case .soloMoving, .multiplayerMoving:
            let travel = geometry.size.width * 1.2
            return parkedX + leadProgress * travel
        }
    }

    private func joinBikeX(in geometry: GeometryProxy, parkedX: CGFloat, laneOffset: CGFloat) -> CGFloat {
        let startX = -geometry.size.width * 0.15
        let targetX = parkedX - 60 + leadProgress * geometry.size.width * 0.5
        return startX + (targetX - startX) * joinProgress
    }

    private func startIdleBob() {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            idleBob = -2
        }
    }

    private func startDeparture() {
        guard !hasStarted else { return }
        hasStarted = true

        withAnimation(.easeIn(duration: 1.0)) {
            leadProgress = 1
        }

        if mode == .multiplayerMoving {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.easeOut(duration: 0.9)) {
                    joinProgress = 1
                }
            }
        }
    }
}
