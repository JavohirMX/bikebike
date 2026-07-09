//
//  AudioPreferences.swift
//  bikebike
//

import Foundation

enum AudioPreferences {
    static let musicEnabledKey = "bikebike.musicEnabled"
    static let sfxEnabledKey = "bikebike.sfxEnabled"
    static let hapticsEnabledKey = "bikebike.hapticsEnabled"

    static var isMusicEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: musicEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: musicEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: musicEnabledKey)
            NotificationCenter.default.post(name: .audioPreferencesChanged, object: nil)
        }
    }

    static var isSFXEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: sfxEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: sfxEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: sfxEnabledKey)
            NotificationCenter.default.post(name: .audioPreferencesChanged, object: nil)
        }
    }

    static var isHapticsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: hapticsEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: hapticsEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hapticsEnabledKey)
            NotificationCenter.default.post(name: .audioPreferencesChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let audioPreferencesChanged = Notification.Name("bikebike.audioPreferencesChanged")
}
