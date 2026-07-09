//
//  CarModelLoader.swift
//  bikebike
//

import Combine
import Foundation
import os
import RealityKit
import UIKit

@MainActor
enum CarModelLoader {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "bikebike", category: "CarModelLoader")
    /// Scale the bike footprint relative to the invisible drive collider.
    private static let visualFitScale: Float = 1.35
    /// Blender export arrives pitched backward; stand it upright before fitting.
    private static let bikePitchOffset: Float = -.pi / 2
    private static let bikeYawOffset: Float = 0
    private static let bikeLift: Float = -0.002

    private static var templateEntities: [String: Entity] = [:]
    private static var preloadTasks: [String: Task<Void, Never>] = [:]
    private static var loadCancellables: [String: AnyCancellable] = [:]

    static func preload(driverId: String = DriverCatalog.default.id) async {
        if templateEntities[driverId] != nil {
            return
        }

        if let preloadTask = preloadTasks[driverId] {
            await preloadTask.value
            return
        }

        let task = Task { @MainActor in
            defer { preloadTasks[driverId] = nil }

            do {
                let loaded = try await loadTemplateEntity(driverId: driverId)
                templateEntities[driverId] = loaded
                logger.info("Loaded \(driverId, privacy: .public) on \(UIDevice.current.model, privacy: .public)")
            } catch {
                logger.error("Preload failed for \(driverId, privacy: .public) on \(UIDevice.current.model, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        preloadTasks[driverId] = task
        await task.value
    }

    static func preloadAll() async {
        for driver in DriverCatalog.all {
            await preload(driverId: driver.id)
        }
    }

    static func makeCar(driverId: String) async -> Entity {
        await preload(driverId: driverId)

        let driver = DriverCatalog.driver(for: driverId)
        guard let templateEntity = templateEntities[driverId] else {
            logger.warning("Using procedural fallback car — USDZ template unavailable for \(driverId, privacy: .public)")
            let color = UIColor(hex: driver.accentColorHex) ?? .systemRed
            return ProceduralTrack.makeCar(color: color)
        }

        let root = makeCarRoot()
        let visual = templateEntity.clone(recursive: true)
        prepareVisualEntity(visual)
        root.addChild(visual)
        return root
    }

    private static func resolveModelURL(for driverId: String) -> URL? {
        let driver = DriverCatalog.driver(for: driverId)
        let modelName = (driver.modelFileName as NSString).deletingPathExtension
        let subdirectoryCandidates: [String?] = ["Resources/drivers", "drivers", "Resources", nil]

        for subdirectory in subdirectoryCandidates {
            if let url = Bundle.main.url(
                forResource: modelName,
                withExtension: "usdz",
                subdirectory: subdirectory
            ) {
                logger.debug("Resolved model at \(url.path, privacy: .public)")
                return url
            }
        }

        if let url = findResource(named: driver.modelFileName, in: Bundle.main.resourceURL) {
            logger.debug("Resolved model via recursive search at \(url.path, privacy: .public)")
            return url
        }

        logger.error("Could not resolve \(driver.modelFileName, privacy: .public) in app bundle")
        return nil
    }

    private static func findResource(named fileName: String, in directory: URL?) -> URL? {
        guard let directory else { return nil }

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == fileName {
            return fileURL
        }

        return nil
    }

    private static func loadTemplateEntity(driverId: String) async throws -> Entity {
        guard let url = resolveModelURL(for: driverId) else {
            throw CarModelLoadError.modelNotFound(driverId)
        }

        return try await withCheckedThrowingContinuation { continuation in
            loadCancellables[driverId] = Entity.loadAsync(contentsOf: url)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            loadCancellables[driverId] = nil
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { entity in
                        loadCancellables[driverId] = nil
                        continuation.resume(returning: entity)
                    }
                )
        }
    }

    private static func makeCarRoot() -> Entity {
        let root = Entity()
        root.name = "Car"

        var collision = CollisionComponent(shapes: [.generateBox(size: OvalTrackGeometry.carSize)])
        collision.filter = CollisionFilter(
            group: .init(rawValue: 1),
            mask: [.init(rawValue: 2), .init(rawValue: 4)]
        )
        root.components.set(collision)

        var physics = PhysicsBodyComponent(
            massProperties: .init(mass: 1.5),
            material: .generate(friction: 0.8, restitution: 0.2),
            mode: .kinematic
        )
        physics.isRotationLocked = (true, false, true)
        root.components.set(physics)

        return root
    }

    private static var bikeOrientation: simd_quatf {
        let pitch = simd_quatf(angle: bikePitchOffset, axis: SIMD3(1, 0, 0))
        let yaw = simd_quatf(angle: bikeYawOffset, axis: SIMD3(0, 1, 0))
        return yaw * pitch
    }

    private static func prepareVisualEntity(_ visual: Entity) {
        visual.orientation = bikeOrientation

        let orientedBounds = visual.visualBounds(relativeTo: nil)
        let extents = orientedBounds.extents
        guard max(extents.x, extents.z) > 0.0001 else { return }

        let targetWidth = OvalTrackGeometry.carSize.x * visualFitScale
        let targetLength = OvalTrackGeometry.carSize.z * visualFitScale
        let scale = min(
            targetWidth / max(extents.x, 0.0001),
            targetLength / max(extents.z, 0.0001)
        )

        visual.scale = SIMD3(repeating: scale)

        let bounds = visual.visualBounds(relativeTo: nil)
        let minY = bounds.center.y - bounds.extents.y / 2
        visual.position = SIMD3(-bounds.center.x, -minY + bikeLift, -bounds.center.z)
    }
}

enum CarModelLoadError: LocalizedError {
    case modelNotFound(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            "Could not find \(name).usdz in app bundle"
        }
    }
}
