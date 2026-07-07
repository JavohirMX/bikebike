//
//  CarModelLoader.swift
//  racecar
//

import Combine
import Foundation
import os
import RealityKit
import UIKit

@MainActor
enum CarModelLoader {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "racecar", category: "CarModelLoader")
    private static let modelName = "bike-talin"
    private static let modelFileName = "bike-talin.usdz"
    /// Scale the bike footprint relative to the invisible drive collider.
    private static let visualFitScale: Float = 1.35
    /// Blender export arrives pitched backward; stand it upright before fitting.
    private static let bikePitchOffset: Float = -.pi / 2
    private static let bikeYawOffset: Float = 0
    private static let bikeLift: Float = -0.002

    private static var templateEntity: Entity?
    private static var preloadTask: Task<Void, Never>?
    private static var loadCancellable: AnyCancellable?

    static func preload() async {
        if templateEntity != nil {
            return
        }

        if let preloadTask {
            await preloadTask.value
            return
        }

        let task = Task { @MainActor in
            defer { preloadTask = nil }

            do {
                let loaded = try await loadTemplateEntity()
                templateEntity = loaded
                logger.info("Loaded \(modelName, privacy: .public) on \(UIDevice.current.model, privacy: .public)")
            } catch {
                logger.error("Preload failed on \(UIDevice.current.model, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        preloadTask = task
        await task.value
    }

    static func makeCar(color: UIColor) async -> Entity {
        await preload()

        guard let templateEntity else {
            logger.warning("Using procedural fallback car — USDZ template unavailable")
            return ProceduralTrack.makeCar(color: color)
        }

        let root = makeCarRoot()
        let visual = templateEntity.clone(recursive: true)
        prepareVisualEntity(visual, color: color)
        root.addChild(visual)
        return root
    }

    private static func resolveModelURL() -> URL? {
        let subdirectoryCandidates: [String?] = ["Resources", nil]

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

        if let url = findResource(named: modelFileName, in: Bundle.main.resourceURL) {
            logger.debug("Resolved model via recursive search at \(url.path, privacy: .public)")
            return url
        }

        logger.error("Could not resolve \(modelFileName, privacy: .public) in app bundle")
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

    private static func loadTemplateEntity() async throws -> Entity {
        guard let url = resolveModelURL() else {
            throw CarModelLoadError.modelNotFound(modelName)
        }

        return try await withCheckedThrowingContinuation { continuation in
            loadCancellable = Entity.loadAsync(contentsOf: url)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            loadCancellable = nil
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { entity in
                        loadCancellable = nil
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

    private static func prepareVisualEntity(_ visual: Entity, color: UIColor) {
        applyPlayerTintIfPossible(to: visual, color: color)

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

    private static func applyPlayerTintIfPossible(to entity: Entity, color: UIColor) {
        for descendant in recursiveEntities(startingAt: entity) {
            guard let model = descendant as? ModelEntity else { continue }
            let loweredName = model.name.lowercased()
            guard shouldTintEntity(named: loweredName) else { continue }

            guard var modelComponent = model.model else { continue }
            modelComponent.materials = modelComponent.materials.map { material in
                let isMetallic = materialNameSuggestsMetal(loweredName)
                return SimpleMaterial(color: color, roughness: 0.35, isMetallic: isMetallic)
            }
            model.model = modelComponent
        }
    }

    private static func recursiveEntities(startingAt entity: Entity) -> [Entity] {
        var result: [Entity] = []

        func visit(_ current: Entity) {
            result.append(current)
            for child in current.children {
                visit(child)
            }
        }

        visit(entity)
        return result
    }

    private static func shouldTintEntity(named name: String) -> Bool {
        if name.isEmpty {
            return true
        }

        let excludedTerms = ["wheel", "tire", "tyre", "glass", "window", "light", "disc", "rim", "chain", "seat", "handle"]
        if excludedTerms.contains(where: { name.contains($0) }) {
            return false
        }

        let includedTerms = ["body", "frame", "fairing", "tank", "panel", "paint", "shell", "bike", "car"]
        return includedTerms.contains(where: { name.contains($0) })
    }

    private static func materialNameSuggestsMetal(_ name: String) -> Bool {
        ["frame", "panel", "fairing", "tank", "shell"].contains(where: { name.contains($0) })
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
