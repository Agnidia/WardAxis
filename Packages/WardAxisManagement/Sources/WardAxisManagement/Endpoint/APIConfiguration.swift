//
//  APIConfiguration.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisAPIClient
import WardAxisAPIContract

/// The server base URL, validated.
///
/// The host comes from the `API_BASE_URL` build setting through the
/// `APIBaseURL` Info.plist key, so no host is compiled into source. The path
/// prefix comes from the contract's `servers` URL, so the spec is its only source.
public struct APIConfiguration: Sendable, Equatable {
    /// Info.plist key that carries the `API_BASE_URL` build setting.
    public static let infoPlistKey: String = "APIBaseURL"
    
    /// Release builds accept only `https`; Debug also accepts `http` to a loopback host.
    public static var requiresHTTPS: Bool {
#if DEBUG
        false
#else
        true
#endif
    }
    
    /// Hosts that `http` may reach when https is not required. A LAN or `.local`
    /// host would carry credentials in cleartext over a shared network, and ATS
    /// exempts such hosts, so it would not stop them either.
    static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]"]
    
    /// The host of `API_BASE_URL` followed by ``contractBasePath()``, for example
    /// `https://api.invalid/v1`. The HTTP client and the configuration stream both
    /// append their operation paths to it.
    public let baseURL: URL
    
    /// Validates a raw base URL string and composes ``baseURL`` from it.
    ///
    /// Accepts an absolute `https` URL with a host, or `http` to a loopback host
    /// when `requiresHTTPS` is `false`. Rejects embedded credentials, a query and
    /// a fragment, because the client appends operation paths to this URL and
    /// would send those parts with every request. Rejects a path other than `/`,
    /// so the contract stays the only source of the prefix and no value can
    /// produce `/v1/v1`.
    public static func resolve(rawValue: String?, requiresHTTPS: Bool) throws(APIConfigurationError) -> APIConfiguration {
        guard let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            throw .missing
        }
        guard var components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.percentEncodedPath.isEmpty || components.percentEncodedPath == "/"
        else {
            throw .malformed
        }
        switch scheme {
        case "https":
            break
        case "http":
            if requiresHTTPS || !loopbackHosts.contains(host.lowercased()) {
                throw .insecureScheme
            }
        default:
            throw .malformed
        }
        components.percentEncodedPath = try contractBasePath()
        guard let url = components.url else {
            throw .malformed
        }
        return APIConfiguration(baseURL: url)
    }
    
    /// The path every API route is served under: the path of the contract's
    /// `servers` URL, `/v1`.
    ///
    /// - Throws: ``APIConfigurationError/invalidContractPath`` when the generated
    ///   URL cannot be built or its path fails ``validateContractPath(_:)``.
    static func contractBasePath() throws(APIConfigurationError) -> String {
        let serverURL: URL
        do {
            serverURL = try WardAxisAPIClient.Servers.Server1.url()
        } catch {
            throw .invalidContractPath
        }
        // Percent-encoded: `URL.path` drops a trailing slash, which must fail here.
        return try validateContractPath(serverURL.path(percentEncoded: true))
    }
    
    /// Applies ``APIBasePathRule``, the rule the server applies to the same path.
    static func validateContractPath(_ path: String) throws(APIConfigurationError) -> String {
        guard APIBasePathRule.isValid(path) else {
            throw .invalidContractPath
        }
        return path
    }
}

/// Why a base URL was rejected. Holds no part of the value, so it is safe to log.
public enum APIConfigurationError: Error, Equatable {
    case missing
    case malformed
    case insecureScheme
    /// The contract's `servers` path cannot prefix routes: a build defect, not a setting.
    case invalidContractPath
}
