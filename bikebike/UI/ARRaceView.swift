//
//  ARRaceView.swift
//  bikebike
//

import ARKit
import Combine
import RealityKit
import SwiftUI

struct ARRaceView: View {
    @Environment(AppState.self) private var appState

    private let gameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            ARViewContainer(
                appState: appState,
                isPlacementActive: appState.phase == .placement,
                planeDetectionStatus: appState.planeDetectionStatus
            )
                .ignoresSafeArea()

            if appState.phase == .placement {
                PlacementOverlay()
            }
            if appState.phase == .countdown {
                CountdownOverlay()
            }
            if appState.phase == .racing {
                RaceHUDView()
            }
            if appState.isRelocalizing, let message = appState.relocalizationMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(message)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
                }
                .allowsHitTesting(false)
            }
        }
        .onReceive(gameTimer) { _ in
            guard appState.phase == .racing else { return }
            appState.applyInputTick(deltaTime: 1.0 / 60.0)
        }
    }
}

private struct ARViewContainer: UIViewRepresentable {
    let appState: AppState
    let isPlacementActive: Bool
    let planeDetectionStatus: PlaneDetectionStatus

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = context.coordinator.arView
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.cameraMode = .ar
        arView.environment.sceneUnderstanding.options = []

        let config = ARSessionConfigFactory.makeWorldConfig(planeDetection: true)
        arView.session.run(config)

        context.coordinator.coachingOverlay = ARCoachingOverlayHelper.attach(
            to: arView,
            delegate: context.coordinator
        )

        appState.arSession = arView.session
        appState.arController.attach(to: arView, sessionDelegate: context.coordinator.sessionCoordinator)
        context.coordinator.placementGestures.attach(to: arView, controller: appState.arController)
        context.coordinator.placementGestures.onScaleChanged = { [weak appState] scale in
            Task { @MainActor in
                appState?.placementScale = scale
            }
        }
        Task { @MainActor in
            appState.onARViewReady()
        }
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.placementGestures.setEnabled(isPlacementActive)
        if let coachingOverlay = context.coordinator.coachingOverlay {
            ARCoachingOverlayHelper.update(
                coachingOverlay,
                isPlacementActive: isPlacementActive,
                planeDetectionStatus: planeDetectionStatus
            )
        }
    }

    final class Coordinator: NSObject, ARCoachingOverlayViewDelegate {
        let arView = ARView(frame: .zero)
        let sessionCoordinator = ARSessionCoordinator()
        let placementGestures = TrackPlacementGestureHandler()
        var coachingOverlay: ARCoachingOverlayView?

        init(appState: AppState) {
            sessionCoordinator.controller = appState.arController
        }
    }
}

// Note: the live camera feed is unavailable in the Xcode canvas / Simulator,
// so the AR background renders black. The SwiftUI overlays still preview.
#Preview("Racing") {
    ARRaceView()
        .environment(PreviewData.appState {
            $0.phase = .racing
            $0.players = PreviewData.players
            $0.carStates = PreviewData.carStates
            $0.leaderboard = PreviewData.leaderboard
        })
}
