//
//  ARCoachingOverlayRepresentable.swift
//  bikebike
//

import ARKit
import RealityKit
import UIKit

enum ARCoachingOverlayHelper {
    static func attach(to arView: ARView, delegate: ARCoachingOverlayViewDelegate?) -> ARCoachingOverlayView {
        let overlay = ARCoachingOverlayView()
        overlay.session = arView.session
        overlay.goal = .horizontalPlane
        overlay.activatesAutomatically = false
        overlay.delegate = delegate
        overlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: arView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: arView.bottomAnchor),
        ])
        return overlay
    }

    static func update(
        _ overlay: ARCoachingOverlayView,
        isPlacementActive: Bool,
        planeDetectionStatus: PlaneDetectionStatus
    ) {
        overlay.isHidden = !isPlacementActive
        guard isPlacementActive else {
            overlay.setActive(false, animated: true)
            return
        }

        switch planeDetectionStatus {
        case .scanning:
            overlay.setActive(true, animated: true)
        case .surfaceFound, .ready:
            overlay.setActive(false, animated: true)
        }
    }
}
