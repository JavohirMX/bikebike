//
//  RaceTrackAssetLoader.swift
//  bikebike
//

import Combine
import Foundation
import os
import RealityKit
import UIKit

@MainActor
enum RaceTrackAssetLoader {
    private struct LoadedTrack {
        var templateEntity: Entity
        var templateGeometry: USDZTrackGeometry
    }

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "bikebike", category: "RaceTrackAssetLoader")

    private static var loadedTracks: [String: LoadedTrack] = [:]
    private static var preloadTask: Task<Void, Never>?
    private static var loadCancellables: [String: AnyCancellable] = [:]

    static func hasLoaded(trackId: String) -> Bool {
        loadedTracks[trackId] != nil
    }

    static func geometry(for trackId: String) -> USDZTrackGeometry? {
        loadedTracks[trackId]?.templateGeometry
    }

    static func preload() async {
        if loadedTracks.count == RaceTrackCatalog.usdzTracks.count {
            return
        }

        if let preloadTask {
            await preloadTask.value
            return
        }

        let task = Task { @MainActor in
            defer { preloadTask = nil }

            for definition in RaceTrackCatalog.usdzTracks {
                guard loadedTracks[definition.id] == nil else { continue }
                await loadTrack(definition)
            }
        }

        preloadTask = task
        await task.value
    }

    static func makeTrackEntity(for trackId: String, scale: Float) -> Entity? {
        guard let loaded = loadedTracks[trackId] else { return nil }
        let root = loaded.templateEntity.clone(recursive: true)
        root.scale = SIMD3(repeating: scale)
        USDZTrackGuideParser.hideCenterLine(in: root)
        return root
    }

    private static func loadTrack(_ definition: USDZTrackDefinition) async {
        let modelFileName = "\(definition.modelName).usdz"

        do {
            let loaded = try await loadTemplateEntity(modelName: definition.modelName)
            let prepared = prepareTrackRoot(from: loaded)

            if let guides = USDZTrackGuideParser.parseGuides(in: prepared),
               let geometry = USDZTrackGuideParser.buildGeometry(
                from: guides,
                definition: definition,
                relativeTo: prepared
               ) {
                loadedTracks[definition.id] = LoadedTrack(templateEntity: prepared, templateGeometry: geometry)
                logger.info("Loaded \(modelFileName, privacy: .public) using guide+curve-json")
            } else {
                let bounds = prepared.visualBounds(relativeTo: nil)
                guard let geometry = USDZTrackGeometry(
                    footprint: SIMD2(bounds.extents.x, bounds.extents.z),
                    presetId: definition.id,
                    displayName: definition.title
                ) else {
                    logger.error("Loaded \(modelFileName, privacy: .public) but could not derive track geometry")
                    return
                }
                loadedTracks[definition.id] = LoadedTrack(templateEntity: prepared, templateGeometry: geometry)
                logger.warning("Loaded \(modelFileName, privacy: .public) with footprint-fallback \(bounds.extents.x, privacy: .public)x\(bounds.extents.z, privacy: .public)")
            }
        } catch {
            logger.error("Preload failed for \(modelFileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func resolveModelURL(modelName: String) -> URL? {
        let modelFileName = "\(modelName).usdz"
        let subdirectoryCandidates: [String?] = ["Resources", nil]

        for subdirectory in subdirectoryCandidates {
            if let url = Bundle.main.url(
                forResource: modelName,
                withExtension: "usdz",
                subdirectory: subdirectory
            ) {
                return url
            }
        }

        if let url = findResource(named: modelFileName, in: Bundle.main.resourceURL) {
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

    private static func loadTemplateEntity(modelName: String) async throws -> Entity {
        guard let url = resolveModelURL(modelName: modelName) else {
            throw CarModelLoadError.modelNotFound(modelName)
        }

        return try await withCheckedThrowingContinuation { continuation in
            loadCancellables[modelName] = Entity.loadAsync(contentsOf: url)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            loadCancellables[modelName] = nil
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { entity in
                        loadCancellables[modelName] = nil
                        continuation.resume(returning: entity)
                    }
                )
        }
    }

    private static func prepareTrackRoot(from loaded: Entity) -> Entity {
        let root = Entity()
        root.name = "TrackRoot"

        // Blender USD exports often keep the tabletop layout in the XY plane; lay it on ARKit's XZ floor.
        loaded.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))

        let bounds = loaded.visualBounds(relativeTo: nil)
        let minY = bounds.center.y - bounds.extents.y / 2
        loaded.position = SIMD3(-bounds.center.x, -minY, -bounds.center.z)
        root.addChild(loaded)

        return root
    }
}

@MainActor
enum RaceTrackFactory {
    static var showsDebugBorders: Bool {
        #if DEBUG
        return !DeviceMemoryPolicy.isConstrained
        #else
        false
        #endif
    }

    static func preloadAssets() async {
        await RaceTrackAssetLoader.preload()
    }

    static func makePlacementGhost(for trackId: String, scale: Float) -> Entity {
        if DeviceMemoryPolicy.isConstrained {
            return makeTrackEntity(for: ProceduralTrack.presetId, scale: scale, opacity: 0.55)
        }
        return makeTrackEntity(for: trackId, scale: scale, opacity: 0.55)
    }

    static var usesFullTrackPlacementGhost: Bool {
        !DeviceMemoryPolicy.isConstrained
    }

    static func resolvedTrackId(for requestedTrackId: String) -> String {
        let normalized = RaceTrackCatalog.normalizedTrackId(requestedTrackId)
        if RaceTrackCatalog.isUSDZTrackId(normalized), RaceTrackAssetLoader.hasLoaded(trackId: normalized) {
            return normalized
        }
        if RaceTrackCatalog.isUSDZTrackId(normalized) {
            return ProceduralTrack.presetId
        }
        return normalized
    }

    static func geometry(for trackId: String, scale: Float = 1.0) -> any RaceTrackGeometry {
        let resolvedId = resolvedTrackId(for: trackId)
        let base: any RaceTrackGeometry
        if RaceTrackCatalog.isUSDZTrackId(resolvedId), let geometry = RaceTrackAssetLoader.geometry(for: resolvedId) {
            base = geometry
        } else {
            base = ProceduralTrackDefinition()
        }

        guard abs(scale - 1) > 0.0001 else { return base }
        if let usdz = base as? USDZTrackGeometry {
            return usdz.scaled(by: scale)
        }
        if let procedural = base as? ProceduralTrackDefinition {
            return procedural.scaled(by: scale)
        }
        return base
    }

    static func geometry(for trackId: String) -> any RaceTrackGeometry {
        geometry(for: trackId, scale: 1.0)
    }

    static func makeTrackEntity(for trackId: String, scale: Float, opacity: Float? = nil) -> Entity {
        let resolvedId = resolvedTrackId(for: trackId)

        let entity: Entity
        if RaceTrackCatalog.isUSDZTrackId(resolvedId),
           let loaded = RaceTrackAssetLoader.makeTrackEntity(for: resolvedId, scale: scale) {
            entity = loaded
        } else {
            entity = ProceduralTrack.makeOvalLoopTrack(scale: scale)
        }

        if let opacity {
            applyOpacity(opacity, to: entity)
        }

        if showsDebugBorders,
           let overlay = TrackDebugVisualizer.makeOverlay(for: geometry(for: trackId, scale: scale)) {
            entity.addChild(overlay)
        }

        return entity
    }

    static func stripOpacity(from entity: Entity) {
        entity.components.remove(OpacityComponent.self)
        for child in entity.children {
            stripOpacity(from: child)
        }
    }

    private static func applyOpacity(_ opacity: Float, to entity: Entity) {
        entity.components.set(OpacityComponent(opacity: opacity))
        for child in entity.children {
            applyOpacity(opacity, to: child)
        }
    }
}
