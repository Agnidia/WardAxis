//
//  APIBasePathTests.swift
//
//  Created on 16.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisManagementTestSupport
@testable import WardAxisManagement

/// The `/v1` prefix reaches every URL the app sends to, from one source: the contract's
/// `servers` URL. The oracles are literal strings, so a prefix from a wrong source fails here.
@Suite("API base path")
struct APIBasePathTests {
    /// The Debug and Release `API_BASE_URL` values from `Configurations/app`, which stay host-only.
    static let debugHost = "http://127.0.0.1:8080"
    static let releaseHost = "https://api.invalid"

    // MARK: - Composition

    @Test("The contract's servers path is /v1")
    func contractBasePathIsV1() throws {
        #expect(try APIConfiguration.contractBasePath() == "/v1")
    }

    @Test("Debug and Release host-only values compose to a /v1 base URL", arguments: [
        (APIBasePathTests.debugHost, false, "http://127.0.0.1:8080/v1"),
        (APIBasePathTests.releaseHost, true, "https://api.invalid/v1"),
        ("https://api.invalid/", true, "https://api.invalid/v1")
    ])
    func composedBaseURL(rawValue: String, requiresHTTPS: Bool, expected: String) throws {
        let configuration = try APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: requiresHTTPS)

        #expect(configuration.baseURL.absoluteString == expected)
    }

    // MARK: - Stream URL

    @Test("The configuration stream is /v1/config/stream on the Release host")
    func streamURL() throws {
        let configuration = try APIConfiguration.resolve(rawValue: Self.releaseHost, requiresHTTPS: true)

        let request = try #require(ConfigurationStreamRequest.make(configuration: configuration))

        #expect(request.url?.absoluteString == "wss://api.invalid/v1/config/stream")
    }

    @Test("The Debug loopback host gets no stream: the feed is mTLS only")
    func debugHostHasNoStream() throws {
        let configuration = try APIConfiguration.resolve(rawValue: Self.debugHost, requiresHTTPS: false)

        #expect(ConfigurationStreamRequest.make(configuration: configuration) == nil)
    }

    // MARK: - Rejections

    @Test("A path in API_BASE_URL is malformed, so the prefix has one source", arguments: [
        "https://api.invalid/v1",
        "https://api.invalid/v1/",
        "http://127.0.0.1:8080/v1",
        "https://api.invalid/api",
        "https://api.invalid//"
    ])
    func pathInBaseURLIsMalformed(rawValue: String) {
        #expect(throws: APIConfigurationError.malformed) {
            try APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: false)
        }
    }

    @Test("A servers path that cannot prefix routes is refused", arguments: ["", "/", "v1", "/v1/", "//v1", "/v1//auth"])
    func invalidContractPathIsRefused(path: String) {
        #expect(throws: APIConfigurationError.invalidContractPath) {
            try APIConfiguration.validateContractPath(path)
        }
    }

    @Test("A nested servers path is accepted", arguments: ["/v1", "/api/v1"])
    func validContractPathIsAccepted(path: String) throws {
        #expect(try APIConfiguration.validateContractPath(path) == path)
    }
}
