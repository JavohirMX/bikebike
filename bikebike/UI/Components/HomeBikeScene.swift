//
//  HomeBikeScene.swift
//  bikebike
//

import SwiftUI

enum HomeBikeSceneMode: Equatable {
    case parked
    case multiplayerParked
    case soloMoving
    case multiplayerMoving
}

struct HomeBikeScene: View {
    let mode: HomeBikeSceneMode

    @State private var leadProgress: CGFloat = 0
    @State private var joinProgress: CGFloat = 0
    @State private var trailingProgress: CGFloat = 0
    @State private var soloEntryProgress: CGFloat = 0
    @State private var idleBob: CGFloat = 0
    @State private var hasStarted = false

    private let bikeHeight: CGFloat = 180
    private let multiplayerBikeSpacing: CGFloat = 120
    private let multiplayerTrailingOffset: CGFloat = 70

    var body: some View {
        GeometryReader { geometry in
            let roadY = geometry.size.height * 0.72
            let parkedX = geometry.size.width * 0.22

            ZStack {
                if mode == .parked || mode == .soloMoving || mode == .multiplayerMoving {
                    bikeImage("rider-ish")
                        .frame(height: bikeHeight)
                        .position(
                            x: leadBikeX(in: geometry, parkedX: parkedX),
                            y: roadY + (mode == .parked ? idleBob : 0)
                        )
                }

                if mode == .soloMoving {
                    bikeImage("rider-ish")
                        .frame(height: bikeHeight)
                        .position(
                            x: soloEntryBikeX(in: geometry, parkedX: parkedX),
                            y: roadY
                        )
                }

                if mode == .multiplayerMoving || mode == .multiplayerParked {
                    bikeImage("rider-ish")
                        .frame(height: bikeHeight)
                        .position(
                            x: trailingBikeX(in: geometry, parkedX: parkedX),
                            y: roadY + (mode == .multiplayerParked ? idleBob : 0)
                        )
                }

                if mode == .multiplayerMoving || mode == .multiplayerParked {
                    bikeImage("rider-talin")
                        .frame(height: bikeHeight)
                        .position(
                            x: joinBikeX(in: geometry, parkedX: parkedX),
                            y: roadY + (mode == .multiplayerParked ? idleBob : 0)
                        )
                }
            }
        }
        .onAppear {
            switch mode {
            case .parked, .multiplayerParked:
                startIdleBob()
            case .soloMoving, .multiplayerMoving:
                startDeparture()
            }
        }
        .onChange(of: mode) { _, newMode in
            leadProgress = 0
            joinProgress = 0
            trailingProgress = 0
            soloEntryProgress = 0
            hasStarted = false
            switch newMode {
            case .parked, .multiplayerParked:
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
        case .parked, .multiplayerParked:
            return parkedX
        case .soloMoving, .multiplayerMoving:
            let travel = geometry.size.width * 1.2
            return parkedX + leadProgress * travel
        }
    }

    private func joinBikeX(in geometry: GeometryProxy, parkedX: CGFloat) -> CGFloat {
        if mode == .multiplayerParked {
            return leadMultiplayerBikeX(parkedX: parkedX)
        }

        let startX = -geometry.size.width * 0.35
        let targetX = leadMultiplayerBikeX(parkedX: parkedX)
        return startX + (targetX - startX) * joinProgress
    }

    private func trailingBikeX(in geometry: GeometryProxy, parkedX: CGFloat) -> CGFloat {
        if mode == .multiplayerParked {
            return trailingMultiplayerBikeX(parkedX: parkedX)
        }

        let startX = -geometry.size.width * 0.35
        let targetX = trailingMultiplayerBikeX(parkedX: parkedX)
        return startX + (targetX - startX) * trailingProgress
    }

    private func soloEntryBikeX(in geometry: GeometryProxy, parkedX: CGFloat) -> CGFloat {
        let startX = -geometry.size.width * 0.35
        return startX + (parkedX - startX) * soloEntryProgress
    }

    private func leadMultiplayerBikeX(parkedX: CGFloat) -> CGFloat {
        parkedX + multiplayerBikeSpacing
    }

    private func trailingMultiplayerBikeX(parkedX: CGFloat) -> CGFloat {
        parkedX - multiplayerTrailingOffset
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

        if mode == .soloMoving {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(850))
                withAnimation(.easeOut(duration: 0.8)) {
                    soloEntryProgress = 1
                }
            }
        } else if mode == .multiplayerMoving {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(850))
                withAnimation(.easeOut(duration: 0.8)) {
                    joinProgress = 1
                }
                try? await Task.sleep(for: .milliseconds(800))
                withAnimation(.easeOut(duration: 0.8)) {
                    trailingProgress = 1
                }
            }
        }
    }
}

#Preview("Parked", traits: .landscapeLeft) {
    HomeBikeScene(mode: .parked)
        .frame(height: 220)
        .padding()
}

#Preview("Multiplayer Moving", traits: .landscapeLeft) {
    HomeBikeScene(mode: .multiplayerMoving)
        .frame(height: 220)
        .padding()
}
