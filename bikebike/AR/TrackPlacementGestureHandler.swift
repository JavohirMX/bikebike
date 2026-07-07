//
//  TrackPlacementGestureHandler.swift
//  bikebike
//

import ARKit
import RealityKit
import UIKit

@MainActor
final class TrackPlacementGestureHandler: NSObject {
    weak var arView: ARView?
    weak var controller: ARSceneController?

    var onScaleChanged: ((Float) -> Void)?

    private var pinchStartScale: Float = 1.0
    private var isEnabled = false

    private lazy var tapGesture: UITapGestureRecognizer = {
        UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    }()

    private lazy var panGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        gesture.maximumNumberOfTouches = 1
        return gesture
    }()

    private lazy var pinchGesture: UIPinchGestureRecognizer = {
        UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
    }()

    private lazy var rotationGesture: UIRotationGestureRecognizer = {
        UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
    }()

    func attach(to arView: ARView, controller: ARSceneController) {
        self.arView = arView
        self.controller = controller
        arView.addGestureRecognizer(tapGesture)
        arView.addGestureRecognizer(panGesture)
        arView.addGestureRecognizer(pinchGesture)
        arView.addGestureRecognizer(rotationGesture)
        pinchGesture.delegate = self
        rotationGesture.delegate = self
        tapGesture.delegate = self
        setEnabled(false)
    }

    func detach() {
        guard let arView else { return }
        arView.removeGestureRecognizer(tapGesture)
        arView.removeGestureRecognizer(panGesture)
        arView.removeGestureRecognizer(pinchGesture)
        arView.removeGestureRecognizer(rotationGesture)
        self.arView = nil
        self.controller = nil
        isEnabled = false
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        tapGesture.isEnabled = enabled
        panGesture.isEnabled = enabled
        pinchGesture.isEnabled = enabled
        rotationGesture.isEnabled = enabled
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard isEnabled, gesture.state == .ended, let arView, let controller else { return }
        let point = gesture.location(in: arView)
        controller.updatePlacement(raycastFrom: point, in: arView)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard isEnabled, let arView, let controller else { return }
        let point = gesture.location(in: arView)
        controller.updatePlacement(raycastFrom: point, in: arView)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard isEnabled, let controller else { return }
        switch gesture.state {
        case .began:
            pinchStartScale = controller.placementScale
        case .changed:
            let scale = pinchStartScale * Float(gesture.scale)
            controller.setPlacementScale(scale)
            onScaleChanged?(controller.placementScale)
        default:
            break
        }
    }

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard isEnabled, let controller else { return }
        if gesture.state == .changed {
            controller.addPlacementYaw(-Float(gesture.rotation))
            gesture.rotation = 0
        }
    }
}

extension TrackPlacementGestureHandler: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        let isPinchOrRotate = gestureRecognizer === pinchGesture || gestureRecognizer === rotationGesture
        let otherIsPinchOrRotate = otherGestureRecognizer === pinchGesture || otherGestureRecognizer === rotationGesture
        return isPinchOrRotate && otherIsPinchOrRotate
    }
}
