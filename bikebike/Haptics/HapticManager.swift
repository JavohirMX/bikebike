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
        light.prepare()
        light.impactOccurred()
    }

    static func raceStart() {
        heavy.prepare()
        heavy.impactOccurred(intensity: 1.0)
    }

    static func boostActivated() {
        rigid.prepare()
        rigid.impactOccurred(intensity: 1.0)
    }

    static func wallCollision() {
        medium.prepare()
        medium.impactOccurred()
    }

    static func finishLine() {
        notification.prepare()
        notification.notificationOccurred(.success)
    }
}
