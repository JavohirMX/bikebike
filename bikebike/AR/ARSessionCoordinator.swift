//
//  ARSessionCoordinator.swift
//  bikebike
//

import ARKit

final class ARSessionCoordinator: NSObject, ARSessionDelegate {
    weak var controller: ARSceneController?

    private var lastDispatchedHasHorizontalPlane: Bool?
    private var relocalizationPollingActive = false

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let hasHorizontalPlane = frame.anchors.contains { anchor in
            guard let plane = anchor as? ARPlaneAnchor else { return false }
            return plane.alignment == .horizontal && plane.planeExtent.width >= 0.15 && plane.planeExtent.height >= 0.15
        }
        let worldMappingStatus = frame.worldMappingStatus
        let trackingState = frame.camera.trackingState

        let planeChanged = lastDispatchedHasHorizontalPlane != hasHorizontalPlane
        guard planeChanged || relocalizationPollingActive else { return }

        if planeChanged {
            lastDispatchedHasHorizontalPlane = hasHorizontalPlane
        }

        Task { @MainActor in
            relocalizationPollingActive = controller?.isAwaitingRelocalization == true

            controller?.updatePlaneDetection(hasHorizontalPlane: hasHorizontalPlane)
            guard relocalizationPollingActive else { return }
            if worldMappingStatus == .mapped, case .normal = trackingState {
                controller?.notifyRelocalizationReady()
            }
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let trackingState = camera.trackingState
        Task { @MainActor in
            controller?.updateTrackingState(trackingState)
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            controller?.updateTrackingState(.notAvailable)
        }
    }
}
