//
//  ARSessionCoordinator.swift
//  bikebike
//

import ARKit

final class ARSessionCoordinator: NSObject, ARSessionDelegate {
    weak var controller: ARSceneController?

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let hasHorizontalPlane = frame.anchors.contains { anchor in
            guard let plane = anchor as? ARPlaneAnchor else { return false }
            return plane.alignment == .horizontal && plane.planeExtent.width >= 0.15 && plane.planeExtent.height >= 0.15
        }
        Task { @MainActor in
            controller?.updatePlaneDetection(hasHorizontalPlane: hasHorizontalPlane)
            guard controller?.isAwaitingRelocalization == true else { return }
            if frame.worldMappingStatus == .mapped,
               case .normal = frame.camera.trackingState {
                controller?.notifyRelocalizationReady()
            }
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        Task { @MainActor in
            controller?.updateTrackingState(camera.trackingState)
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            controller?.updateTrackingState(.notAvailable)
        }
    }
}
