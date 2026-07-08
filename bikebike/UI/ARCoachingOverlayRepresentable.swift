//
//  ARCoachingOverlayRepresentable.swift
//  bikebike
//

import ARKit
import SwiftUI

struct ARCoachingOverlayRepresentable: UIViewRepresentable {
    let session: ARSession
    var activatesAutomatically: Bool
    var planeDetectionStatus: PlaneDetectionStatus

    func makeUIView(context: Context) -> ARCoachingOverlayView {
        let overlay = ARCoachingOverlayView()
        overlay.session = session
        overlay.goal = .horizontalPlane
        overlay.activatesAutomatically = activatesAutomatically
        return overlay
    }

    func updateUIView(_ uiView: ARCoachingOverlayView, context: Context) {
        uiView.session = session
        uiView.activatesAutomatically = activatesAutomatically
        switch planeDetectionStatus {
        case .ready, .surfaceFound:
            uiView.setActive(false, animated: true)
        case .scanning:
            break
        }
    }
}
