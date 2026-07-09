//
//  ARSessionCoordinator.swift
//  bikebike
//

import ARKit

final class ARSessionCoordinator: NSObject, ARSessionDelegate {
    weak var controller: ARSceneController?

    private let stateLock = NSLock()
    private var qualifyingPlaneIDs: Set<UUID> = []
    private var lastDispatchedHasHorizontalPlane: Bool?

    func resetPlaneTracking() {
        stateLock.lock()
        qualifyingPlaneIDs.removeAll()
        lastDispatchedHasHorizontalPlane = nil
        stateLock.unlock()
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        refreshQualifyingPlanes(anchors)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        refreshQualifyingPlanes(anchors)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        stateLock.lock()
        for anchor in anchors where anchor is ARPlaneAnchor {
            qualifyingPlaneIDs.remove(anchor.identifier)
        }
        let hasPlane = !qualifyingPlaneIDs.isEmpty
        let changed = lastDispatchedHasHorizontalPlane != hasPlane
        if changed {
            lastDispatchedHasHorizontalPlane = hasPlane
        }
        stateLock.unlock()

        if changed {
            dispatchPlaneDetection(hasHorizontalPlane: hasPlane)
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let trackingState = camera.trackingState
        DispatchQueue.main.async { [weak self] in
            self?.controller?.updateTrackingState(trackingState)
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.controller?.updateTrackingState(.notAvailable)
        }
    }

    private func refreshQualifyingPlanes(_ anchors: [ARAnchor]) {
        stateLock.lock()
        for anchor in anchors {
            guard let plane = anchor as? ARPlaneAnchor else { continue }
            if Self.isQualifyingHorizontalPlane(plane) {
                qualifyingPlaneIDs.insert(plane.identifier)
            } else {
                qualifyingPlaneIDs.remove(plane.identifier)
            }
        }
        let hasPlane = !qualifyingPlaneIDs.isEmpty
        let changed = lastDispatchedHasHorizontalPlane != hasPlane
        if changed {
            lastDispatchedHasHorizontalPlane = hasPlane
        }
        stateLock.unlock()

        if changed {
            dispatchPlaneDetection(hasHorizontalPlane: hasPlane)
        }
    }

    private func dispatchPlaneDetection(hasHorizontalPlane: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.controller?.updatePlaneDetection(hasHorizontalPlane: hasHorizontalPlane)
        }
    }

    private static func isQualifyingHorizontalPlane(_ plane: ARPlaneAnchor) -> Bool {
        plane.alignment == .horizontal
            && plane.planeExtent.width >= 0.15
            && plane.planeExtent.height >= 0.15
    }
}
