//
//  LocalPlayerIndicator.swift
//  bikebike
//

import RealityKit
import UIKit

enum LocalPlayerIndicator {
    static let anchorName = "LocalPlayerIndicator"
    static let heightAboveCar: Float = 0.12
    private static let coneHeight: Float = 0.028
    private static let coneRadius: Float = 0.015
    private static let bobAmplitude: Float = 0.008
    private static let bobSpeed: Float = 3.0

    static func make(accentHex: String) -> Entity {
        let root = Entity()
        root.name = anchorName
        root.position = SIMD3(0, heightAboveCar, 0)

        let baseColor = UIColor(hex: accentHex) ?? .systemBlue
        let material = SimpleMaterial(color: baseColor, roughness: 0.15, isMetallic: false)

        let cone = ModelEntity(
            mesh: .generateCone(height: coneHeight, radius: coneRadius),
            materials: [material]
        )
        // RealityKit cones point along +Y; flip so the tip aims down at the bike.
        cone.orientation = simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0))
        cone.components.remove(CollisionComponent.self)
        root.addChild(cone)

        return root
    }

    static func bobOffset(time: TimeInterval) -> Float {
        bobAmplitude * sin(Float(time) * bobSpeed)
    }
}
