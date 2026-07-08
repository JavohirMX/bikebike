//
//  RaceTrackCenterlineLoader.swift
//  bikebike
//

import Foundation
import os
import simd

struct RaceTrackCenterlineDocument: Decodable {
    let pointCount: Int
    let closed: Bool
    let points: [[Float]]
}

enum RaceTrackCenterlineLoader {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "bikebike",
        category: "RaceTrackCenterlineLoader"
    )

    private static let fileName = "racetrack_centerline"
    private static let fileExtension = "json"

    static func loadPoints() -> [SIMD3<Float>]? {
        guard let url = resolveURL() else {
            logger.error("Could not resolve \(fileName, privacy: .public).\(fileExtension, privacy: .public) in app bundle")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let document = try JSONDecoder().decode(RaceTrackCenterlineDocument.self, from: data)
            let points = document.points.compactMap { values -> SIMD3<Float>? in
                guard values.count == 3 else { return nil }
                return SIMD3(values[0], values[1], values[2])
            }

            guard points.count >= 8 else {
                logger.error("Centerline JSON produced too few points (\(points.count, privacy: .public))")
                return nil
            }

            logger.info("Loaded \(points.count, privacy: .public) centerline points from JSON")
            return points
        } catch {
            logger.error("Failed to load centerline JSON: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func resolveURL() -> URL? {
        let subdirectoryCandidates: [String?] = ["Resources", nil]
        for subdirectory in subdirectoryCandidates {
            if let url = Bundle.main.url(
                forResource: fileName,
                withExtension: fileExtension,
                subdirectory: subdirectory
            ) {
                return url
            }
        }
        return nil
    }
}
