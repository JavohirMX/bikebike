//
//  ARSceneController.swift
//  bikebike
//

import ARKit
import Combine
import RealityKit
import UIKit

struct PlacementResult {
    let transform: TransformPacket
    let scale: Float
    let presetId: String
}

@MainActor
final class ARSceneController {
    private weak var arView: ARView?
    private var trackAnchor: AnchorEntity?
    private var ghostAnchor: AnchorEntity?
    private var ghostTrackEntity: Entity?
    private var cars: [String: Entity] = [:]
    private var carSpeeds: [String: Float] = [:]
    private var bikeMovementStates: [String: BikeMovementState] = [:]
    private var remoteCarStates: [String: RemoteCarState] = [:]
    private var lastMeasuredArc: [String: Float] = [:]
    private var distanceSinceLap: [String: Float] = [:]
    private var passedCheckpoint: [String: Bool] = [:]
    private var lastLapTimestamp: [String: TimeInterval] = [:]
    private var updateSubscription: (any Cancellable)?
    private var selectedTrackId: String = RaceTrackCatalog.defaultTrackId
    private var trackGeometry: any RaceTrackGeometry = ProceduralTrackDefinition()

    var isPlacementMode = false
    var trackConfirmed = false
    var onLapCrossed: ((String) -> Void)?
    var onPlaneStateUpdated: ((PlaneDetectionStatus, Bool, ARTrackingQuality) -> Void)?
    var onRelocalizationReady: (() -> Void)?

    private var awaitingRelocalization = false
    private var pendingTrack: (transform: TransformPacket, scale: Float, presetId: String)?
    private var pendingWorldMap: ARWorldMap?

    var isARViewAttached: Bool { arView != nil }
    var isAwaitingRelocalization: Bool { awaitingRelocalization }

    private(set) var planeDetectionStatus: PlaneDetectionStatus = .scanning
    private(set) var hasDetectedPlane = false
    private(set) var trackingQuality: ARTrackingQuality = .normal

    private let minLapTime: TimeInterval = 1.5
    private let maxProgressStepPerFrame: Float = 0.20

    private static let minPlacementScale: Float = 0.6
    private static let maxPlacementScale: Float = 1.4

    private(set) var placementScale: Float = 1.0
    private var placementYaw: Float = 0
    private var placementPosition: SIMD3<Float>?

    func attach(to arView: ARView, sessionDelegate: ARSessionDelegate) {
        self.arView = arView
        arView.environment.sceneUnderstanding.options = []
        arView.session.delegate = sessionDelegate
        Task { @MainActor in
            await CarModelLoader.preload()
            await RaceTrackFactory.preloadAssets()
            refreshTrackGeometry()
        }
        flushPendingState(session: arView.session)
    }

    func setSelectedTrack(id: String) {
        selectedTrackId = RaceTrackCatalog.normalizedTrackId(id)
        refreshTrackGeometry()
    }

    func flushPendingState(session: ARSession) {
        if let worldMap = pendingWorldMap {
            pendingWorldMap = nil
            applyWorldMap(worldMap, session: session)
        }
        if let pending = pendingTrack {
            pendingTrack = nil
            placeTrackFromSync(transform: pending.transform, scale: pending.scale, presetId: pending.presetId)
        }
    }

    func updatePlaneDetection(hasHorizontalPlane: Bool) {
        hasDetectedPlane = hasHorizontalPlane
        if hasHorizontalPlane {
            if trackingQuality == .normal {
                planeDetectionStatus = .ready
            } else {
                planeDetectionStatus = .surfaceFound
            }
            arView?.debugOptions.remove(.showFeaturePoints)
            if isPlacementMode, ghostAnchor == nil {
                tryInitialGhostPlacement()
            }
        } else if isPlacementMode {
            planeDetectionStatus = .scanning
            arView?.debugOptions.insert(.showFeaturePoints)
        }
        notifyPlaneState()
    }

    func updateTrackingState(_ state: ARCamera.TrackingState) {
        switch state {
        case .normal:
            trackingQuality = .normal
            if hasDetectedPlane && isPlacementMode {
                planeDetectionStatus = .ready
            }
        case .limited:
            trackingQuality = .limited
            if isPlacementMode && hasDetectedPlane {
                planeDetectionStatus = .surfaceFound
            }
        case .notAvailable:
            trackingQuality = .unavailable
        }
        notifyPlaneState()
    }

    var canConfirmPlacement: Bool {
        ghostAnchor != nil && hasDetectedPlane && trackingQuality == .normal
    }

    func startPlacementPreview() {
        guard arView != nil else { return }
        isPlacementMode = true
        trackConfirmed = false
        placementScale = 1.0
        placementYaw = 0
        placementPosition = nil
        planeDetectionStatus = .scanning
        hasDetectedPlane = false
        notifyPlaneState()
        removeTrack()
        removeGhost()

        arView?.debugOptions.insert(.showFeaturePoints)
        tryInitialGhostPlacement()
    }

    func cancelPlacementPreview() {
        isPlacementMode = false
        placementPosition = nil
        removeGhost()
        arView?.debugOptions.remove(.showFeaturePoints)
        planeDetectionStatus = .scanning
        hasDetectedPlane = false
        notifyPlaneState()
    }

    func updatePlacement(raycastFrom point: CGPoint, in arView: ARView) {
        guard isPlacementMode else { return }
        let results = arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal)
        guard let hit = results.first else { return }

        placementPosition = SIMD3(
            hit.worldTransform.columns.3.x,
            hit.worldTransform.columns.3.y,
            hit.worldTransform.columns.3.z
        )

        if ghostAnchor == nil {
            createGhostTrack()
        } else {
            applyGhostTransform()
        }
    }

    func setPlacementScale(_ scale: Float) {
        placementScale = min(Self.maxPlacementScale, max(Self.minPlacementScale, scale))
        ghostTrackEntity?.scale = SIMD3(repeating: placementScale)
    }

    func addPlacementYaw(_ delta: Float) {
        placementYaw += delta
        applyGhostTransform()
    }

    func confirmPlacement() -> PlacementResult? {
        guard let ghost = ghostAnchor else { return nil }
        let worldTransform = ghost.transformMatrix(relativeTo: nil)
        let scale = placementScale
        let presetId = RaceTrackFactory.resolvedTrackId(for: selectedTrackId)
        removeGhost()
        removeTrack()

        let anchor = AnchorEntity(world: worldTransform)
        let track = RaceTrackFactory.makeTrackEntity(for: presetId, scale: scale)
        anchor.addChild(track)
        arView?.scene.addAnchor(anchor)
        trackAnchor = anchor
        trackGeometry = RaceTrackFactory.geometry(for: presetId)

        isPlacementMode = false
        trackConfirmed = true
        placementPosition = nil
        arView?.debugOptions.remove(.showFeaturePoints)

        let pos = SIMD3<Float>(worldTransform.columns.3.x, worldTransform.columns.3.y, worldTransform.columns.3.z)
        let rot = simd_quatf(worldTransform)
        return PlacementResult(transform: TransformPacket(position: pos, rotation: rot), scale: scale, presetId: presetId)
    }

    private func tryInitialGhostPlacement() {
        guard let arView, isPlacementMode else { return }
        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        updatePlacement(raycastFrom: center, in: arView)
    }

    private func createGhostTrack() {
        guard let arView, let position = placementPosition else { return }
        removeGhost()

        var matrix = matrix_identity_float4x4
        matrix = simd_float4x4(simd_quatf(angle: placementYaw, axis: SIMD3(0, 1, 0)))
        matrix.columns.3 = SIMD4(position.x, position.y, position.z, 1)

        let ghost = AnchorEntity(world: matrix)
        let track = RaceTrackFactory.makeTrackEntity(for: selectedTrackId, scale: placementScale, opacity: 0.55)
        ghost.addChild(track)
        arView.scene.addAnchor(ghost)
        ghostAnchor = ghost
        ghostTrackEntity = track
    }

    private func applyGhostTransform() {
        guard let ghostAnchor, let position = placementPosition else { return }
        var matrix = simd_float4x4(simd_quatf(angle: placementYaw, axis: SIMD3(0, 1, 0)))
        matrix.columns.3 = SIMD4(position.x, position.y, position.z, 1)
        ghostAnchor.transform.matrix = matrix
    }

    func placeTrackFromSync(transform: TransformPacket, scale: Float = 1.0, presetId: String? = nil) {
        let trackId = presetId ?? selectedTrackId
        guard arView != nil else {
            pendingTrack = (transform, scale, trackId)
            return
        }
        removeGhost()
        removeTrack()

        var matrix = simd_float4x4(transform.rotation.simd)
        matrix.columns.3 = SIMD4(transform.position.x, transform.position.y, transform.position.z, 1)

        let anchor = AnchorEntity(world: matrix)
        let track = RaceTrackFactory.makeTrackEntity(for: trackId, scale: scale)
        anchor.addChild(track)
        arView?.scene.addAnchor(anchor)
        trackAnchor = anchor
        selectedTrackId = RaceTrackCatalog.normalizedTrackId(trackId)
        trackGeometry = RaceTrackFactory.geometry(for: trackId)
        trackConfirmed = true
        isPlacementMode = false
    }

    func applyWorldMap(_ worldMap: ARWorldMap, session: ARSession) {
        guard arView != nil else {
            pendingWorldMap = worldMap
            return
        }
        awaitingRelocalization = true
        removeAllCars()
        removeTrack()
        removeGhost()
        trackConfirmed = false

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        config.initialWorldMap = worldMap
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func notifyRelocalizationReady() {
        guard awaitingRelocalization else { return }
        awaitingRelocalization = false
        onRelocalizationReady?()
    }

    func hasCar(playerId: String) -> Bool {
        cars[playerId] != nil
    }

    func spawnCar(playerId: String, colorHex: String, gridIndex: Int) async {
        guard let trackAnchor else { return }
        removeCar(playerId: playerId)

        let color = UIColor(hex: colorHex) ?? .systemRed
        let car = await CarModelLoader.makeCar(color: color)
        car.name = "Car_\(playerId)"

        let spawn = trackGeometry.spawnTransform(gridIndex: gridIndex)
        car.position = spawn.position
        car.orientation = simd_quatf(angle: spawn.orientationAngle, axis: SIMD3(0, 1, 0))

        trackAnchor.addChild(car)
        cars[playerId] = car
        carSpeeds[playerId] = 0
        bikeMovementStates[playerId] = BikeMovementModel.initialState(from: car.orientation)
        let spawnArc = trackGeometry.arcLength(for: spawn.position)
        lastMeasuredArc[playerId] = spawnArc
        distanceSinceLap[playerId] = 0
        passedCheckpoint[playerId] = false
        lastLapTimestamp[playerId] = Date().timeIntervalSince1970
    }

    func removeCar(playerId: String) {
        cars[playerId]?.removeFromParent()
        cars.removeValue(forKey: playerId)
        carSpeeds.removeValue(forKey: playerId)
        bikeMovementStates.removeValue(forKey: playerId)
        remoteCarStates.removeValue(forKey: playerId)
        lastMeasuredArc.removeValue(forKey: playerId)
        distanceSinceLap.removeValue(forKey: playerId)
        passedCheckpoint.removeValue(forKey: playerId)
        lastLapTimestamp.removeValue(forKey: playerId)
    }

    func removeAllCars() {
        for id in cars.keys { removeCar(playerId: id) }
    }

    func applyInput(playerId: String, steer: Float, gasPressed: Bool, brake: Float, deltaTime: Float) {
        guard let car = cars[playerId], let trackAnchor else { return }

        let previousLocal = localCarPosition(car)
        var movementState = bikeMovementStates[playerId] ?? BikeMovementModel.initialState(from: car.orientation)
        movementState.speed = carSpeeds[playerId] ?? movementState.speed

        let result = BikeMovementModel.integrate(
            state: movementState,
            input: BikeMovementInput(steer: steer, gasPressed: gasPressed, brake: brake),
            localPosition: previousLocal,
            trackGeometry: trackGeometry,
            wheelbase: trackGeometry.carSize.z,
            hintArcLength: lastMeasuredArc[playerId],
            deltaTime: deltaTime
        )

        car.setPosition(trackAnchor.convert(position: result.localPosition, to: nil), relativeTo: nil)
        car.orientation = result.orientation
        carSpeeds[playerId] = result.speed
        bikeMovementStates[playerId] = BikeMovementState(
            speed: result.speed,
            pedalAmount: result.pedalAmount,
            yaw: result.yaw,
            pitch: result.pitch
        )

        checkFinishLineCrossing(playerId: playerId, car: car, previousLocal: previousLocal)
    }

    func carTransform(playerId: String) -> TransformPacket? {
        guard let car = cars[playerId], let trackAnchor else { return nil }
        let pos = car.position(relativeTo: trackAnchor)
        let rot = car.orientation(relativeTo: trackAnchor)
        return TransformPacket(position: pos, rotation: rot, timestamp: Date().timeIntervalSince1970)
    }

    func carSpeed(playerId: String) -> Float {
        carSpeeds[playerId] ?? 0
    }

    func setRemoteCarTarget(playerId: String, transform: TransformPacket, speed: Float) {
        guard trackAnchor != nil, cars[playerId] != nil else { return }
        remoteCarStates[playerId] = RemoteCarState(
            transform: transform,
            speed: speed,
            receivedAt: Date().timeIntervalSince1970
        )
    }

    func tickRemoteCars(deltaTime: Float, now: TimeInterval) {
        guard trackAnchor != nil else { return }
        let smoothingRate: Float = 15.0
        let alpha = min(1.0, deltaTime * smoothingRate)
        let maxExtrapolation: TimeInterval = 0.15

        for (playerId, state) in remoteCarStates {
            guard let car = cars[playerId] else { continue }

            var targetPos = state.transform.position.simd
            let targetRot = state.transform.rotation.simd

            let elapsed = now - state.receivedAt
            if elapsed > 0, elapsed < maxExtrapolation, state.speed > 0.01 {
                let forward = state.transform.rotation.simd.act(SIMD3(0, 0, -1))
                let forwardXZ = SIMD3<Float>(forward.x, 0, forward.z)
                if simd_length_squared(forwardXZ) > 0.0001 {
                    let forwardDir = simd_normalize(forwardXZ)
                    targetPos += forwardDir * state.speed * Float(elapsed)
                }
            }

            car.position = simd_mix(car.position, targetPos, SIMD3(repeating: alpha))
            car.orientation = simd_slerp(car.orientation, targetRot, alpha)
            alignRemoteCarToTrack(car, playerId: playerId)
        }
    }

    private func alignRemoteCarToTrack(_ car: Entity, playerId: String) {
        guard let trackAnchor else { return }
        var localPos = trackAnchor.convert(position: car.position(relativeTo: nil), from: nil)
        let yaw = BikeMovementModel.yaw(from: car.orientation(relativeTo: trackAnchor))
        let forwardXZ = SIMD2(sin(yaw), -cos(yaw))
        let halfWheelbase = trackGeometry.carSize.z / 2

        let frontSample = SIMD3(
            localPos.x + forwardXZ.x * halfWheelbase,
            localPos.y,
            localPos.z + forwardXZ.y * halfWheelbase
        )
        let rearSample = SIMD3(
            localPos.x - forwardXZ.x * halfWheelbase,
            localPos.y,
            localPos.z - forwardXZ.y * halfWheelbase
        )
        let hint = lastMeasuredArc[playerId]
        let frontY = trackGeometry.surfaceHeight(at: frontSample, hintArcLength: hint)
        let rearY = trackGeometry.surfaceHeight(at: rearSample, hintArcLength: hint)
        localPos.y = (frontY + rearY) / 2
        let pitch = atan2(frontY - rearY, max(trackGeometry.carSize.z, 0.001))
        let orientation = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
            * simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0))

        car.setPosition(trackAnchor.convert(position: localPos, to: nil), relativeTo: nil)
        car.orientation = orientation
    }

    func updateRemoteCar(playerId: String, transform: TransformPacket) {
        setRemoteCarTarget(playerId: playerId, transform: transform, speed: 0)
    }

    func teardown() {
        updateSubscription?.cancel()
        removeAllCars()
        removeTrack()
        removeGhost()
        arView?.session.delegate = nil
        arView?.debugOptions.remove(.showFeaturePoints)
        arView = nil
        planeDetectionStatus = .scanning
        hasDetectedPlane = false
        trackingQuality = .normal
        awaitingRelocalization = false
        pendingTrack = nil
        pendingWorldMap = nil
        notifyPlaneState()
    }

    private func notifyPlaneState() {
        onPlaneStateUpdated?(planeDetectionStatus, hasDetectedPlane, trackingQuality)
    }

    private func updateLapProgress(playerId: String, localPos: SIMD3<Float>) {
        let hint = lastMeasuredArc[playerId]
        let measured = trackGeometry.arcLength(for: localPos, hintArcLength: hint)
        guard let lastMeasured = lastMeasuredArc[playerId] else {
            lastMeasuredArc[playerId] = measured
            return
        }

        let delta = trackGeometry.forwardArcDelta(from: lastMeasured, to: measured)
        guard delta > 0, delta <= maxProgressStepPerFrame else { return }

        lastMeasuredArc[playerId] = measured
        distanceSinceLap[playerId] = (distanceSinceLap[playerId] ?? 0) + delta
    }

    private func checkFinishLineCrossing(playerId: String, car: Entity, previousLocal: SIMD3<Float>) {
        guard trackAnchor != nil else { return }
        let local = localCarPosition(car)
        updateLapProgress(playerId: playerId, localPos: local)

        guard let distance = distanceSinceLap[playerId] else { return }

        if !passedCheckpoint[playerId, default: false], distance >= checkpointDistance {
            passedCheckpoint[playerId] = true
        }

        let hint = lastMeasuredArc[playerId]
        let measured = trackGeometry.arcLength(for: local, hintArcLength: hint)
        let finish = trackGeometry.finishArcLength
        let nearFinish = trackGeometry.forwardArcDelta(from: finish, to: measured) < 0.12

        if passedCheckpoint[playerId] == true, distance >= minLapDistance, nearFinish {
            let now = Date().timeIntervalSince1970
            if now - (lastLapTimestamp[playerId] ?? 0) >= minLapTime {
                lastLapTimestamp[playerId] = now
                distanceSinceLap[playerId] = 0
                passedCheckpoint[playerId] = false
                lastMeasuredArc[playerId] = measured
                onLapCrossed?(playerId)
            }
        }
    }

    private func localCarPosition(_ car: Entity) -> SIMD3<Float> {
        guard let trackAnchor else { return .zero }
        return trackAnchor.convert(position: car.position(relativeTo: nil), from: nil)
    }

    private var minLapDistance: Float {
        trackGeometry.perimeterLength * 0.75
    }

    private var checkpointDistance: Float {
        trackGeometry.perimeterLength * 0.45
    }

    private func refreshTrackGeometry() {
        trackGeometry = RaceTrackFactory.geometry(for: selectedTrackId)
    }

    private func removeTrack() {
        trackAnchor?.removeFromParent()
        trackAnchor = nil
        trackConfirmed = false
    }

    private func removeGhost() {
        ghostAnchor?.removeFromParent()
        ghostAnchor = nil
        ghostTrackEntity = nil
    }
}

private struct RemoteCarState {
    var transform: TransformPacket
    var speed: Float
    var receivedAt: TimeInterval
}

private extension UIColor {
    convenience init?(hex: String) {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.hasPrefix("#") { hex = String(hex.dropFirst()) }
        guard hex.count == 6, let int = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: CGFloat((int >> 16) & 0xFF) / 255,
            green: CGFloat((int >> 8) & 0xFF) / 255,
            blue: CGFloat(int & 0xFF) / 255,
            alpha: 1
        )
    }
}

private extension simd_quatf {
    init(_ matrix: simd_float4x4) {
        self = simd_quaternion(matrix)
    }
}
