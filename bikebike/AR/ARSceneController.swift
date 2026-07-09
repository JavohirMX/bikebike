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
    private weak var sessionCoordinator: ARSessionCoordinator?
    private var trackAnchor: AnchorEntity?
    private var ghostAnchor: AnchorEntity?
    private var ghostTrackEntity: Entity?
    private var cars: [String: Entity] = [:]
    private var carSpeeds: [String: Float] = [:]
    private var bikeMovementStates: [String: BikeMovementState] = [:]
    private var boostEmitterEntities: [String: Entity] = [:]
    private var remoteBoostActive: [String: Bool] = [:]
    private var remoteCarStates: [String: RemoteCarState] = [:]
    private var lastMeasuredArc: [String: Float] = [:]
    private var distanceSinceLap: [String: Float] = [:]
    private var passedCheckpoint: [String: Bool] = [:]
    private var lastLapTimestamp: [String: TimeInterval] = [:]
    private var updateSubscription: (any Cancellable)?
    private var selectedTrackId: String = RaceTrackCatalog.defaultTrackId
    private var trackScale: Float = 1.0
    private var trackGeometry: any RaceTrackGeometry = ProceduralTrackDefinition()

    var isPlacementMode = false
    var trackConfirmed = false
    var onLapCrossed: ((String) -> Void)?
    var onPlaneStateUpdated: ((PlaneDetectionStatus, Bool, ARTrackingQuality) -> Void)?
    var onRelocalizationReady: (() -> Void)?

    private var awaitingRelocalization = false
    private var relocalizationTimer: Timer?
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
    private var ghostUsesFullTrackPreview = false
    private var placementAssetsReady = false

    func attach(to arView: ARView, sessionDelegate: ARSessionDelegate) {
        self.arView = arView
        sessionCoordinator = sessionDelegate as? ARSessionCoordinator
        arView.environment.sceneUnderstanding.options = []
        arView.session.delegate = sessionDelegate
        flushPendingState(session: arView.session)
    }

    func preloadTrackIfNeeded() async {
        refreshTrackGeometry()
    }

    func setSelectedTrack(id: String) {
        selectedTrackId = RaceTrackCatalog.normalizedTrackId(id)
        refreshTrackGeometry()
        if isPlacementMode, ghostAnchor != nil, placementPosition != nil {
            removeGhost()
            createGhostTrack()
        }
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
            if isPlacementMode, ghostAnchor == nil, placementAssetsReady {
                tryInitialGhostPlacement()
            }
        } else if isPlacementMode {
            planeDetectionStatus = .scanning
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

    private(set) var isPreparingPlacementAssets = false

    func startPlacementPreview() {
        guard arView != nil else { return }
        isPlacementMode = true
        trackConfirmed = false
        placementAssetsReady = false
        isPreparingPlacementAssets = true
        placementScale = 1.0
        placementYaw = 0
        placementPosition = nil
        planeDetectionStatus = .scanning
        hasDetectedPlane = false
        notifyPlaneState()
        removeTrack()
        removeGhost()

        resumePlaneDetection()
        Task { @MainActor in
            let trackId = RaceTrackCatalog.normalizedTrackId(selectedTrackId)
            if RaceTrackCatalog.isUSDZTrackId(trackId) {
                await RaceTrackAssetLoader.preloadTrack(id: trackId)
            }
            refreshTrackGeometry()
            placementAssetsReady = true
            isPreparingPlacementAssets = false
            tryInitialGhostPlacement()
        }
    }

    func cancelPlacementPreview() {
        isPlacementMode = false
        placementAssetsReady = false
        isPreparingPlacementAssets = false
        placementPosition = nil
        removeGhost()
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

    func confirmPlacement() async -> PlacementResult? {
        guard let ghost = ghostAnchor else { return nil }
        let requestedTrackId = RaceTrackCatalog.normalizedTrackId(selectedTrackId)
        let worldTransform = ghost.transformMatrix(relativeTo: nil)
        let scale = placementScale
        if !ghostUsesFullTrackPreview, RaceTrackCatalog.isUSDZTrackId(requestedTrackId) {
            await RaceTrackAssetLoader.preloadTrack(id: requestedTrackId)
        }

        let presetId = requestedTrackId
        removeTrack()

        if ghostUsesFullTrackPreview, let track = ghostTrackEntity {
            ghost.removeFromParent()
            track.removeFromParent()
            RaceTrackFactory.stripOpacity(from: track)
            let anchor = AnchorEntity(world: worldTransform)
            anchor.addChild(track)
            arView?.scene.addAnchor(anchor)
            trackAnchor = anchor
            ghostAnchor = nil
            ghostTrackEntity = nil
            ghostUsesFullTrackPreview = false
        } else {
            removeGhost()
            let anchor = AnchorEntity(world: worldTransform)
            guard let track = RaceTrackFactory.makeSyncedTrackEntity(for: presetId, scale: scale) else {
                return nil
            }
            anchor.addChild(track)
            arView?.scene.addAnchor(anchor)
            trackAnchor = anchor
        }

        guard let geometry = RaceTrackFactory.exactGeometry(for: presetId, scale: scale) else {
            return nil
        }
        trackGeometry = geometry
        trackScale = scale

        isPlacementMode = false
        trackConfirmed = true
        placementPosition = nil
        stopPlaneDetectionForRacing()

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
        guard let arView, let position = placementPosition, placementAssetsReady else { return }
        removeGhost()

        var matrix = matrix_identity_float4x4
        matrix = simd_float4x4(simd_quatf(angle: placementYaw, axis: SIMD3(0, 1, 0)))
        matrix.columns.3 = SIMD4(position.x, position.y, position.z, 1)

        guard let track = RaceTrackFactory.makePlacementGhost(for: selectedTrackId, scale: placementScale) else {
            return
        }

        let ghost = AnchorEntity(world: matrix)
        ghostUsesFullTrackPreview = RaceTrackFactory.usesFullTrackPlacementGhost
        ghost.addChild(track)
        arView.scene.addAnchor(ghost)
        ghostAnchor = ghost
        ghostTrackEntity = track
        notifyPlaneState()
    }

    private func applyGhostTransform() {
        guard let ghostAnchor, let position = placementPosition else { return }
        var matrix = simd_float4x4(simd_quatf(angle: placementYaw, axis: SIMD3(0, 1, 0)))
        matrix.columns.3 = SIMD4(position.x, position.y, position.z, 1)
        ghostAnchor.transform.matrix = matrix
    }

    @discardableResult
    func placeTrackFromSync(transform: TransformPacket, scale: Float = 1.0, presetId: String? = nil) -> Bool {
        let trackId = RaceTrackCatalog.normalizedTrackId(presetId ?? selectedTrackId)
        guard arView != nil else {
            pendingTrack = (transform, scale, trackId)
            return false
        }
        removeGhost()
        removeTrack()

        guard let track = RaceTrackFactory.makeSyncedTrackEntity(for: trackId, scale: scale),
              let geometry = RaceTrackFactory.syncedGeometry(for: trackId, scale: scale) else {
            return false
        }

        var matrix = simd_float4x4(transform.rotation.simd)
        matrix.columns.3 = SIMD4(transform.position.x, transform.position.y, transform.position.z, 1)

        let anchor = AnchorEntity(world: matrix)
        anchor.addChild(track)
        arView?.scene.addAnchor(anchor)
        trackAnchor = anchor
        selectedTrackId = trackId
        trackScale = scale
        trackGeometry = geometry
        trackConfirmed = true
        isPlacementMode = false
        stopPlaneDetectionForRacing()
        return true
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
        sessionCoordinator?.resetPlaneTracking()

        let config = ARSessionConfigFactory.makeWorldConfig(
            planeDetection: true,
            initialWorldMap: worldMap
        )
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        startRelocalizationPolling(session: session)
    }

    func notifyRelocalizationReady() {
        guard awaitingRelocalization else { return }
        awaitingRelocalization = false
        stopRelocalizationPolling()
        onRelocalizationReady?()
    }

    func hasCar(playerId: String) -> Bool {
        cars[playerId] != nil
    }

    func spawnCar(playerId: String, driverId: String, gridIndex: Int, isLocal: Bool) async {
        guard let trackAnchor else { return }
        removeCar(playerId: playerId)

        let car = await CarModelLoader.makeCar(driverId: driverId)
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

    func hideCar(playerId: String) {
        cars[playerId]?.isEnabled = false
    }

    func removeCar(playerId: String) {
        cars[playerId]?.removeFromParent()
        cars.removeValue(forKey: playerId)
        carSpeeds.removeValue(forKey: playerId)
        bikeMovementStates.removeValue(forKey: playerId)
        remoteCarStates.removeValue(forKey: playerId)
        remoteBoostActive.removeValue(forKey: playerId)
        removeBoostEmitter(for: playerId)
        lastMeasuredArc.removeValue(forKey: playerId)
        distanceSinceLap.removeValue(forKey: playerId)
        passedCheckpoint.removeValue(forKey: playerId)
        lastLapTimestamp.removeValue(forKey: playerId)
    }

    private func disableLights(on entity: Entity) {
        if entity.components.has(SpotLightComponent.self) {
            entity.components.remove(SpotLightComponent.self)
        }
        if entity.components.has(PointLightComponent.self) {
            entity.components.remove(PointLightComponent.self)
        }
        if entity.components.has(DirectionalLightComponent.self) {
            entity.components.remove(DirectionalLightComponent.self)
        }
        for child in entity.children {
            disableLights(on: child)
        }
    }

    func removeAllCars() {
        for id in cars.keys { removeCar(playerId: id) }
    }

    func applyBoostBurst(playerId: String) {
        let burstSpeed = BikeMovementModel.boostedMaxSpeed
        let current = carSpeeds[playerId] ?? 0
        let newSpeed = max(current, burstSpeed)
        carSpeeds[playerId] = newSpeed
        if var state = bikeMovementStates[playerId] {
            state.speed = newSpeed
            bikeMovementStates[playerId] = state
        }
    }

    @discardableResult
    func applyInput(playerId: String, steer: Float, gasPressed: Bool, brake: Float, boostActive: Bool, deltaTime: Float) -> Bool {
        guard let car = cars[playerId], let trackAnchor else { return false }

        let previousLocal = localCarPosition(car)
        var movementState = bikeMovementStates[playerId] ?? BikeMovementModel.initialState(from: car.orientation)
        movementState.speed = carSpeeds[playerId] ?? movementState.speed

        let result = BikeMovementModel.integrate(
            state: movementState,
            input: BikeMovementInput(steer: steer, gasPressed: gasPressed, brake: brake, boostActive: boostActive),
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

        setBoostActive(playerId: playerId, active: boostActive)
        checkFinishLineCrossing(playerId: playerId, car: car, previousLocal: previousLocal)
        return result.hitWall
    }

    func setBoostActive(playerId: String, active: Bool) {
        guard let car = cars[playerId] else { return }
        if active {
            if boostEmitterEntities[playerId] == nil {
                let emitter = makeBoostEmitter()
                emitter.position = SIMD3(0, 0.04, 0.08)
                car.addChild(emitter)
                boostEmitterEntities[playerId] = emitter
            }
        } else {
            removeBoostEmitter(for: playerId)
        }
    }

    func isBoostActive(playerId: String) -> Bool {
        boostEmitterEntities[playerId] != nil
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

    func setRemoteCarTarget(playerId: String, transform: TransformPacket, speed: Float, boostActive: Bool = false) {
        guard trackAnchor != nil, cars[playerId] != nil else { return }
        remoteCarStates[playerId] = RemoteCarState(
            transform: transform,
            speed: speed,
            receivedAt: Date().timeIntervalSince1970
        )
        if remoteBoostActive[playerId] != boostActive {
            remoteBoostActive[playerId] = boostActive
            setBoostActive(playerId: playerId, active: boostActive)
        }
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
        let forwardXZ = SIMD2(-sin(yaw), -cos(yaw))
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
        stopRelocalizationPolling()
        removeAllCars()
        removeTrack()
        removeGhost()
        arView?.session.delegate = nil
        arView = nil
        sessionCoordinator = nil
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
        // Allow up to 45% of the track per frame to support low framerates without resetting progress
        let maxStep = trackGeometry.perimeterLength * 0.45
        guard delta > 0, delta <= maxStep else { 
            // Update lastMeasured so we don't get permanently stuck if there was a jump
            lastMeasuredArc[playerId] = measured
            return 
        }

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
        let deltaFromFinish = trackGeometry.forwardArcDelta(from: finish, to: measured)
        
        // Ensure we crossed the finish line and are in the first 15% of the lap
        let nearFinish = deltaFromFinish < (trackGeometry.perimeterLength * 0.15)

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
        trackGeometry = RaceTrackFactory.geometry(for: selectedTrackId, scale: trackScale)
    }

    private func resumePlaneDetection() {
        guard let session = arView?.session else { return }
        let config = ARSessionConfigFactory.makeWorldConfig(planeDetection: true)
        session.run(config)
    }

    private func stopPlaneDetectionForRacing() {
        guard let session = arView?.session else { return }
        let config = ARSessionConfigFactory.makeWorldConfig(planeDetection: false)
        session.run(config)
    }

    private func startRelocalizationPolling(session: ARSession) {
        stopRelocalizationPolling()
        relocalizationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkRelocalizationReady()
            }
        }
    }

    private func checkRelocalizationReady() {
        guard awaitingRelocalization else {
            stopRelocalizationPolling()
            return
        }
        guard let frame = arView?.session.currentFrame else { return }
        let mappingStatus = frame.worldMappingStatus
        let trackingState = frame.camera.trackingState
        if mappingStatus == .mapped, case .normal = trackingState {
            notifyRelocalizationReady()
        }
    }

    private func stopRelocalizationPolling() {
        relocalizationTimer?.invalidate()
        relocalizationTimer = nil
    }

    private func removeTrack() {
        trackAnchor?.removeFromParent()
        trackAnchor = nil
        trackConfirmed = false
        trackScale = 1.0
    }

    private func removeGhost() {
        ghostAnchor?.removeFromParent()
        ghostAnchor = nil
        ghostTrackEntity = nil
        ghostUsesFullTrackPreview = false
        if isPlacementMode {
            notifyPlaneState()
        }
    }
}

private struct RemoteCarState {
    var transform: TransformPacket
    var speed: Float
    var receivedAt: TimeInterval
}

private func makeBoostEmitter() -> Entity {
    let entity = Entity()
    var particles = ParticleEmitterComponent()
    particles.emitterShape = .sphere
    particles.emitterShapeSize = SIMD3(0.02, 0.02, 0.02)
    particles.speed = 0.35
    particles.mainEmitter.birthRate = 180
    particles.mainEmitter.lifeSpan = 0.35
    particles.mainEmitter.size = 0.012
    particles.mainEmitter.color = .evolving(
        start: .single(.orange),
        end: .single(.yellow)
    )
    entity.components.set(particles)
    return entity
}

private extension ARSceneController {
    func removeBoostEmitter(for playerId: String) {
        boostEmitterEntities[playerId]?.removeFromParent()
        boostEmitterEntities.removeValue(forKey: playerId)
    }
}

private extension simd_quatf {
    init(_ matrix: simd_float4x4) {
        self = simd_quaternion(matrix)
    }
}
