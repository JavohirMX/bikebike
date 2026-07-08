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
            ARViewContainer(appState: appState, isPlacementActive: appState.phase == .placement)
                .ignoresSafeArea()

            if appState.phase == .placement {
                ARCoachingOverlayRepresentable(
                    session: appState.arSession,
                    activatesAutomatically: appState.planeDetectionStatus == .scanning,
                    planeDetectionStatus: appState.planeDetectionStatus
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                PlacementOverlay()
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
    }

    final class Coordinator {
        let arView = ARView(frame: .zero)
        let sessionCoordinator = ARSessionCoordinator()
        let placementGestures = TrackPlacementGestureHandler()

        init(appState: AppState) {
            sessionCoordinator.controller = appState.arController
        }
    }
}
