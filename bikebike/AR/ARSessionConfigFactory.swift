//
//  ARSessionConfigFactory.swift
//  bikebike
//

import ARKit

enum ARSessionConfigFactory {
    static func makeWorldConfig(
        planeDetection: Bool,
        initialWorldMap: ARWorldMap? = nil
    ) -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = planeDetection ? [.horizontal] : []
        // Reflections are cosmetic here; automatic probes accumulate texture memory over time.
        config.environmentTexturing = .none
        config.initialWorldMap = initialWorldMap

        if let lowest = lowestMemoryVideoFormat() {
            config.videoFormat = lowest
        }
        return config
    }

    private static func lowestMemoryVideoFormat() -> ARConfiguration.VideoFormat? {
        let formats = ARWorldTrackingConfiguration.supportedVideoFormats
        let candidates = DeviceMemoryPolicy.isConstrained
            ? formats.filter { $0.framesPerSecond <= 30 }
            : formats
        let pool = candidates.isEmpty ? formats : candidates

        return pool.min { lhs, rhs in
            let lhsPixels = lhs.imageResolution.width * lhs.imageResolution.height
            let rhsPixels = rhs.imageResolution.width * rhs.imageResolution.height
            if lhsPixels != rhsPixels {
                return lhsPixels < rhsPixels
            }
            return lhs.framesPerSecond < rhs.framesPerSecond
        }
    }
}
