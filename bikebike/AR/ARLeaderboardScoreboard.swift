//
//  ARLeaderboardScoreboard.swift
//  bikebike
//

import os
import RealityKit
import SwiftUI
import UIKit

@MainActor
final class ARLeaderboardScoreboard {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "bikebike",
        category: "ARLeaderboard"
    )

    private var pivotEntity: Entity?
    private var panelEntity: ModelEntity?
    private var cachedEntries: [LeaderboardEntry] = []
    private var cachedLocalPlayerId: String = ""
    private var cachedLapCount: Int = 3
    private var panelWidth: Float = 0.52
    private var panelHeight: Float = 0.39

    private static let textureSize = CGSize(width: 320, height: 240)
    private static let textureCornerRadius: CGFloat = 12

    var isAttached: Bool { pivotEntity != nil }

    func attach(
        to trackAnchor: AnchorEntity,
        geometry: any RaceTrackGeometry,
        scale: Float,
        entries: [LeaderboardEntry],
        localPlayerId: String,
        lapCount: Int
    ) {
        hide()

        panelWidth = 0.38 * scale
        panelHeight = panelWidth * (240.0 / 320.0)

        let pivot = Entity()
        pivot.name = "LeaderboardPivot"

        let cornerRadius = panelWidth * Float(Self.textureCornerRadius / Self.textureSize.width)
        let mesh = MeshResource.generatePlane(
            width: panelWidth,
            depth: panelHeight,
            cornerRadius: cornerRadius
        )
        let panel = ModelEntity(mesh: mesh, materials: [makePlaceholderMaterial()])
        panel.name = "LeaderboardPanel"
        panel.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))

        let placement = geometry.scoreboardPlacementFrame(panelWidth: panelWidth, scale: scale)
        pivot.position = placement.position

        pivot.addChild(panel)
        trackAnchor.addChild(pivot)
        pivotEntity = pivot
        panelEntity = panel

        cachedEntries = entries
        cachedLocalPlayerId = localPlayerId
        cachedLapCount = lapCount

        Self.logger.info(
            "Leaderboard attached at (\(placement.position.x), \(placement.position.y), \(placement.position.z)) size \(self.panelWidth)x\(self.panelHeight)"
        )

        applyTexture(
            entries: entries,
            localPlayerId: localPlayerId,
            lapCount: lapCount
        )
    }

    func update(entries: [LeaderboardEntry], localPlayerId: String, lapCount: Int) {
        cachedEntries = entries
        cachedLocalPlayerId = localPlayerId
        cachedLapCount = lapCount
        applyTexture(entries: entries, localPlayerId: localPlayerId, lapCount: lapCount)
    }

    func faceCamera(_ cameraWorldPosition: SIMD3<Float>) {
        guard let pivot = pivotEntity else { return }
        let worldPosition = pivot.position(relativeTo: nil)
        guard worldPosition.allFinite, cameraWorldPosition.allFinite else { return }

        var toCamera = cameraWorldPosition - worldPosition
        toCamera.y = 0
        guard simd_length_squared(toCamera) > 0.0001 else { return }

        let yaw = atan2(toCamera.x, toCamera.z)
        pivot.orientation = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
    }

    func hide() {
        pivotEntity?.removeFromParent()
        pivotEntity = nil
        panelEntity = nil
    }

    private func applyTexture(
        entries: [LeaderboardEntry],
        localPlayerId: String,
        lapCount: Int
    ) {
        Task { @MainActor in
            await applyTextureAsync(
                entries: entries,
                localPlayerId: localPlayerId,
                lapCount: lapCount
            )
        }
    }

    private func applyTextureAsync(
        entries: [LeaderboardEntry],
        localPlayerId: String,
        lapCount: Int
    ) async {
        guard let panel = panelEntity else { return }

        if let texture = await renderFallbackTexture(
            entries: entries,
            localPlayerId: localPlayerId,
            lapCount: lapCount
        ) {
            panel.model?.materials = [makeTexturedMaterial(texture: texture)]
            return
        }

        Self.logger.warning("CoreGraphics leaderboard bake failed; trying ImageRenderer")
        if let texture = await renderTexture(
            entries: entries,
            localPlayerId: localPlayerId,
            lapCount: lapCount
        ) {
            panel.model?.materials = [makeTexturedMaterial(texture: texture)]
            return
        }

        Self.logger.error("Leaderboard texture bake failed; using visible placeholder")
        panel.model?.materials = [makeDebugPlaceholderMaterial()]
    }

    private func makePlaceholderMaterial() -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor(red: 0.36, green: 0.73, blue: 1.0, alpha: 1))
        material.faceCulling = .none
        return material
    }

    private func makeTexturedMaterial(texture: TextureResource) -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(texture: .init(texture))
        material.faceCulling = .none
        return material
    }

    private func makeDebugPlaceholderMaterial() -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor(red: 0.36, green: 0.73, blue: 1.0, alpha: 1))
        material.faceCulling = .none
        return material
    }

    private func renderTexture(
        entries: [LeaderboardEntry],
        localPlayerId: String,
        lapCount: Int
    ) async -> TextureResource? {
        let view = ARLeaderboardPanelView(
            entries: entries,
            localPlayerId: localPlayerId,
            lapCount: lapCount,
            useSimplifiedRendering: true
        )
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: 320, height: 240)
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage else {
            Self.logger.warning("ImageRenderer returned nil cgImage")
            return nil
        }
        return await textureResource(from: cgImage)
    }

    private func renderFallbackTexture(
        entries: [LeaderboardEntry],
        localPlayerId: String,
        lapCount: Int
    ) async -> TextureResource? {
        let size = CGSize(width: 320, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let cream = UIColor(red: 0.92, green: 0.85, blue: 0.76, alpha: 1)
            let skyBlue = UIColor(red: 0.36, green: 0.73, blue: 1.0, alpha: 1)
            let darkBlue = UIColor(red: 0.10, green: 0.23, blue: 0.42, alpha: 1)
            let brown = UIColor(red: 0.29, green: 0.24, blue: 0.19, alpha: 1)
            let yellow = UIColor(red: 0.95, green: 0.84, blue: 0.09, alpha: 1)

            darkBlue.setStroke()
            let border = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 12)
            border.lineWidth = 3
            cream.setFill()
            border.fill()
            border.stroke()

            let headerRect = CGRect(x: 0, y: 0, width: size.width, height: 44)
            skyBlue.setFill()
            UIBezierPath(
                roundedRect: headerRect,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: 12, height: 12)
            ).fill()

            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: yellow
            ]
            let header = "Race Standings" as NSString
            let headerSize = header.size(withAttributes: headerAttributes)
            header.draw(
                at: CGPoint(
                    x: (size.width - headerSize.width) / 2,
                    y: (44 - headerSize.height) / 2
                ),
                withAttributes: headerAttributes
            )

            var y: CGFloat = 52
            let rowHeight: CGFloat = 28
            for entry in entries.prefix(6) {
                let isLocal = entry.playerId == localPlayerId
                let rowRect = CGRect(x: 10, y: y, width: size.width - 20, height: rowHeight)
                let rowPath = UIBezierPath(roundedRect: rowRect, cornerRadius: rowHeight / 2)
                (isLocal ? yellow.withAlphaComponent(0.5) : UIColor.white.withAlphaComponent(0.55)).setFill()
                rowPath.fill()

                let rankAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: entry.rank <= 3 ? UIColor.white : darkBlue
                ]
                let nameAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: brown
                ]
                let metaAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold),
                    .foregroundColor: entry.status == .dnf ? UIColor.red : brown
                ]

                let rankText = "\(entry.rank)" as NSString
                rankText.draw(at: CGPoint(x: rowRect.minX + 10, y: y + 7), withAttributes: rankAttributes)

                let name = entry.displayName as NSString
                name.draw(
                    in: CGRect(x: rowRect.minX + 34, y: y + 6, width: 120, height: 18),
                    withAttributes: nameAttributes
                )

                let lap = min(entry.currentLap + 1, lapCount)
                let lapText = "L\(lap)/\(lapCount)" as NSString
                lapText.draw(at: CGPoint(x: rowRect.maxX - 96, y: y + 7), withAttributes: metaAttributes)

                let timeText: String
                switch entry.status {
                case .dnf:
                    timeText = "DNF"
                case .finished:
                    timeText = formatRaceTime(entry.totalTime)
                default:
                    timeText = entry.totalTime > 0 ? formatRaceTime(entry.totalTime) : "--"
                }
                let timeNSString = timeText as NSString
                timeNSString.draw(at: CGPoint(x: rowRect.maxX - 52, y: y + 7), withAttributes: metaAttributes)

                y += rowHeight + 4
            }
        }

        guard let cgImage = image.cgImage else { return nil }
        return await textureResource(from: cgImage)
    }

    private func textureResource(from cgImage: CGImage) async -> TextureResource? {
        try? await TextureResource(image: cgImage, options: .init(semantic: .color))
    }

    private func formatRaceTime(_ time: TimeInterval) -> String {
        let total = Int(time)
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}
