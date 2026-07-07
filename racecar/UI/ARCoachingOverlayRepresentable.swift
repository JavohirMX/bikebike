//
//  ARCoachingOverlayRepresentable.swift
//  racecar
//

import ARKit
import SwiftUI

struct ARCoachingOverlayRepresentable: UIViewRepresentable {
    let session: ARSession
    var activatesAutomatically: Bool

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
    }
}
