//
//  HapticManager.swift
//  bikebike
//

import UIKit

@MainActor
enum HapticManager {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()

    static func countdownTick() {
        guard AudioPreferences.isHapticsEnabled else { return }
        light.prepare()
        light.impactOccurred()
    }

    static func raceStart() {
        guard AudioPreferences.isHapticsEnabled else { return }
        heavy.prepare()
        heavy.impactOccurred(intensity: 1.0)
    }

    static func boostActivated() {
        guard AudioPreferences.isHapticsEnabled else { return }
        rigid.prepare()
        rigid.impactOccurred(intensity: 1.0)
    }

    static func wallCollision() {
        guard AudioPreferences.isHapticsEnabled else { return }
        medium.prepare()
        medium.impactOccurred()
    }

    static func finishLine() {
        guard AudioPreferences.isHapticsEnabled else { return }
        notification.prepare()
        notification.notificationOccurred(.success)
    }
}
