//
//  TrackDebugVisualizer.swift
//  bikebike
//

import RealityKit
import UIKit
import simd

enum TrackDebugVisualizer {
    private static let overlayHeight: Float = 0.004
    private static let overlayWidth: Float = 0.006
    private static let surfaceLift: Float = 0.008

    static func makeOverlay(for geometry: any RaceTrackGeometry) -> Entity? {
        guard let corridor = geometry.debugCorridor else { return nil }

        let root = Entity()
        root.name = "TrackDebugOverlay"

        addPolylineLoop(
            points: corridor.points,
            heights: corridor.heights,
            color: .systemYellow,
            namePrefix: "Centerline",
            to: root
        )

        let innerBorder = borderLoop(
            points: corridor.points,
            heights: corridor.heights,
            halfWidth: corridor.halfWidth,
            side: -1
        )
        let outerBorder = borderLoop(
            points: corridor.points,
            heights: corridor.heights,
            halfWidth: corridor.halfWidth,
            side: 1
        )

        addPolylineLoop(
            points: innerBorder.points,
            heights: innerBorder.heights,
            color: .systemRed,
            namePrefix: "InnerBorder",
            to: root
        )
        addPolylineLoop(
            points: outerBorder.points,
            heights: outerBorder.heights,
            color: .systemBlue,
            namePrefix: "OuterBorder",
            to: root
        )

        if let finish = frame(atArcLength: corridor.finishArcLength, on: corridor) {
            let barLength = corridor.halfWidth * 2
            let finishBar = makeSegmentBox(
                from: finish.point - finish.right * (barLength / 2),
                to: finish.point + finish.right * (barLength / 2),
                y: finish.height + surfaceLift,
                color: .white,
                thickness: overlayWidth * 1.4
            )
            finishBar.name = "FinishMarker"
            root.addChild(finishBar)
        }

        for gridIndex in 0..<3 {
            let spawn = geometry.spawnTransform(gridIndex: gridIndex)
            let marker = makeSpawnMarker(at: spawn.position)
            marker.name = "SpawnGrid\(gridIndex)"
            root.addChild(marker)
        }

        return root
    }

    // MARK: - Border geometry

    private static func borderLoop(
        points: [SIMD2<Float>],
        heights: [Float],
        halfWidth: Float,
        side: Float
    ) -> (points: [SIMD2<Float>], heights: [Float]) {
        guard points.count >= 2, heights.count == points.count else {
            return ([], [])
        }

        var borderPoints: [SIMD2<Float>] = []
        var borderHeights: [Float] = []
        borderPoints.reserveCapacity(points.count)
        borderHeights.reserveCapacity(points.count)

        for index in 0..<points.count {
            let point = points[index]
            let next = points[(index + 1) % points.count]
            let tangent = simd_normalize(next - point)
            let right = SIMD2(tangent.y, -tangent.x)
            borderPoints.append(point + right * (halfWidth * side))
            borderHeights.append(heights[index])
        }

        return (borderPoints, borderHeights)
    }

    private static func frame(
        atArcLength arc: Float,
        on corridor: TrackDebugCorridorData
    ) -> (point: SIMD2<Float>, right: SIMD2<Float>, height: Float)? {
        let points = corridor.points
        guard points.count >= 2, corridor.perimeter > 0, corridor.heights.count == points.count else {
            return nil
        }

        var target = arc.truncatingRemainder(dividingBy: corridor.perimeter)
        if target < 0 { target += corridor.perimeter }

        var traversed: Float = 0
        for index in 0..<points.count {
            let start = points[index]
            let end = points[(index + 1) % points.count]
            let segment = end - start
            let length = simd_length(segment)
            guard length > 0.0001 else { continue }

            if traversed + length >= target {
                let t = (target - traversed) / length
                let point = simd_mix(start, end, SIMD2(repeating: t))
                let tangent = segment / length
                let right = SIMD2(tangent.y, -tangent.x)
                let startHeight = corridor.heights[index]
                let endHeight = corridor.heights[(index + 1) % corridor.heights.count]
                let height = simd_mix(startHeight, endHeight, t)
                return (point, right, height)
            }
            traversed += length
        }

        let tangent = simd_normalize(points[1] - points[0])
        return (points[0], SIMD2(tangent.y, -tangent.x), corridor.heights[0])
    }

    // MARK: - Mesh builders

    private static func addPolylineLoop(
        points: [SIMD2<Float>],
        heights: [Float],
        color: UIColor,
        namePrefix: String,
        to root: Entity
    ) {
        guard points.count >= 2, heights.count == points.count else { return }

        for index in 0..<points.count {
            let start = points[index]
            let end = points[(index + 1) % points.count]
            let startY = heights[index] + surfaceLift
            let endY = heights[(index + 1) % heights.count] + surfaceLift
            let segment = makeSegmentBox(
                from: start,
                to: end,
                y: (startY + endY) / 2,
                color: color
            )
            segment.name = "\(namePrefix)\(index)"
            root.addChild(segment)
        }
    }

    private static func makeSegmentBox(
        from start: SIMD2<Float>,
        to end: SIMD2<Float>,
        y: Float,
        color: UIColor,
        thickness: Float = overlayWidth
    ) -> ModelEntity {
        let midpoint = (start + end) / 2
        let edgeVector = end - start
        let length = max(simd_length(edgeVector), 0.012)
        let yaw = atan2(edgeVector.y, edgeVector.x)

        let entity = makeVisualBox(
            size: SIMD3(length, overlayHeight, thickness),
            color: color,
            position: SIMD3(midpoint.x, y, midpoint.y)
        )
        entity.orientation = simd_quatf(angle: -yaw, axis: SIMD3(0, 1, 0))
        return entity
    }

    private static func makeSpawnMarker(at position: SIMD3<Float>) -> ModelEntity {
        makeVisualBox(
            size: SIMD3(0.035, overlayHeight * 2, 0.06),
            color: .systemGreen,
            position: SIMD3(position.x, position.y + surfaceLift, position.z)
        )
    }

    private static func makeVisualBox(
        size: SIMD3<Float>,
        color: UIColor,
        position: SIMD3<Float>
    ) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: size)
        let material = SimpleMaterial(color: color, roughness: 0.3, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        return entity
    }
}
