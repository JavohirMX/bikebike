//
//  BikeMovementModel.swift
//  bikebike
//

import simd

struct BikeMovementState {
    var speed: Float
    var pedalAmount: Float
    var yaw: Float
    var pitch: Float
    var roll: Float = 0
}

struct BikeMovementInput {
    var steer: Float
    var gasPressed: Bool
    var brake: Float
    var boostActive: Bool = false
}

struct BikeMovementResult {
    var localPosition: SIMD3<Float>
    var orientation: simd_quatf
    var speed: Float
    var pedalAmount: Float
    var yaw: Float
    var pitch: Float
    var roll: Float
    var hitWall: Bool
}

enum BikeMovementModel {
    static let maxSpeed: Float = 0.28 // was 0.35
    static let thrustForce: Float = 2.0 // was 2.5
    static let brakeForce: Float = 4.5
    static let rollingDrag: Float = 1.2
    static let wallSlideFriction: Float = 0.75
    static let boostThrustMultiplier: Float = 2.5
    static let boostSustainThrust: Float = 1.8

    static var boostedMaxSpeed: Float { maxSpeed * BoostState.speedMultiplier }

    static let maxYawRate: Float = 3.5 // was 2.8
    static let minSteerSpeed: Float = 0.05
    static let heightSmoothing: Float = 14
    static let pitchSmoothing: Float = 12
    static let leanSmoothing: Float = 5
    static let leanReturnSmoothing: Float = 14
    static let pedalRampUp: Float = 0.5
    static let pedalRampDown: Float = 1.5
    static let maxLean: Float = 0.35
    static let fallRecoveryThreshold: Float = 0.15

    static func integrate(
        state: BikeMovementState,
        input: BikeMovementInput,
        localPosition: SIMD3<Float>,
        trackGeometry: any RaceTrackGeometry,
        wheelbase: Float,
        hintArcLength: Float?,
        deltaTime: Float
    ) -> BikeMovementResult {
        var speed = state.speed
        var pedalAmount = state.pedalAmount
        var yaw = state.yaw
        var pitch = state.pitch
        var roll = state.roll
        var localPos = localPosition

        if input.gasPressed {
            pedalAmount = min(1, pedalAmount + pedalRampUp * deltaTime)
        } else {
            pedalAmount = max(0, pedalAmount - pedalRampDown * deltaTime)
        }

        let thrustMultiplier: Float = input.boostActive ? boostThrustMultiplier : 1.0
        if pedalAmount > 0.001 {
            speed += thrustForce * pedalAmount * thrustMultiplier * deltaTime
        } else if input.boostActive {
            speed += boostSustainThrust * deltaTime
        }
        if input.brake > 0.05 {
            speed -= brakeForce * input.brake * deltaTime
        }
        if pedalAmount <= 0.001, input.brake <= 0.05, !input.boostActive {
            speed *= exp(-rollingDrag * deltaTime)
        }

        let speedCap = input.boostActive ? boostedMaxSpeed : maxSpeed
        speed = max(0, min(speedCap, speed))
        if input.boostActive {
            speed = max(speed, boostedMaxSpeed * 0.9)
        }

        let steerFactor = speedSteerFactor(speed)
        if abs(input.steer) > 0.02, steerFactor > 0 {
            yaw -= input.steer * maxYawRate * steerFactor * deltaTime
        }

        let forwardXZ = forwardDirection(yaw: yaw)
        localPos.x += forwardXZ.x * speed * deltaTime
        localPos.z += forwardXZ.y * speed * deltaTime

        let clampResult = trackGeometry.clampToCorridor(localPos)
        var hitWall = false
        if clampResult.hitWall {
            localPos.x = clampResult.position.x
            localPos.z = clampResult.position.y
            speed *= wallSlideFriction
            hitWall = true
        }

        let halfWheelbase = wheelbase / 2
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

        let frontY = trackGeometry.surfaceHeight(at: frontSample, hintArcLength: hintArcLength)
        let rearY = trackGeometry.surfaceHeight(at: rearSample, hintArcLength: hintArcLength)
        let targetChassisY = (frontY + rearY) / 2
        let targetPitch = atan2(frontY - rearY, max(wheelbase, 0.001))

        let heightBlend = 1 - exp(-heightSmoothing * deltaTime)
        let pitchBlend = 1 - exp(-pitchSmoothing * deltaTime)
        localPos.y = simd_mix(localPos.y, targetChassisY, heightBlend)
        pitch = simd_mix(pitch, targetPitch, pitchBlend)

        if localPos.y < -fallRecoveryThreshold {
            localPos.y = targetChassisY
        }

        let targetRoll = -input.steer * maxLean * steerFactor
        let leanSmoothingRate = abs(input.steer) > 0.02 ? leanSmoothing : leanReturnSmoothing
        let leanBlend = 1 - exp(-leanSmoothingRate * deltaTime)
        roll = simd_mix(roll, targetRoll, leanBlend)
        let orientation = composeOrientation(yaw: yaw, pitch: pitch, roll: roll)

        return BikeMovementResult(
            localPosition: localPos,
            orientation: orientation,
            speed: speed,
            pedalAmount: pedalAmount,
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            hitWall: hitWall
        )
    }

    static func initialState(from orientation: simd_quatf) -> BikeMovementState {
        BikeMovementState(
            speed: 0,
            pedalAmount: 0,
            yaw: yaw(from: orientation),
            pitch: 0
        )
    }

    static func yaw(from orientation: simd_quatf) -> Float {
        let forward = orientation.act(SIMD3<Float>(0, 0, -1))
        return atan2(-forward.x, -forward.z)
    }

    private static func speedSteerFactor(_ speed: Float) -> Float {
        1.0
    }

    private static func forwardDirection(yaw: Float) -> SIMD2<Float> {
        SIMD2(-sin(yaw), -cos(yaw))
    }

    private static func composeOrientation(yaw: Float, pitch: Float, roll: Float) -> simd_quatf {
        let yawQuat = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
        let pitchQuat = simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0))
        let rollQuat = simd_quatf(angle: roll, axis: SIMD3(0, 0, 1))
        return yawQuat * pitchQuat * rollQuat
    }
}
