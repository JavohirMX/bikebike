//
//  USDZTrackGuideParser.swift
//  bikebike
//

import Foundation
import os
import RealityKit
import simd

struct USDZTrackGuides {
    let centerLine: Entity
    let road: Entity?
    let roadblock: Entity?
    let barrierEntities: [Entity]
    let startFinish: Entity?
}

struct PolylineNearest3D {
    var point3D: SIMD3<Float>
    var pointXZ: SIMD2<Float>
    var tangentXZ: SIMD2<Float>
    var tangent3D: SIMD3<Float>
    var right: SIMD2<Float>
    var arcLength: Float
}

enum USDZTrackGuideParser {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "bikebike",
        category: "USDZTrackGuideParser"
    )

    static let centerLineNames = ["centerline", "center_line"]
    static let roadNames = ["road"]
    static let roadblockNames = ["roadblock", "road_block"]
    static let roadBarrierPrefix = "road_straight_barrier"
    static let startFinishNames = ["startfinish", "start_finish", "finishline", "finish_line"]

    static func parseGuides(in root: Entity) -> USDZTrackGuides? {
        guard let centerLine = findEntity(in: root, matchingAnyOf: centerLineNames) else {
            logger.error("Missing required track guide: centerLine")
            return nil
        }

        let road = findEntity(in: root, matchingAnyOf: roadNames)
        let barrierEntities = findEntities(in: root, matchingPrefix: roadBarrierPrefix)

        guard road != nil || !barrierEntities.isEmpty else {
            logger.error("Missing required track guides: road and/or road_straight_barrier entities")
            return nil
        }

        return USDZTrackGuides(
            centerLine: centerLine,
            road: road,
            roadblock: findEntity(in: root, matchingAnyOf: roadblockNames),
            barrierEntities: barrierEntities,
            startFinish: findEntity(in: root, matchingAnyOf: startFinishNames)
        )
    }

    static func buildGeometry(
        from guides: USDZTrackGuides,
        definition: USDZTrackDefinition,
        relativeTo root: Entity
    ) -> USDZTrackGeometry? {
        guard let centerline3D = RaceTrackCenterlineLoader.loadPoints(baseName: definition.centerlineBaseName) else {
            logger.error("Missing \(definition.centerlineBaseName, privacy: .public).json for authored track path")
            return nil
        }

        let resampled3D = resamplePolyline3D(centerline3D, targetCount: 320)
        let resampledXZ = resampled3D.map { SIMD2($0.x, $0.z) }

        let barrierVertices = guides.barrierEntities.flatMap {
            meshVerticesXZ(in: $0, relativeTo: root)
        }

        let drivableHalfWidth: Float
        if !barrierVertices.isEmpty {
            drivableHalfWidth = estimateHalfWidthFromBarriers(
                centerline: resampledXZ,
                barrierVertices: barrierVertices
            )
        } else if let road = guides.road {
            let roadVertices = meshVerticesXZ(in: road, relativeTo: root)
            drivableHalfWidth = estimateDrivableHalfWidth(
                centerline: resampledXZ,
                roadVertices: roadVertices,
                roadblock: guides.roadblock.map { meshVerticesXZ(in: $0, relativeTo: root) }
            )
        } else {
            drivableHalfWidth = 0.04
        }

        let surfaceY = estimateSurfaceY(
            centerlineEntity: guides.centerLine,
            roadEntity: guides.road,
            barrierEntities: guides.barrierEntities,
            relativeTo: root
        )

        let finishArcLength: Float
        if let startFinish = guides.startFinish {
            let finishPosition = startFinish.position(relativeTo: root)
            finishArcLength = nearestOnPolyline3D(
                resampled3D,
                to: finishPosition,
                hintArcLength: nil,
                perimeter: polylinePerimeter(resampled3D)
            ).arcLength
        } else {
            finishArcLength = 0
        }

        guard let layout = SampledCenterlineLayout(
            presetId: definition.id,
            displayName: definition.title,
            points3D: resampled3D,
            drivableHalfWidth: drivableHalfWidth,
            surfaceY: surfaceY,
            finishArcLength: finishArcLength,
            carSize: SIMD3<Float>(0.04, 0.016, 0.065)
        ) else {
            return nil
        }

        logger.info(
            "Built sampled track from curve JSON: \(resampled3D.count, privacy: .public) points, width \(drivableHalfWidth, privacy: .public), surfaceY \(surfaceY, privacy: .public), finish \(finishArcLength, privacy: .public)"
        )
        return USDZTrackGeometry(sampled: layout)
    }

    static func hideCenterLine(in root: Entity) {
        if let centerLine = findEntity(in: root, matchingAnyOf: centerLineNames) {
            centerLine.isEnabled = false
        }
    }

    static func trackRelevantBounds(in root: Entity) -> BoundingBox? {
        let entities = trackRelevantEntities(in: root)
        guard let first = entities.first else { return nil }

        var combined = first.visualBounds(relativeTo: root)
        for entity in entities.dropFirst() {
            combined = combined.union(entity.visualBounds(relativeTo: root))
        }
        return combined
    }

    // MARK: - Entity lookup

    private static func isTrackRelevantEntityName(_ name: String) -> Bool {
        let lowered = name.lowercased()
        if centerLineNames.contains(lowered)
            || roadNames.contains(lowered)
            || roadblockNames.contains(lowered)
            || startFinishNames.contains(lowered) {
            return true
        }
        return lowered.hasPrefix(roadBarrierPrefix) || lowered.hasPrefix("road_")
    }

    private static func trackRelevantEntities(in root: Entity) -> [Entity] {
        var results: [Entity] = []
        collectEntities(in: root) { name, entity in
            guard isTrackRelevantEntityName(name) else { return }
            if entity is ModelEntity || !entity.children.isEmpty {
                results.append(entity)
            }
        }
        return results
    }

    static func findEntity(in root: Entity, matchingAnyOf names: [String]) -> Entity? {
        let lowered = Set(names.map { $0.lowercased() })
        return findEntity(in: root) { lowered.contains($0.lowercased()) }
    }

    private static func findEntity(in root: Entity, where matches: (String) -> Bool) -> Entity? {
        if matches(root.name) { return root }
        for child in root.children {
            if let found = findEntity(in: child, where: matches) {
                return found
            }
        }
        return nil
    }

    private static func findEntities(in root: Entity, matchingPrefix prefix: String) -> [Entity] {
        let loweredPrefix = prefix.lowercased()
        var results: [Entity] = []
        collectEntities(in: root) { name, entity in
            if name.lowercased().hasPrefix(loweredPrefix) {
                results.append(entity)
            }
        }
        return results
    }

    private static func collectEntities(
        in root: Entity,
        visitor: (String, Entity) -> Void
    ) {
        if !root.name.isEmpty {
            visitor(root.name, root)
        }
        for child in root.children {
            collectEntities(in: child, visitor: visitor)
        }
    }

    // MARK: - Mesh extraction

    private static func meshVerticesXZ(in entity: Entity, relativeTo root: Entity) -> [SIMD2<Float>] {
        var result: [SIMD2<Float>] = []
        collectMeshVertices(in: entity, relativeTo: root) { position in
            result.append(SIMD2(position.x, position.z))
        }
        return dedupePoints(result, tolerance: 0.002)
    }

    private static func collectMeshVertices(
        in entity: Entity,
        relativeTo root: Entity,
        visitor: (SIMD3<Float>) -> Void
    ) {
        if let modelEntity = entity as? ModelEntity,
           let mesh = modelEntity.model?.mesh,
           let positions = meshVertexPositions(from: mesh) {
            for local in positions {
                let world = modelEntity.convert(position: local, to: root)
                visitor(world)
            }
        }

        for child in entity.children {
            collectMeshVertices(in: child, relativeTo: root, visitor: visitor)
        }
    }

    private static func meshVertexPositions(from mesh: MeshResource) -> [SIMD3<Float>]? {
        let contents = mesh.contents
        var positions: [SIMD3<Float>] = []
        for model in contents.models {
            for part in model.parts {
                appendPositions(from: part.positions, into: &positions)
            }
        }
        return positions.isEmpty ? nil : positions
    }

    private static func appendPositions(
        from buffer: MeshBuffer<SIMD3<Float>>,
        into positions: inout [SIMD3<Float>]
    ) {
        guard !buffer.elements.isEmpty else { return }
        positions.reserveCapacity(positions.count + buffer.elements.count)
        positions.append(contentsOf: buffer.elements)
    }

    private static func entityCenterXZ(_ entity: Entity, relativeTo root: Entity) -> SIMD2<Float> {
        let center = entity.position(relativeTo: root)
        return SIMD2(center.x, center.z)
    }

    private static func estimateSurfaceY(
        centerlineEntity: Entity,
        roadEntity: Entity?,
        barrierEntities: [Entity],
        relativeTo root: Entity
    ) -> Float {
        var ys: [Float] = []
        collectMeshVertices(in: centerlineEntity, relativeTo: root) { ys.append($0.y) }
        if let roadEntity = roadEntity {
            collectMeshVertices(in: roadEntity, relativeTo: root) { ys.append($0.y) }
        }
        for barrier in barrierEntities {
            collectMeshVertices(in: barrier, relativeTo: root) { ys.append($0.y) }
        }
        guard !ys.isEmpty else { return 0.03 }

        let sorted = ys.sorted()
        let median = sorted[sorted.count / 2]
        return max(0.01, median)
    }

    private static func estimateHalfWidthFromBarriers(
        centerline: [SIMD2<Float>],
        barrierVertices: [SIMD2<Float>]
    ) -> Float {
        guard !barrierVertices.isEmpty else { return 0.04 }

        var laterals: [Float] = []
        laterals.reserveCapacity(barrierVertices.count)

        for vertex in barrierVertices {
            let nearest = nearestOnPolyline(centerline, to: vertex)
            let lateral = abs(simd_dot(vertex - nearest.point, nearest.right))
            laterals.append(lateral)
        }

        laterals.sort()
        let percentileIndex = min(laterals.count - 1, Int(Float(laterals.count) * 0.92))
        let halfWidth = laterals[percentileIndex]
        return max(0.02, halfWidth - 0.012)
    }

    // MARK: - Centerline ordering

    private static func orderCenterlinePoints(
        _ points: [SIMD2<Float>],
        startNear hint: SIMD2<Float>?
    ) -> [SIMD2<Float>]? {
        guard points.count >= 3 else { return nil }

        let startIndex: Int
        if let hint {
            startIndex = points.enumerated().min(by: {
                simd_length_squared($0.element - hint) < simd_length_squared($1.element - hint)
            })?.offset ?? 0
        } else {
            startIndex = points.enumerated().min(by: { $0.element.x < $1.element.x })?.offset ?? 0
        }

        var remaining = Set(points.indices)
        var ordered: [SIMD2<Float>] = [points[startIndex]]
        remaining.remove(startIndex)

        while let last = ordered.last, !remaining.isEmpty {
            let nextIndex = remaining.min(by: {
                simd_length_squared(points[$0] - last) < simd_length_squared(points[$1] - last)
            })!
            let step = simd_length(points[nextIndex] - last)
            if step > maxStepDistance(in: points) { break }
            ordered.append(points[nextIndex])
            remaining.remove(nextIndex)
        }

        guard ordered.count >= 8 else { return nil }
        return ordered
    }

    private static func resamplePolyline(_ points: [SIMD2<Float>], targetCount: Int) -> [SIMD2<Float>] {
        guard points.count >= 2, targetCount >= 2 else { return points }

        var cumulative: [Float] = [0]
        var total: Float = 0
        for index in 0..<points.count {
            let next = points[(index + 1) % points.count]
            let segment = simd_length(next - points[index])
            total += segment
            cumulative.append(total)
        }

        guard total > 0.001 else { return points }

        var resampled: [SIMD2<Float>] = []
        resampled.reserveCapacity(targetCount)

        for sampleIndex in 0..<targetCount {
            let targetDistance = (Float(sampleIndex) / Float(targetCount)) * total
            var segmentIndex = 0
            while segmentIndex < points.count,
                  cumulative[segmentIndex + 1] < targetDistance {
                segmentIndex += 1
            }

            let segmentStart = cumulative[segmentIndex]
            let segmentEnd = cumulative[segmentIndex + 1]
            let t = segmentEnd > segmentStart
                ? (targetDistance - segmentStart) / (segmentEnd - segmentStart)
                : 0
            let a = points[segmentIndex]
            let b = points[(segmentIndex + 1) % points.count]
            resampled.append(simd_mix(a, b, SIMD2(repeating: t)))
        }

        return resampled
    }

    private static func arcLength(on polyline: [SIMD3<Float>], nearestTo point: SIMD2<Float>) -> Float {
        let query = SIMD3(point.x, polyline.first?.y ?? 0, point.y)
        return nearestOnPolyline3D(polyline, to: query, hintArcLength: nil, perimeter: polylinePerimeter(polyline)).arcLength
    }

    private static func polylinePerimeter(_ polyline: [SIMD3<Float>]) -> Float {
        guard polyline.count >= 2 else { return 0 }
        var total: Float = 0
        for index in 0..<polyline.count {
            let next = polyline[(index + 1) % polyline.count]
            total += simd_length(next - polyline[index])
        }
        return total
    }

    private static func resamplePolyline3D(_ points: [SIMD3<Float>], targetCount: Int) -> [SIMD3<Float>] {
        guard points.count >= 2, targetCount >= 2 else { return points }

        var cumulative: [Float] = [0]
        var total: Float = 0
        for index in 0..<points.count {
            let next = points[(index + 1) % points.count]
            let segment = simd_length(next - points[index])
            total += segment
            cumulative.append(total)
        }

        guard total > 0.001 else { return points }

        var resampled: [SIMD3<Float>] = []
        resampled.reserveCapacity(targetCount)

        for sampleIndex in 0..<targetCount {
            let targetDistance = (Float(sampleIndex) / Float(targetCount)) * total
            var segmentIndex = 0
            while segmentIndex < points.count,
                  cumulative[segmentIndex + 1] < targetDistance {
                segmentIndex += 1
            }

            let segmentStart = cumulative[segmentIndex]
            let segmentEnd = cumulative[segmentIndex + 1]
            let t = segmentEnd > segmentStart
                ? (targetDistance - segmentStart) / (segmentEnd - segmentStart)
                : 0
            let a = points[segmentIndex]
            let b = points[(segmentIndex + 1) % points.count]
            resampled.append(simd_mix(a, b, SIMD3(repeating: t)))
        }

        return resampled
    }

    static func nearestOnPolyline3D(
        _ polyline: [SIMD3<Float>],
        to query: SIMD3<Float>,
        hintArcLength: Float?,
        perimeter: Float
    ) -> PolylineNearest3D {
        struct Candidate {
            var point3D: SIMD3<Float>
            var pointXZ: SIMD2<Float>
            var tangentXZ: SIMD2<Float>
            var tangent3D: SIMD3<Float>
            var arcLength: Float
            var distanceSquared: Float
        }

        var candidates: [Candidate] = []
        var traversed: Float = 0

        for index in 0..<polyline.count {
            let start = polyline[index]
            let end = polyline[(index + 1) % polyline.count]
            let segment3D = end - start
            let length = simd_length(segment3D)
            guard length > 0.0001 else { continue }

            let t = max(0, min(1, simd_dot(query - start, segment3D) / (length * length)))
            let projected = start + segment3D * t
            let tangent3D = segment3D / length
            let segmentXZ = SIMD2(end.x - start.x, end.z - start.z)
            let xzLength = simd_length(segmentXZ)
            let tangentXZ = xzLength > 0.0001 ? segmentXZ / xzLength : SIMD2<Float>(1, 0)

            candidates.append(
                Candidate(
                    point3D: projected,
                    pointXZ: SIMD2(projected.x, projected.z),
                    tangentXZ: tangentXZ,
                    tangent3D: tangent3D,
                    arcLength: traversed + length * t,
                    distanceSquared: simd_length_squared(projected - query)
                )
            )
            traversed += length
        }

        guard !candidates.isEmpty else {
            return PolylineNearest3D(
                point3D: query,
                pointXZ: SIMD2(query.x, query.z),
                tangentXZ: SIMD2(1, 0),
                tangent3D: SIMD3(0, 0, -1),
                right: SIMD2(0, -1),
                arcLength: 0
            )
        }

        let bestDistance = candidates.map(\.distanceSquared).min() ?? .infinity
        let closeCandidates = candidates.filter { $0.distanceSquared <= bestDistance * 1.35 + 0.0001 }

        let chosen: Candidate
        if let hintArcLength, closeCandidates.count > 1 {
            let hinted = closeCandidates.min(by: {
                arcDistance($0.arcLength, hintArcLength, perimeter: perimeter) <
                    arcDistance($1.arcLength, hintArcLength, perimeter: perimeter)
            }) ?? closeCandidates[0]
            let window = perimeter * 0.15
            if arcDistance(hinted.arcLength, hintArcLength, perimeter: perimeter) <= window {
                chosen = hinted
            } else if let nearest = candidates.min(by: { $0.distanceSquared < $1.distanceSquared }) {
                chosen = nearest
            } else {
                chosen = hinted
            }
        } else if let nearest = candidates.min(by: { $0.distanceSquared < $1.distanceSquared }) {
            chosen = nearest
        } else {
            chosen = candidates[0]
        }

        let right = SIMD2(chosen.tangentXZ.y, -chosen.tangentXZ.x)
        return PolylineNearest3D(
            point3D: chosen.point3D,
            pointXZ: chosen.pointXZ,
            tangentXZ: chosen.tangentXZ,
            tangent3D: chosen.tangent3D,
            right: right,
            arcLength: chosen.arcLength
        )
    }

    private static func arcDistance(_ a: Float, _ b: Float, perimeter: Float) -> Float {
        let delta = abs(a - b)
        return min(delta, max(perimeter - delta, 0))
    }

    private static func arcLength(on polyline: [SIMD2<Float>], nearestTo point: SIMD2<Float>) -> Float {
        let nearest = nearestOnPolyline(polyline, to: point)
        return nearest.arcLength
    }

    private static func estimateDrivableHalfWidth(
        centerline: [SIMD2<Float>],
        roadVertices: [SIMD2<Float>],
        roadblock: [SIMD2<Float>]?
    ) -> Float {
        guard !roadVertices.isEmpty else { return 0.04 }

        var laterals: [Float] = []
        laterals.reserveCapacity(roadVertices.count)

        for vertex in roadVertices {
            let nearest = nearestOnPolyline(centerline, to: vertex)
            let lateral = abs(simd_dot(vertex - nearest.point, nearest.right))
            laterals.append(lateral)
        }

        laterals.sort()
        let percentileIndex = min(laterals.count - 1, Int(Float(laterals.count) * 0.92))
        var halfWidth = laterals[percentileIndex]

        if let roadblock {
            var blockLaterals: [Float] = []
            for vertex in roadblock {
                let nearest = nearestOnPolyline(centerline, to: vertex)
                let lateral = abs(simd_dot(vertex - nearest.point, nearest.right))
                blockLaterals.append(lateral)
            }
            if let minBlock = blockLaterals.min() {
                halfWidth = min(halfWidth, minBlock * 0.95)
            }
        }

        return max(0.02, halfWidth - 0.012)
    }

    static func nearestOnPolyline(
        _ polyline: [SIMD2<Float>],
        to query: SIMD2<Float>
    ) -> (point: SIMD2<Float>, tangent: SIMD2<Float>, right: SIMD2<Float>, arcLength: Float) {
        var bestPoint = polyline[0]
        var bestTangent = SIMD2<Float>(1, 0)
        var bestArc: Float = 0
        var bestDistSq = Float.infinity

        var traversed: Float = 0
        for index in 0..<polyline.count {
            let start = polyline[index]
            let end = polyline[(index + 1) % polyline.count]
            let segment = end - start
            let length = simd_length(segment)
            guard length > 0.0001 else { continue }

            let t = max(0, min(1, simd_dot(query - start, segment) / (length * length)))
            let projected = start + segment * t
            let distSq = simd_length_squared(projected - query)
            if distSq < bestDistSq {
                bestDistSq = distSq
                bestPoint = projected
                bestTangent = segment / length
                bestArc = traversed + length * t
            }
            traversed += length
        }

        let right = SIMD2(bestTangent.y, -bestTangent.x)
        return (bestPoint, bestTangent, right, bestArc)
    }

    private static func maxStepDistance(in points: [SIMD2<Float>]) -> Float {
        guard points.count >= 2 else { return 0.5 }
        var distances: [Float] = []
        for index in 0..<min(points.count, 64) {
            let pivot = points[index]
            let nearest = points.enumerated()
                .filter { $0.offset != index }
                .min(by: { simd_length_squared($0.element - pivot) < simd_length_squared($1.element - pivot) })
            if let nearest {
                distances.append(simd_length(nearest.element - pivot))
            }
        }
        guard distances.indices.contains(distances.count / 2) else { return 0.5 }
        let median = distances.sorted()[distances.count / 2]
        return max(0.08, median * 4)
    }

    private static func dedupePoints(_ points: [SIMD2<Float>], tolerance: Float) -> [SIMD2<Float>] {
        var result: [SIMD2<Float>] = []
        for point in points {
            if result.contains(where: { simd_length_squared($0 - point) < tolerance * tolerance }) {
                continue
            }
            result.append(point)
        }
        return result
    }
}
