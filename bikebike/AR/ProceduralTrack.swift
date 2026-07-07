//
//  ProceduralTrack.swift
//  bikebike
//

import RealityKit
import UIKit

enum ProceduralTrack {
    static var presetId: String { OvalTrackGeometry.presetId }
    static var startGridOffset: SIMD3<Float> { OvalTrackGeometry.startGridOffset }
    static var carSize: SIMD3<Float> { OvalTrackGeometry.carSize }
    static var carHalfExtents: SIMD3<Float> { OvalTrackGeometry.carHalfExtents }

    /// Stadium-oval loop track (~0.8m × 0.5m).
    static func makeOvalLoopTrack(scale: Float = 1.0) -> Entity {
        let root = Entity()
        root.name = "TrackRoot"
        root.scale = SIMD3(repeating: scale)

        let segments = OvalTrackGeometry.segmentCount
        let floorY = OvalTrackGeometry.floorThickness / 2
        let wallY = OvalTrackGeometry.wallHeight / 2 + OvalTrackGeometry.floorThickness

        let floor = TrackMeshBuilder.makeAnnulusFloorEntity(segments: segments)
        root.addChild(floor)

        for index in 0..<segments {
            let t0 = Float(index) / Float(segments)
            let t1 = Float(index + 1) / Float(segments)

            let e0 = OvalTrackGeometry.trackEdges(at: t0)
            let e1 = OvalTrackGeometry.trackEdges(at: t1)
            let c0 = e0.center
            let c1 = e1.center

            let curbColor: UIColor = index.isMultiple(of: 2) ? .systemRed : .white
            addCurbWall(from: e0.inner, to: e1.inner, wallY: wallY, color: curbColor, name: "InnerWall\(index)", root: root)
            addCurbWall(from: e0.outer, to: e1.outer, wallY: wallY, color: curbColor, name: "OuterWall\(index)", root: root)

            if index.isMultiple(of: 4) {
                let yaw = atan2(c1.y - c0.y, c1.x - c0.x)
                let dash = makeVisualBox(
                    size: SIMD3(0.02, 0.003, 0.008),
                    color: .white,
                    position: SIMD3(c0.x, floorY + 0.004, c0.y),
                    roughness: 0.3
                )
                dash.orientation = simd_quatf(angle: -yaw, axis: SIMD3(0, 1, 0))
                root.addChild(dash)
            }
        }

        let finishPoint = OvalTrackGeometry.centerlinePoint(t: OvalTrackGeometry.finishLineParameter)
        let finishTangent = OvalTrackGeometry.centerlineTangent(t: OvalTrackGeometry.finishLineParameter)
        let finishYaw = atan2(finishTangent.y, finishTangent.x)

        let finishLine = makeVisualBox(
            size: SIMD3(OvalTrackGeometry.trackWidth, 0.05, 0.02),
            color: .white,
            position: SIMD3(finishPoint.x, 0.03, finishPoint.y)
        )
        finishLine.name = "FinishLine"
        finishLine.orientation = simd_quatf(angle: -finishYaw + .pi / 2, axis: SIMD3(0, 1, 0))
        root.addChild(finishLine)

        let spawnT = max(0, OvalTrackGeometry.finishLineParameter - 0.035)
        let spawnEdges = OvalTrackGeometry.trackEdges(at: spawnT)
        for (index, offset) in [(Float(-0.04), UIColor.systemGreen), (Float(0.0), UIColor.systemGreen), (Float(0.04), UIColor(white: 0.9, alpha: 1))].enumerated() {
            let tangent = OvalTrackGeometry.centerlineTangent(t: spawnT)
            let stripeCenter = spawnEdges.center + spawnEdges.right * offset.0
            let yaw = atan2(tangent.y, tangent.x)

            let stripe = makeVisualBox(
                size: SIMD3(0.035, 0.01, 0.06),
                color: offset.1,
                position: SIMD3(stripeCenter.x, 0.012, stripeCenter.y)
            )
            stripe.name = "StartGrid\(index)"
            stripe.orientation = simd_quatf(angle: -yaw, axis: SIMD3(0, 1, 0))
            root.addChild(stripe)
        }

        return root
    }

    static func makeCar(color: UIColor) -> Entity {
        let root = Entity()
        root.name = "Car"

        let bodySize = SIMD3(carSize.x * 0.92, carSize.y * 0.75, carSize.z * 0.88)
        let body = makeVisualBox(size: bodySize, color: color, position: SIMD3(0, carSize.y * 0.15, 0), isMetallic: true)
        root.addChild(body)

        let cabinSize = SIMD3(bodySize.x * 0.55, carSize.y * 0.45, bodySize.z * 0.45)
        let cabin = makeVisualBox(
            size: cabinSize,
            color: UIColor(white: 0.12, alpha: 1),
            position: SIMD3(0, bodySize.y * 0.55 + carSize.y * 0.15, -bodySize.z * 0.05),
            isMetallic: false
        )
        root.addChild(cabin)

        let spoiler = makeVisualBox(
            size: SIMD3(bodySize.x * 0.85, 0.004, 0.012),
            color: color.withAlphaComponent(0.9),
            position: SIMD3(0, bodySize.y * 0.35 + carSize.y * 0.15, bodySize.z * 0.42)
        )
        root.addChild(spoiler)

        let wheelRadius: Float = 0.005
        let wheelWidth: Float = 0.004
        let wheelY: Float = 0.002
        let wheelOffsets: [SIMD3<Float>] = [
            SIMD3(-bodySize.x * 0.42, wheelY, bodySize.z * 0.32),
            SIMD3(bodySize.x * 0.42, wheelY, bodySize.z * 0.32),
            SIMD3(-bodySize.x * 0.42, wheelY, -bodySize.z * 0.32),
            SIMD3(bodySize.x * 0.42, wheelY, -bodySize.z * 0.32),
        ]
        for (index, offset) in wheelOffsets.enumerated() {
            let wheel = makeVisualCylinder(
                radius: wheelRadius,
                height: wheelWidth,
                color: UIColor(white: 0.08, alpha: 1),
                position: offset
            )
            wheel.name = "Wheel\(index)"
            root.addChild(wheel)
        }

        var collision = CollisionComponent(shapes: [.generateBox(size: carSize)])
        collision.filter = CollisionFilter(
            group: .init(rawValue: 1),
            mask: [.init(rawValue: 2), .init(rawValue: 4)]
        )
        root.components.set(collision)

        var physics = PhysicsBodyComponent(
            massProperties: .init(mass: 1.5),
            material: .generate(friction: 0.8, restitution: 0.2),
            mode: .kinematic
        )
        physics.isRotationLocked = (true, false, true)
        root.components.set(physics)

        return root
    }

    // MARK: - Builders

    private static func addCurbWall(
        from start: SIMD2<Float>,
        to end: SIMD2<Float>,
        wallY: Float,
        color: UIColor,
        name: String,
        root: Entity
    ) {
        let midpoint = (start + end) / 2
        let edgeVector = end - start
        let length = max(simd_length(edgeVector), 0.012)
        let yaw = atan2(edgeVector.y, edgeVector.x)

        let wall = makeVisualBox(
            size: SIMD3(length, OvalTrackGeometry.wallHeight, OvalTrackGeometry.wallThickness),
            color: color,
            position: SIMD3(midpoint.x, wallY, midpoint.y)
        )
        wall.name = name
        wall.orientation = simd_quatf(angle: -yaw, axis: SIMD3(0, 1, 0))
        root.addChild(wall)
    }

    private static func makeVisualBox(
        size: SIMD3<Float>,
        color: UIColor,
        position: SIMD3<Float>,
        isMetallic: Bool = false,
        roughness: MaterialScalarParameter = 0.35
    ) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: size)
        let material = SimpleMaterial(color: color, roughness: roughness, isMetallic: isMetallic)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        return entity
    }

    private static func makeVisualCylinder(
        radius: Float,
        height: Float,
        color: UIColor,
        position: SIMD3<Float>
    ) -> ModelEntity {
        let mesh = MeshResource.generateCylinder(height: height, radius: radius)
        let material = SimpleMaterial(color: color, roughness: 0.6, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        entity.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(0, 0, 1))
        return entity
    }
}
