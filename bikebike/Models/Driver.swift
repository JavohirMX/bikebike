//
//  Driver.swift
//  bikebike
//

import UIKit

struct Driver: Identifiable, Codable, Equatable {
    let id: String
    let displayName: String
    let modelFileName: String
    let accentColorHex: String
    let imageName: String
}

enum DriverCatalog {
    static let placeholderImageName = "driver-talin"
    private static let selectedDriverDefaultsKey = "selectedDriverId"

    static let all: [Driver] = [
        Driver(id: "talin", displayName: "Talin", modelFileName: "bike-talin.usdz", accentColorHex: "#FF3B30", imageName: "driver-talin"),
        Driver(id: "ish", displayName: "Ish", modelFileName: "bike-ish.usdz", accentColorHex: "#FF9500", imageName: "driver-ish"),
        Driver(id: "ana", displayName: "Ana", modelFileName: "bike-ana.usdz", accentColorHex: "#FF375F", imageName: "driver-ana"),
        Driver(id: "ivan", displayName: "Ivan", modelFileName: "bike-ivan.usdz", accentColorHex: "#AF52DE", imageName: "driver-ivan"),
        Driver(id: "john", displayName: "John", modelFileName: "bike-john.usdz", accentColorHex: "#007AFF", imageName: "driver-john"),
        Driver(id: "baeni", displayName: "Baeni", modelFileName: "bike-baeni.usdz", accentColorHex: "#FFCC00", imageName: "driver-baeni"),
    ]

    static let `default` = all[0]

    static func driver(for id: String?) -> Driver {
        guard let id, let match = all.first(where: { $0.id == id }) else { return `default` }
        return match
    }

    static func accentColorHex(for driverId: String?) -> String {
        driver(for: driverId).accentColorHex
    }

    static func resolvedImageName(for driver: Driver) -> String {
        if UIImage(named: driver.imageName) != nil {
            return driver.imageName
        }
        return placeholderImageName
    }

    static func resolvedImageName(forDriverId driverId: String?) -> String {
        resolvedImageName(for: driver(for: driverId))
    }

    static func takenDriverIds(by players: [PlayerProfile], excluding peerId: String?) -> Set<String> {
        Set(players.compactMap { player in
            guard player.peerId != peerId else { return nil }
            return player.driverId
        })
    }

    static func firstAvailableDriverId(excluding taken: Set<String>) -> String {
        all.first { !taken.contains($0.id) }?.id ?? `default`.id
    }

    static func loadPersistedDriverId() -> String {
        let stored = UserDefaults.standard.string(forKey: selectedDriverDefaultsKey)
        return driver(for: stored).id
    }

    static func persistDriverId(_ driverId: String) {
        UserDefaults.standard.set(driverId, forKey: selectedDriverDefaultsKey)
    }
}
