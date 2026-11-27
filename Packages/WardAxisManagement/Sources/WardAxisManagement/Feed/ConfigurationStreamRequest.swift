//
//  ConfigurationStreamRequest.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisAPIContract

/// Builds the `GET /v1/config/stream` WebSocket upgrade request.
enum ConfigurationStreamRequest {
    /// Relative to ``APIConfiguration/baseURL``, which already carries the contract prefix.
    static let path = ConfigStream.path
    
    /// The upgrade request, or `nil` when no connection may be attempted.
    ///
    /// Only `https` (sent as `wss`) is accepted, for every host and build: the
    /// feed authenticates in the TLS handshake, so a cleartext socket could never
    /// carry the identity and would only leak that the device is managed.
    static func make(configuration: APIConfiguration?) -> URLRequest? {
        guard let configuration else {
            return nil
        }
        let url = configuration.baseURL.appending(path: path, directoryHint: .notDirectory)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false
        else {
            return nil
        }
        components.scheme = "wss"
        components.query = nil
        components.fragment = nil
        guard let streamURL = components.url else {
            return nil
        }
        return URLRequest(url: streamURL)
    }
}
