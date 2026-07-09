//
//  RaceTrackCatalog.swift
//  bikebike
//

import Foundation
import simd

struct TrackOption: Identifiable, Equatable {
    let id: String
    let title: String
    let shortTitle: String
    let subtitle: String
    let thumbnailAssetName: String
    let previewFootprint: SIMD2<Float>
    let isPrimary: Bool
}

struct USDZTrackDefinition {
    let id: String
    let title: String
    let shortTitle: String
    let subtitle: String
    let thumbnailAssetName: String
    let previewFootprint: SIMD2<Float>
    let modelName: String
    let centerlineBaseName: String
}

struct TrackClampResult {
    var position: SIMD2<Float>
    var hitWall: Bool
}

struct TrackDebugCorridorData {
    let points: [SIMD2<Float>]
    let heights: [Float]
    let halfWidth: Float
    let surfaceY: Float
    let finishArcLength: Float
    let perimeter: Float
}

struct TrackSurfaceFrame {
    var position: SIMD3<Float>
    var tangent: SIMD3<Float>
    var arcLength: Float
}

struct ScoreboardPlacementFrame {
    var position: SIMD3<Float>
    var outward: SIMD3<Float>
}

protocol RaceTrackGeometry {
    var presetId: String { get }
    var displayName: String { get }
    var carSize: SIMD3<Float> { get }
    var surfaceY: Float { get }
    var perimeterLength: Float { get }
    var finishArcLength: Float { get }
    var debugCorridor: TrackDebugCorridorData? { get }

    func spawnTransform(gridIndex: Int) -> (position: SIMD3<Float>, orientationAngle: Float)
    func clampToCorridor(_ localPos: SIMD3<Float>) -> TrackClampResult
    func arcLength(for localPos: SIMD3<Float>, hintArcLength: Float?) -> Float
    func forwardArcDelta(from: Float, to: Float) -> Float
    func surfaceHeight(at localPos: SIMD3<Float>, hintArcLength: Float?) -> Float
    func surfaceFrame(at localPos: SIMD3<Float>, hintArcLength: Float?) -> TrackSurfaceFrame
}

extension RaceTrackGeometry {
    func arcLength(for localPos: SIMD3<Float>) -> Float {
        arcLength(for: localPos, hintArcLength: nil)
    }

    func surfaceHeight(at localPos: SIMD3<Float>) -> Float {
        surfaceHeight(at: localPos, hintArcLength: nil)
    }

    func surfaceFrame(at localPos: SIMD3<Float>) -> TrackSurfaceFrame {
        surfaceFrame(at: localPos, hintArcLength: nil)
    }

    func scoreboardPlacementFrame(panelWidth: Float, scale: Float) -> ScoreboardPlacementFrame {
        let finishCenter = finishLineCenterPosition()
        let frame = surfaceFrame(at: finishCenter, hintArcLength: finishArcLength)

        // Float centered above the start/finish straight like a hovering screen.
        let floatHeight = 0.6 * scale
        let surfaceY = frame.position.y
        let position = SIMD3<Float>(
            frame.position.x,
            surfaceY + floatHeight,
            frame.position.z
        )

        guard position.allFinite else {
            let spawn = spawnTransform(gridIndex: 0)
            let spawnFrame = surfaceFrame(at: spawn.position, hintArcLength: finishArcLength)
            let fallback = SIMD3<Float>(
                spawnFrame.position.x,
                spawnFrame.position.y + floatHeight,
                spawnFrame.position.z
            )
            return ScoreboardPlacementFrame(position: fallback, outward: .zero)
        }

        return ScoreboardPlacementFrame(position: position, outward: .zero)
    }

    private func finishLineCenterPosition() -> SIMD3<Float> {
        let spawn = spawnTransform(gridIndex: 0)
        let clamped = clampToCorridor(spawn.position)
        let y = surfaceHeight(at: spawn.position, hintArcLength: finishArcLength)
        return SIMD3<Float>(clamped.position.x, y, clamped.position.y)
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}

enum RaceTrackCatalog {
    static let usdzTrackId = "racetrack-usdz"
    static let roadTrackId = "road-usdz"
    static let defaultTrackId = roadTrackId

    static let usdzTracks: [USDZTrackDefinition] = [
        USDZTrackDefinition(
            id: usdzTrackId,
            title: "Racetrack",
            shortTitle: "Racetrack",
            subtitle: "Classic circuit track loaded from racetrack.usdz",
            thumbnailAssetName: "racetrack-thumbnail",
            previewFootprint: SIMD2(0.92, 0.58),
            modelName: "racetrack",
            centerlineBaseName: "racetrack_centerline"
        ),
        USDZTrackDefinition(
            id: roadTrackId,
            title: "Sunrise Road",
            shortTitle: "Sunrise Road",
            subtitle: "Featured curved road track loaded from road.usdz",
            thumbnailAssetName: "sunrise-road-thumbnail",
            previewFootprint: SIMD2(1.18, 0.62),
            modelName: "road",
            centerlineBaseName: "road_centerline"
        ),
    ]

    static let allOptions: [TrackOption] = usdzTracks.map {
        TrackOption(
            id: $0.id,
            title: $0.title,
            shortTitle: $0.shortTitle,
            subtitle: $0.subtitle,
            thumbnailAssetName: $0.thumbnailAssetName,
            previewFootprint: $0.previewFootprint,
            isPrimary: $0.id == roadTrackId
        )
    } + [
        TrackOption(
            id: ProceduralTrack.presetId,
            title: "Classic Oval",
            shortTitle: "Classic",
            subtitle: "Secondary procedural fallback track",
            thumbnailAssetName: "classic-oval-thumbnail",
            previewFootprint: SIMD2(0.82, 0.54),
            isPrimary: false
        ),
    ]

    static func usdzTrack(for trackId: String) -> USDZTrackDefinition? {
        usdzTracks.first { $0.id == trackId }
    }

    static func isUSDZTrackId(_ trackId: String) -> Bool {
        usdzTrack(for: trackId) != nil
    }

    static func normalizedTrackId(_ trackId: String) -> String {
        allOptions.contains(where: { $0.id == trackId }) ? trackId : defaultTrackId
    }

    static func option(for trackId: String) -> TrackOption {
        let id = normalizedTrackId(trackId)
        return allOptions.first(where: { $0.id == id }) ?? allOptions[0]
    }
}

private enum TrackAxis {
    case x
    case z
}

struct ProceduralTrackDefinition: RaceTrackGeometry {
    private let layout: OvalTrackLayout

    init() {
        layout = OvalTrackLayout(
            presetId: ProceduralTrack.presetId,
            displayName: "Classic Oval",
            turnRadius: 0.25,
            straightLength: 0.30,
            trackWidth: 0.20,
            surfaceY: 0.03,
            carSize: SIMD3<Float>(0.04, 0.016, 0.065),
            axis: .x
        )
    }

    fileprivate init(layout: OvalTrackLayout) {
        self.layout = layout
    }

    var presetId: String { layout.presetId }
    var displayName: String { layout.displayName }
    var carSize: SIMD3<Float> { layout.carSize }
    var surfaceY: Float { layout.surfaceY }
    var perimeterLength: Float { layout.perimeterLength }
    var finishArcLength: Float { layout.finishArcLength }
    var debugCorridor: TrackDebugCorridorData? { layout.debugCorridor }

    func spawnTransform(gridIndex: Int) -> (position: SIMD3<Float>, orientationAngle: Float) {
        layout.spawnTransform(gridIndex: gridIndex)
    }

    func clampToCorridor(_ localPos: SIMD3<Float>) -> TrackClampResult {
        layout.clampToCorridor(localPos)
    }

    func arcLength(for localPos: SIMD3<Float>, hintArcLength: Float?) -> Float {
        layout.arcLength(for: localPos, hintArcLength: hintArcLength)
    }

    func forwardArcDelta(from: Float, to: Float) -> Float {
        layout.forwardArcDelta(from: from, to: to)
    }

    func surfaceHeight(at localPos: SIMD3<Float>, hintArcLength: Float?) -> Float {
        layout.surfaceHeight(at: localPos, hintArcLength: hintArcLength)
    }

    func surfaceFrame(at localPos: SIMD3<Float>, hintArcLength: Float?) -> TrackSurfaceFrame {
        layout.surfaceFrame(at: localPos, hintArcLength: hintArcLength)
    }

    func scaled(by scale: Float) -> ProceduralTrackDefinition {
        guard abs(scale - 1) > 0.0001 else { return self }
        return ProceduralTrackDefinition(layout: layout.scaled(by: scale))
    }
}

struct USDZTrackGeometry: RaceTrackGeometry {
    private enum Backend {
        case sampled(SampledCenterlineLayout)
        case oval(OvalTrackLayout)
    }

    private let backend: Backend

    init?(footprint: SIMD2<Float>, presetId: String, displayName: String) {
        let longAxis = max(footprint.x, footprint.y)
        let shortAxis = min(footprint.x, footprint.y)
        guard longAxis > 0.2, shortAxis > 0.1 else { return nil }

        let axis: TrackAxis = footprint.x >= footprint.y ? .x : .z
        let trackWidth = min(shortAxis * 0.35, shortAxis * 0.60)
        let outerRadius = shortAxis / 2
        let turnRadius = max(0.06, outerRadius - trackWidth / 2)
        let straightLength = max(0.06, longAxis - 2 * outerRadius)

        backend = .oval(OvalTrackLayout(
            presetId: presetId,
            displayName: displayName,
            turnRadius: turnRadius,
            straightLength: straightLength,
            trackWidth: max(0.06, trackWidth),
            surfaceY: 0.03,
            carSize: SIMD3<Float>(0.04, 0.016, 0.065),
            axis: axis
        ))
    }

    init(sampled layout: SampledCenterlineLayout) {
        backend = .sampled(layout)
    }

    var presetId: String {
        switch backend {
        case .sampled(let layout): layout.presetId
        case .oval(let layout): layout.presetId
        }
    }

    var displayName: String {
        switch backend {
        case .sampled(let layout): layout.displayName
        case .oval(let layout): layout.displayName
        }
    }

    var carSize: SIMD3<Float> {
        switch backend {
        case .sampled(let layout): layout.carSize
        case .oval(let layout): layout.carSize
        }
    }

    var surfaceY: Float {
        switch backend {
        case .sampled(let layout): layout.surfaceY
        case .oval(let layout): layout.surfaceY
        }
    }

    var perimeterLength: Float {
        switch backend {
        case .sampled(let layout): layout.perimeterLength
        case .oval(let layout): layout.perimeterLength
        }
    }

    var finishArcLength: Float {
        switch backend {
        case .sampled(let layout): layout.finishArcLength
        case .oval(let layout): layout.finishArcLength
        }
    }

    var debugCorridor: TrackDebugCorridorData? {
        switch backend {
        case .sampled(let layout): layout.debugCorridor
        case .oval(let layout): layout.debugCorridor
        }
    }

    func spawnTransform(gridIndex: Int) -> (position: SIMD3<Float>, orientationAngle: Float) {
        switch backend {
        case .sampled(let layout): layout.spawnTransform(gridIndex: gridIndex)
        case .oval(let layout): layout.spawnTransform(gridIndex: gridIndex)
        }
    }

    func clampToCorridor(_ localPos: SIMD3<Float>) -> TrackClampResult {
        switch backend {
        case .sampled(let layout): layout.clampToCorridor(localPos)
        case .oval(let layout): layout.clampToCorridor(localPos)
        }
    }

    func arcLength(for localPos: SIMD3<Float>, hintArcLength: Float?) -> Float {
        switch backend {
        case .sampled(let layout): layout.arcLength(for: localPos, hintArcLength: hintArcLength)
        case .oval(let layout): layout.arcLength(for: localPos, hintArcLength: hintArcLength)
        }
    }

    func forwardArcDelta(from: Float, to: Float) -> Float {
        switch backend {
        case .sampled(let layout): layout.forwardArcDelta(from: from, to: to)
        case .oval(let layout): layout.forwardArcDelta(from: from, to: to)
        }
    }

    func surfaceHeight(at localPos: SIMD3<Float>, hintArcLength: Float?) -> Float {
        switch backend {
        case .sampled(let layout): layout.surfaceHeight(at: localPos, hintArcLength: hintArcLength)
        case .oval(let layout): layout.surfaceHeight(at: localPos, hintArcLength: hintArcLength)
        }
    }

    func surfaceFrame(at localPos: SIMD3<Float>, hintArcLength: Float?) -> TrackSurfaceFrame {
        switch backend {
        case .sampled(let layout): layout.surfaceFrame(at: localPos, hintArcLength: hintArcLength)
        case .oval(let layout): layout.surfaceFrame(at: localPos, hintArcLength: hintArcLength)
        }
    }

    func scaled(by scale: Float) -> USDZTrackGeometry {
        guard abs(scale - 1) > 0.0001 else { return self }
        switch backend {
        case .sampled(let layout):
            if let scaled = layout.scaled(by: scale) {
                return USDZTrackGeometry(sampled: scaled)
            }
            return self
        case .oval(let layout):
            return USDZTrackGeometry(oval: layout.scaled(by: scale))
        }
    }

    private init(oval layout: OvalTrackLayout) {
        backend = .oval(layout)
    }
}

struct SampledCenterlineLayout: RaceTrackGeometry {
    let presetId: String
    let displayName: String
    let points3D: [SIMD3<Float>]
    let points: [SIMD2<Float>]
    let perimeter: Float
    let drivableHalfWidth: Float
    let surfaceY: Float
    let finishArcLength: Float
    let carSize: SIMD3<Float>

    var perimeterLength: Float { perimeter }

    var debugCorridor: TrackDebugCorridorData? {
        TrackDebugCorridorData(
            points: points,
            heights: points3D.map(\.y),
            halfWidth: drivableHalfWidth,
            surfaceY: surfaceY,
            finishArcLength: finishArcLength,
            perimeter: perimeter
        )
    }

    private var carHalfExtents: SIMD3<Float> { carSize / 2 }

    init?(
        presetId: String,
        displayName: String,
        points3D: [SIMD3<Float>],
        drivableHalfWidth: Float,
        surfaceY: Float,
        finishArcLength: Float,
        carSize: SIMD3<Float>
    ) {
        guard points3D.count >= 8 else { return nil }

        var total: Float = 0
        for index in 0..<points3D.count {
            let next = points3D[(index + 1) % points3D.count]
            total += simd_length(next - points3D[index])
        }
        guard total > 0.05 else { return nil }

        let carHalf = carSize / 2
        self.presetId = presetId
        self.displayName = displayName
        self.points3D = points3D
        self.points = points3D.map { SIMD2($0.x, $0.z) }
        self.perimeter = total
        self.drivableHalfWidth = max(0.02, drivableHalfWidth - max(carHalf.x, carHalf.z))
        self.surfaceY = surfaceY
        self.finishArcLength = finishArcLength.truncatingRemainder(dividingBy: total)
        self.carSize = carSize
    }

    func spawnTransform(gridIndex: Int) -> (position: SIMD3<Float>, orientationAngle: Float) {
        let laneSpacing = max(carSize.x, carSize.z) * 0.9
        let lateralOffset = (Float(gridIndex) - 0.5) * laneSpacing
        let spawnArc = wrappedArc(finishArcLength - perimeter * 0.035)
        let frame = frame3D(atArcLength: spawnArc)
        let spawnPoint = frame.point3D + SIMD3(frame.right.x, 0, frame.right.y) * lateralOffset
        let orientationAngle = atan2(-frame.tangent.x, -frame.tangent.y)

        return (spawnPoint, orientationAngle)
    }

    func clampToCorridor(_ localPos: SIMD3<Float>) -> TrackClampResult {
        let nearest = USDZTrackGuideParser.nearestOnPolyline3D(
            points3D,
            to: localPos,
            hintArcLength: nil,
            perimeter: perimeter
        )
        let query = SIMD2(localPos.x, localPos.z)
        let lateral = simd_dot(query - nearest.pointXZ, nearest.right)
        let clampedLateral = min(drivableHalfWidth, max(-drivableHalfWidth, lateral))
        let hitWall = abs(lateral - clampedLateral) > 0.0005
        let clamped = nearest.pointXZ + nearest.right * clampedLateral
        return TrackClampResult(position: clamped, hitWall: hitWall)
    }

    func surfaceFrame(at localPos: SIMD3<Float>, hintArcLength: Float?) -> TrackSurfaceFrame {
        let nearest = USDZTrackGuideParser.nearestOnPolyline3D(
            points3D,
            to: localPos,
            hintArcLength: hintArcLength,
            perimeter: perimeter
        )
        return TrackSurfaceFrame(
            position: nearest.point3D,
            tangent: nearest.tangent3D,
            arcLength: nearest.arcLength
        )
    }

    func arcLength(for localPos: SIMD3<Float>, hintArcLength: Float?) -> Float {
        USDZTrackGuideParser.nearestOnPolyline3D(
            points3D,
            to: localPos,
            hintArcLength: hintArcLength,
            perimeter: perimeter
        ).arcLength
    }

    func surfaceHeight(at localPos: SIMD3<Float>, hintArcLength: Float?) -> Float {
        USDZTrackGuideParser.nearestOnPolyline3D(
            points3D,
            to: localPos,
            hintArcLength: hintArcLength,
            perimeter: perimeter
        ).point3D.y
    }

    func forwardArcDelta(from: Float, to: Float) -> Float {
        let delta = to - from
        return delta >= 0 ? delta : delta + perimeter
    }

    private func wrappedArc(_ arc: Float) -> Float {
        var value = arc.truncatingRemainder(dividingBy: perimeter)
        if value < 0 { value += perimeter }
        return value
    }

    private func frame3D(atArcLength arc: Float) -> (
        point3D: SIMD3<Float>,
        tangent: SIMD2<Float>,
        right: SIMD2<Float>
    ) {
        let target = wrappedArc(arc)
        var traversed: Float = 0

        for index in 0..<points3D.count {
            let start = points3D[index]
            let end = points3D[(index + 1) % points3D.count]
            let segment3D = end - start
            let length = simd_length(segment3D)
            guard length > 0.0001 else { continue }

            if traversed + length >= target {
                let t = (target - traversed) / length
                let point3D = simd_mix(start, end, SIMD3(repeating: t))
                let segmentXZ = SIMD2(end.x - start.x, end.z - start.z)
                let tangent = simd_normalize(segmentXZ)
                let right = SIMD2(tangent.y, -tangent.x)
                return (point3D, tangent, right)
            }
            traversed += length
        }

        let tangent = simd_normalize(points[1] - points[0])
        return (points3D[0], tangent, SIMD2(tangent.y, -tangent.x))
    }

    func scaled(by scale: Float) -> SampledCenterlineLayout? {
        guard abs(scale - 1) > 0.0001 else { return self }

        let carHalf = carSize / 2
        let rawHalfWidth = drivableHalfWidth + max(carHalf.x, carHalf.z)
        return SampledCenterlineLayout(
            presetId: presetId,
            displayName: displayName,
            points3D: points3D.map { $0 * scale },
            drivableHalfWidth: rawHalfWidth * scale,
            surfaceY: surfaceY * scale,
            finishArcLength: finishArcLength * scale,
            carSize: carSize * scale
        )
    }
}

private struct OvalTrackLayout: RaceTrackGeometry {
    let presetId: String
    let displayName: String
    let turnRadius: Float
    let straightLength: Float
    let trackWidth: Float
    let surfaceY: Float
    let carSize: SIMD3<Float>
    let axis: TrackAxis

    var carHalfExtents: SIMD3<Float> { carSize / 2 }
    var trackHalfWidth: Float { trackWidth / 2 }
    var finishLineParameter: Float { (straightLength / 2) / perimeter }
    var finishArcLength: Float { finishLineParameter * perimeter }
    var perimeterLength: Float { perimeter }

    private var halfStraight: Float { straightLength / 2 }
    private var semicircleLength: Float { .pi * turnRadius }
    private var perimeter: Float { 2 * straightLength + 2 * semicircleLength }
    private var drivableHalfWidth: Float {
        max(0.02, trackWidth / 2 - max(carHalfExtents.x, carHalfExtents.z))
    }

    var debugCorridor: TrackDebugCorridorData? {
        let sampleCount = 64
        var sampledPoints: [SIMD2<Float>] = []
        sampledPoints.reserveCapacity(sampleCount)
        for index in 0..<sampleCount {
            let t = Float(index) / Float(sampleCount)
            sampledPoints.append(inversePoint(centerlinePoint(t: t)))
        }
        return TrackDebugCorridorData(
            points: sampledPoints,
            heights: Array(repeating: surfaceY, count: sampleCount),
            halfWidth: drivableHalfWidth,
            surfaceY: surfaceY,
            finishArcLength: finishArcLength,
            perimeter: perimeter
        )
    }

    func spawnTransform(gridIndex: Int) -> (position: SIMD3<Float>, orientationAngle: Float) {
        let laneSpacing = max(carSize.x, carSize.z) * 0.9
        let lateralOffset = (Float(gridIndex) - 0.5) * laneSpacing
        let spawnT = max(0, finishLineParameter - 0.035)
        let tangent = centerlineTangent(t: spawnT)
        let right = centerlineRight(t: spawnT)
        let spawnPoint = centerlinePoint(t: spawnT) + right * lateralOffset
        let localPoint = inversePoint(spawnPoint)
        let localTangent = inverseVector(tangent)
        let orientationAngle = atan2(-localTangent.x, -localTangent.y)

        return (
            SIMD3(localPoint.x, surfaceY, localPoint.y),
            orientationAngle
        )
    }

    func clampToCorridor(_ localPos: SIMD3<Float>) -> TrackClampResult {
        let point = canonicalPoint(from: localPos)
        let nearest = nearestCenterline(to: point)
        let lateral = simd_dot(point - nearest.point, nearest.right)
        let clampedLateral = min(drivableHalfWidth, max(-drivableHalfWidth, lateral))
        let hitWall = abs(lateral - clampedLateral) > 0.0005
        let clamped = nearest.point + nearest.right * clampedLateral
        return TrackClampResult(position: inversePoint(clamped), hitWall: hitWall)
    }

    func arcLength(for localPos: SIMD3<Float>, hintArcLength: Float?) -> Float {
        _ = hintArcLength
        return nearestCenterline(to: canonicalPoint(from: localPos)).parameter * perimeter
    }

    func surfaceHeight(at localPos: SIMD3<Float>, hintArcLength: Float?) -> Float {
        surfaceFrame(at: localPos, hintArcLength: hintArcLength).position.y
    }

    func surfaceFrame(at localPos: SIMD3<Float>, hintArcLength: Float?) -> TrackSurfaceFrame {
        _ = hintArcLength
        let point = canonicalPoint(from: localPos)
        let nearest = nearestCenterline(to: point)
        let localTangent = inverseVector(centerlineTangent(t: nearest.parameter))
        let tangentXZ = simd_length_squared(localTangent) > 0.0001 ? simd_normalize(localTangent) : SIMD2(1, 0)
        let tangent3D = SIMD3(tangentXZ.x, 0, tangentXZ.y)
        return TrackSurfaceFrame(
            position: SIMD3(localPos.x, surfaceY, localPos.z),
            tangent: tangent3D,
            arcLength: nearest.parameter * perimeter
        )
    }

    func forwardArcDelta(from: Float, to: Float) -> Float {
        let delta = to - from
        return delta >= 0 ? delta : delta + perimeter
    }

    func scaled(by scale: Float) -> OvalTrackLayout {
        guard abs(scale - 1) > 0.0001 else { return self }
        return OvalTrackLayout(
            presetId: presetId,
            displayName: displayName,
            turnRadius: turnRadius * scale,
            straightLength: straightLength * scale,
            trackWidth: trackWidth * scale,
            surfaceY: surfaceY * scale,
            carSize: carSize * scale,
            axis: axis
        )
    }

    private func canonicalPoint(from localPos: SIMD3<Float>) -> SIMD2<Float> {
        canonicalPoint(from: SIMD2(localPos.x, localPos.z))
    }

    private func canonicalPoint(from localXZ: SIMD2<Float>) -> SIMD2<Float> {
        switch axis {
        case .x:
            return localXZ
        case .z:
            return SIMD2(localXZ.y, -localXZ.x)
        }
    }

    private func inversePoint(_ canonicalPoint: SIMD2<Float>) -> SIMD2<Float> {
        switch axis {
        case .x:
            return canonicalPoint
        case .z:
            return SIMD2(-canonicalPoint.y, canonicalPoint.x)
        }
    }

    private func inverseVector(_ canonicalVector: SIMD2<Float>) -> SIMD2<Float> {
        inversePoint(canonicalVector)
    }

    private func centerlinePoint(t: Float) -> SIMD2<Float> {
        let wrapped = t - floor(t)
        return centerlinePoint(distance: wrapped * perimeter)
    }

    private func centerlineTangent(t: Float) -> SIMD2<Float> {
        let epsilon: Float = 0.002
        let p0 = centerlinePoint(t: t)
        let p1 = centerlinePoint(t: t + epsilon)
        let delta = p1 - p0
        let len = simd_length(delta)
        guard len > 0.0001 else { return SIMD2(1, 0) }
        return delta / len
    }

    private func centerlineRight(t: Float) -> SIMD2<Float> {
        let tangent = centerlineTangent(t: t)
        return SIMD2(tangent.y, -tangent.x)
    }

    private func centerlinePoint(distance: Float) -> SIMD2<Float> {
        var d = distance.truncatingRemainder(dividingBy: perimeter)
        if d < 0 { d += perimeter }

        if d < straightLength {
            let x = halfStraight - d
            return SIMD2(x, -turnRadius)
        }
        d -= straightLength

        if d < semicircleLength {
            let angle = -.pi / 2 - (d / turnRadius)
            return SIMD2(-halfStraight + turnRadius * cos(angle), turnRadius * sin(angle))
        }
        d -= semicircleLength

        if d < straightLength {
            let x = -halfStraight + d
            return SIMD2(x, turnRadius)
        }
        d -= straightLength

        let angle = .pi / 2 - (d / turnRadius)
        return SIMD2(halfStraight + turnRadius * cos(angle), turnRadius * sin(angle))
    }

    private struct NearestCenterline {
        var point: SIMD2<Float>
        var right: SIMD2<Float>
        var parameter: Float
        var distanceSquared: Float
    }

    private func nearestCenterline(to point: SIMD2<Float>) -> NearestCenterline {
        var best = NearestCenterline(
            point: centerlinePoint(t: 0),
            right: centerlineRight(t: 0),
            parameter: 0,
            distanceSquared: .infinity
        )

        let samples = 96
        for index in 0..<samples {
            let t = Float(index) / Float(samples)
            let candidate = centerlinePoint(t: t)
            let distSq = simd_length_squared(candidate - point)
            if distSq < best.distanceSquared {
                best = NearestCenterline(
                    point: candidate,
                    right: centerlineRight(t: t),
                    parameter: t,
                    distanceSquared: distSq
                )
            }
        }

        refineNearest(onBottomStraight: point, best: &best)
        refineNearest(onTopStraight: point, best: &best)
        refineNearest(onLeftArc: point, best: &best)
        refineNearest(onRightArc: point, best: &best)

        return best
    }

    private func parameter(onBottomStraight x: Float) -> Float {
        (halfStraight - x) / perimeter
    }

    private func parameter(onTopStraight x: Float) -> Float {
        (straightLength + semicircleLength + (x + halfStraight)) / perimeter
    }

    private func refineNearest(onBottomStraight point: SIMD2<Float>, best: inout NearestCenterline) {
        let x = min(halfStraight, max(-halfStraight, point.x))
        updateBest(candidate: SIMD2(x, -turnRadius), parameter: parameter(onBottomStraight: x), point: point, best: &best)
    }

    private func refineNearest(onTopStraight point: SIMD2<Float>, best: inout NearestCenterline) {
        let x = min(halfStraight, max(-halfStraight, point.x))
        updateBest(candidate: SIMD2(x, turnRadius), parameter: parameter(onTopStraight: x), point: point, best: &best)
    }

    private func refineNearest(onLeftArc point: SIMD2<Float>, best: inout NearestCenterline) {
        let center = SIMD2(-halfStraight, 0)
        let delta = point - center
        let angle = atan2(delta.y, delta.x)
        let phi: Float
        if angle <= -.pi / 2 {
            phi = -.pi / 2 - angle
        } else if angle >= .pi / 2 {
            phi = 3 * .pi / 2 - angle
        } else {
            phi = angle < 0 ? 0 : .pi
        }
        let theta = -.pi / 2 - phi
        let candidate = center + turnRadius * SIMD2(cos(theta), sin(theta))
        let parameter = (straightLength + turnRadius * phi) / perimeter
        updateBest(candidate: candidate, parameter: parameter, point: point, best: &best)
    }

    private func refineNearest(onRightArc point: SIMD2<Float>, best: inout NearestCenterline) {
        let center = SIMD2(halfStraight, 0)
        let delta = point - center
        let angle = atan2(delta.y, delta.x)
        let phi: Float
        if angle >= -.pi / 2 && angle <= .pi / 2 {
            phi = .pi / 2 - angle
        } else {
            phi = angle > 0 ? 0 : .pi
        }
        let theta = .pi / 2 - phi
        let candidate = center + turnRadius * SIMD2(cos(theta), sin(theta))
        let parameter = (2 * straightLength + semicircleLength + turnRadius * phi) / perimeter
        updateBest(candidate: candidate, parameter: parameter, point: point, best: &best)
    }

    private func updateBest(
        candidate: SIMD2<Float>,
        parameter: Float,
        point: SIMD2<Float>,
        best: inout NearestCenterline
    ) {
        let distSq = simd_length_squared(candidate - point)
        if distSq < best.distanceSquared {
            best = NearestCenterline(
                point: candidate,
                right: centerlineRight(t: parameter),
                parameter: parameter,
                distanceSquared: distSq
            )
        }
    }
}
