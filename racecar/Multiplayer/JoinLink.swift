//
//  JoinLink.swift
//  racecar
//

import Foundation

enum JoinLink {
    static let serviceType = NetworkSessionManager.serviceType

    static func buildURL(hostName: String) -> URL? {
        var components = URLComponents()
        components.scheme = "racecar"
        components.host = "join"
        components.queryItems = [
            URLQueryItem(name: "host", value: hostName),
            URLQueryItem(name: "service", value: serviceType),
        ]
        return components.url
    }

    static func parse(_ url: URL) -> String? {
        guard url.scheme == "racecar", url.host == "join" else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.queryItems?.first(where: { $0.name == "host" })?.value,
              !host.isEmpty else { return nil }
        return host
    }
}
