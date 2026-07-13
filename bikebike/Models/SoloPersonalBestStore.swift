//
//  SoloPersonalBestStore.swift
//  bikebike
//

import Foundation

enum SoloPersonalBestStore {
    private static let keyPrefix = "bikebike.soloPB."

    static func bestTotalTime(trackId: String, lapCount: Int) -> TimeInterval? {
        let value = UserDefaults.standard.double(forKey: storageKey(trackId: trackId, lapCount: lapCount))
        // UserDefaults returns 0 when missing; treat non-positive as absent.
        return value > 0 ? value : nil
    }

    /// Persists `time` when it is strictly better than the stored best (or first finish).
    /// Returns whether this run set a new personal best, and the standing best afterward.
    @discardableResult
    static func updateIfBetter(trackId: String, lapCount: Int, time: TimeInterval) -> (isNew: Bool, best: TimeInterval) {
        guard time > 0 else {
            let existing = bestTotalTime(trackId: trackId, lapCount: lapCount) ?? time
            return (false, existing)
        }

        let key = storageKey(trackId: trackId, lapCount: lapCount)
        if let previous = bestTotalTime(trackId: trackId, lapCount: lapCount) {
            if time < previous {
                UserDefaults.standard.set(time, forKey: key)
                return (true, time)
            }
            return (false, previous)
        }

        UserDefaults.standard.set(time, forKey: key)
        return (true, time)
    }

    private static func storageKey(trackId: String, lapCount: Int) -> String {
        "\(keyPrefix)\(trackId).laps\(lapCount)"
    }
}
