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
    private var boostVFXEntities: [String: Entity] = [:]
    private var boostVFXBurstStartedAt: [String: TimeInterval] = [:]
    private var localPlayerIndicator: Entity?
    private var localPlayerIndicatorBobStart: TimeInterval?
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
    private let leaderboardScoreboard = ARLeaderboardScoreboard()

    func attach(to arView: ARView, sessionCoordinator: ARSessionCoordinator) {
        self.arView = arView
        self.sessionCoordinator = sessionCoordinator
        arView.environment.sceneUnderstanding.options = []
        arView.session.delegate = sessionCoordinator
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

    func spawnCar(
        playerId: String,
        driverId: String,
        gridIndex: Int,
        isLocal: Bool,
        showOwnBikeIndicator: Bool = false
    ) async {
        guard let trackAnchor else { return }
        removeCar(playerId: playerId)

        let car = await CarModelLoader.makeCar(driverId: driverId)
        car.name = "Car_\(playerId)"


        let spawn = trackGeometry.spawnTransform(gridIndex: gridIndex)
        car.position = spawn.position
        car.orientation = simd_quatf(angle: spawn.orientationAngle, axis: SIMD3(0, 1, 0))

        trackAnchor.addChild(car)
        cars[playerId] = car

        if showOwnBikeIndicator {
            let indicator = LocalPlayerIndicator.make(
                accentHex: DriverCatalog.accentColorHex(for: driverId)
            )
            car.addChild(indicator)
            localPlayerIndicator = indicator
            localPlayerIndicatorBobStart = Date().timeIntervalSince1970
        }
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
        if localPlayerIndicator?.parent == cars[playerId] {
            localPlayerIndicator = nil
            localPlayerIndicatorBobStart = nil
        }
        cars[playerId]?.removeFromParent()
        cars.removeValue(forKey: playerId)
        carSpeeds.removeValue(forKey: playerId)
        bikeMovementStates.removeValue(forKey: playerId)
        remoteCarStates.removeValue(forKey: playerId)
        remoteBoostActive.removeValue(forKey: playerId)
        removeBoostVFX(for: playerId)
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
            pitch: result.pitch,
            roll: result.roll
        )

        setBoostActive(playerId: playerId, active: boostActive)
        updateLocalPlayerIndicatorBob()
        updateBoostVFXAnimation(playerId: playerId)
        checkFinishLineCrossing(playerId: playerId, car: car, previousLocal: previousLocal)
        return result.hitWall
    }

    private func updateLocalPlayerIndicatorBob() {
        guard let indicator = localPlayerIndicator else { return }
        let start = localPlayerIndicatorBobStart ?? Date().timeIntervalSince1970
        let elapsed = Date().timeIntervalSince1970 - start
        indicator.position.y = LocalPlayerIndicator.heightAboveCar + LocalPlayerIndicator.bobOffset(time: elapsed)
    }

    func setBoostActive(playerId: String, active: Bool) {
        guard let car = cars[playerId] else { return }
        if active {
            if boostVFXEntities[playerId] == nil {
                let vfx = makeBoostVFX()
                // Visual bike is longer than the collider (fit scale 1.35); pin to the rear tip.
                let rearZ = OvalTrackGeometry.carSize.z * 0.5 * 1.35
                vfx.position = SIMD3(0, 0.012, rearZ)
                car.addChild(vfx)
                boostVFXEntities[playerId] = vfx
                boostVFXBurstStartedAt[playerId] = Date().timeIntervalSince1970
                updateBoostVFXAnimation(playerId: playerId)
                triggerBoostParticleBurst(on: vfx)
            }
        } else {
            removeBoostVFX(for: playerId)
        }
    }

    func isBoostActive(playerId: String) -> Bool {
        boostVFXEntities[playerId] != nil
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

    func trackProgress(for playerId: String) -> Float {
        guard trackGeometry.perimeterLength > 0.001 else { return 0 }
        if let car = cars[playerId] {
            let local = localCarPosition(car)
            let hint = lastMeasuredArc[playerId]
            let arc = trackGeometry.arcLength(for: local, hintArcLength: hint)
            return min(1, max(0, arc / trackGeometry.perimeterLength))
        }
        if let arc = lastMeasuredArc[playerId] {
            return min(1, max(0, arc / trackGeometry.perimeterLength))
        }
        return 0
    }

    var isLeaderboardAttached: Bool { leaderboardScoreboard.isAttached }

    func showLeaderboardScoreboard(
        entries: [LeaderboardEntry],
        localPlayerId: String,
        lapCount: Int
    ) {
        guard let trackAnchor else {
            return
        }
        leaderboardScoreboard.attach(
            to: trackAnchor,
            geometry: trackGeometry,
            scale: trackScale,
            entries: entries,
            localPlayerId: localPlayerId,
            lapCount: lapCount
        )
        updateLeaderboardOrientation()
    }

    func updateLeaderboardOrientation() {
        guard leaderboardScoreboard.isAttached,
              let frame = arView?.session.currentFrame else { return }
        let cameraPosition = SIMD3<Float>(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )
        leaderboardScoreboard.faceCamera(cameraPosition)
    }

    func updateLeaderboardScoreboard(
        entries: [LeaderboardEntry],
        localPlayerId: String,
        lapCount: Int
    ) {
        if !leaderboardScoreboard.isAttached, trackAnchor != nil {
            showLeaderboardScoreboard(
                entries: entries,
                localPlayerId: localPlayerId,
                lapCount: lapCount
            )
            return
        }
        leaderboardScoreboard.update(
            entries: entries,
            localPlayerId: localPlayerId,
            lapCount: lapCount
        )
    }

    func hideLeaderboardScoreboard() {
        leaderboardScoreboard.hide()
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
            updateBoostVFXAnimation(playerId: playerId)
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
        updateArcMeasurement(playerId: playerId, localPos: localPos)
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

    private func updateArcMeasurement(playerId: String, localPos: SIMD3<Float>) {
        let hint = lastMeasuredArc[playerId]
        let measured = trackGeometry.arcLength(for: localPos, hintArcLength: hint)
        if let last = lastMeasuredArc[playerId] {
            let delta = trackGeometry.forwardArcDelta(from: last, to: measured)
            let maxStep = trackGeometry.perimeterLength * 0.45
            guard delta <= maxStep else { return }
        }
        lastMeasuredArc[playerId] = measured
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
        hideLeaderboardScoreboard()
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

private enum BoostVFX {
    static let burstScale: Float = 1.9
    static let sustainScale: Float = 1.0
    static let burstDuration: TimeInterval = 0.22
    /// RealityKit cones point along +Y; rotate so the tip aims rearward (+Z).
    static let rearFacingOrientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
}

private struct RemoteCarState {
    var transform: TransformPacket
    var speed: Float
    var receivedAt: TimeInterval
}

private func makeBoostVFX() -> Entity {
    let root = Entity()
    root.name = "BoostVFX"
    // Stretch into a rear jet; bike is only ~6.5cm long.
    root.scale = SIMD3(0.85, 0.85, 1.35)

    let layers: [(height: Float, radius: Float, z: Float, color: UIColor, opacity: Float)] = [
        (0.07, 0.022, 0.012, UIColor(red: 1.0, green: 0.18, blue: 0.02, alpha: 1), 0.55),
        (0.055, 0.014, 0.008, UIColor(red: 1.0, green: 0.45, blue: 0.05, alpha: 1), 0.7),
        (0.04, 0.008, 0.004, UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1), 0.85),
        (0.028, 0.004, 0.0, UIColor(red: 1.0, green: 0.98, blue: 0.75, alpha: 1), 0.95)
    ]

    for (index, layer) in layers.enumerated() {
        let flame = makeFlameCone(
            height: layer.height,
            radius: layer.radius,
            color: layer.color,
            opacity: layer.opacity
        )
        flame.name = "FlameLayer\(index)"
        // Cone is centered on origin; shift so the wide base sits at the exhaust and the tip trails +Z.
        flame.position = SIMD3(0, 0, layer.z + layer.height * 0.5)
        root.addChild(flame)
    }

    for index in 0..<5 {
        let ember = makeEmberOrb(
            size: 0.006 + Float(index) * 0.0012,
            color: index % 2 == 0
                ? UIColor(red: 1.0, green: 0.55, blue: 0.08, alpha: 1)
                : UIColor(red: 1.0, green: 0.9, blue: 0.35, alpha: 1)
        )
        ember.name = "Ember\(index)"
        ember.position = SIMD3(
            Float.random(in: -0.008...0.008),
            Float.random(in: -0.004...0.006),
            0.03 + Float(index) * 0.012
        )
        root.addChild(ember)
    }

    let emitter = Entity()
    emitter.name = "BoostParticles"
    emitter.position = SIMD3(0, 0, 0.01)
    var particles = ParticleEmitterComponent.Presets.sparks
    particles.emitterShape = .sphere
    particles.emitterShapeSize = SIMD3(repeating: 0.006)
    particles.birthDirection = .local
    particles.emissionDirection = SIMD3(0, 0.05, 1)
    particles.particlesInheritTransform = true
    particles.isEmitting = true
    particles.simulationState = .play
    particles.speed = 0.35
    particles.speedVariation = 0.15
    particles.burstCount = 70
    particles.burstCountVariation = 15
    particles.mainEmitter.birthRate = 280
    particles.mainEmitter.lifeSpan = 0.4
    particles.mainEmitter.size = 0.012
    particles.mainEmitter.sizeVariation = 0.006
    particles.mainEmitter.spreadingAngle = 0.5
    particles.mainEmitter.blendMode = .additive
    particles.mainEmitter.color = .evolving(
        start: .single(.orange),
        end: .single(.yellow)
    )
    emitter.components.set(particles)
    root.addChild(emitter)

    return root
}

private func makeFlameCone(height: Float, radius: Float, color: UIColor, opacity: Float) -> ModelEntity {
    var material = UnlitMaterial(color: color)
    material.blending = .transparent(opacity: .init(floatLiteral: opacity))
    let cone = ModelEntity(
        mesh: .generateCone(height: height, radius: radius),
        materials: [material]
    )
    cone.orientation = BoostVFX.rearFacingOrientation
    cone.components.remove(CollisionComponent.self)
    return cone
}

private func makeEmberOrb(size: Float, color: UIColor) -> ModelEntity {
    var material = UnlitMaterial(color: color)
    material.blending = .transparent(opacity: .init(floatLiteral: 0.9))
    let orb = ModelEntity(
        mesh: .generateSphere(radius: size),
        materials: [material]
    )
    orb.components.remove(CollisionComponent.self)
    return orb
}

private extension ARSceneController {
    func updateBoostVFXAnimation(playerId: String) {
        guard let vfx = boostVFXEntities[playerId],
              let startedAt = boostVFXBurstStartedAt[playerId] else { return }
        let now = Date().timeIntervalSince1970
        let elapsed = now - startedAt
        let burstT = min(1, Float(elapsed / BoostVFX.burstDuration))
        let burstScale = BoostVFX.burstScale + (BoostVFX.sustainScale - BoostVFX.burstScale) * burstT

        let flicker = 1.0
            + 0.08 * sin(Float(elapsed) * 28)
            + 0.05 * sin(Float(elapsed) * 47 + 1.7)
        let scaleXZ = 0.85 * burstScale * flicker
        let scaleZ = 1.35 * burstScale * (0.92 + 0.12 * flicker)
        vfx.scale = SIMD3(scaleXZ, scaleXZ, scaleZ)

        for child in vfx.children where child.name.hasPrefix("Ember") {
            let phase = Float(abs(child.name.hashValue % 1000)) / 1000
            let drift = 0.004 * sin(Float(elapsed) * (10 + phase * 8) + phase * 6)
            child.position.x = drift
            child.position.y = abs(drift) * 0.4
            let pulse = 0.85 + 0.25 * sin(Float(elapsed) * (18 + phase * 10))
            child.scale = SIMD3(repeating: pulse)
        }
    }

    func triggerBoostParticleBurst(on vfx: Entity) {
        guard let emitter = vfx.children.first(where: { $0.name == "BoostParticles" }),
              var particles = emitter.components[ParticleEmitterComponent.self] else { return }
        particles.burst()
        emitter.components.set(particles)
    }

    func removeBoostVFX(for playerId: String) {
        boostVFXEntities[playerId]?.removeFromParent()
        boostVFXEntities.removeValue(forKey: playerId)
        boostVFXBurstStartedAt.removeValue(forKey: playerId)
    }
}

private extension simd_quatf {
    init(_ matrix: simd_float4x4) {
        self = simd_quaternion(matrix)
    }
}
