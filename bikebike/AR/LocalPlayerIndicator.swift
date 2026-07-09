//
//  LocalPlayerIndicator.swift
//  bikebike
//

import RealityKit
import UIKit

enum LocalPlayerIndicator {
    static let anchorName = "LocalPlayerIndicator"
    static let heightAboveCar: Float = 0.12
    private static let bobAmplitude: Float = 0.008
    private static let bobSpeed: Float = 3.0

    static func make(accentHex: String) -> Entity {
        let root = Entity()
        root.name = anchorName
        root.position = SIMD3(0, heightAboveCar, 0)

        let baseColor = UIColor(hex: accentHex) ?? .systemBlue
        let material = SimpleMaterial(color: baseColor, roughness: 0.15, isMetallic: false)

        let armSize = SIMD3<Float>(0.003, 0.022, 0.004)
        let spread: Float = 0.009
        let drop: Float = 0.009

        let leftArm = ModelEntity(mesh: .generateBox(size: armSize), materials: [material])
        leftArm.position = SIMD3(-spread, -drop, 0)
        leftArm.orientation = simd_quatf(angle: -.pi / 4, axis: SIMD3(0, 0, 1))
        leftArm.components.remove(CollisionComponent.self)
        root.addChild(leftArm)

        let rightArm = ModelEntity(mesh: .generateBox(size: armSize), materials: [material])
        rightArm.position = SIMD3(spread, -drop, 0)
        rightArm.orientation = simd_quatf(angle: .pi / 4, axis: SIMD3(0, 0, 1))
        rightArm.components.remove(CollisionComponent.self)
        root.addChild(rightArm)

        return root
    }

    static func bobOffset(time: TimeInterval) -> Float {
        bobAmplitude * sin(Float(time) * bobSpeed)
    }
}
