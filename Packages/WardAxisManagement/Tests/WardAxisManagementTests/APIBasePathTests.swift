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
    
    @Test
    func `The contract's servers path is /v1`() throws {
        #expect(try APIConfiguration.contractBasePath() == "/v1")
    }
    
    @Test(arguments: [
        (APIBasePathTests.debugHost, false, "http://127.0.0.1:8080/v1"),
        (APIBasePathTests.releaseHost, true, "https://api.invalid/v1"),
        ("https://api.invalid/", true, "https://api.invalid/v1")
    ])
    func `Debug and Release host-only values compose to a /v1 base URL`(rawValue: String, requiresHTTPS: Bool, expected: String) throws {
        let configuration = try APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: requiresHTTPS)
        
        #expect(configuration.baseURL.absoluteString == expected)
    }
    
    // MARK: - Stream URL
    
    @Test
    func `The configuration stream is /v1/config/stream on the Release host`() throws {
        let configuration = try APIConfiguration.resolve(rawValue: Self.releaseHost, requiresHTTPS: true)
        
        let request = try #require(ConfigurationStreamRequest.make(configuration: configuration))
        
        #expect(request.url?.absoluteString == "wss://api.invalid/v1/config/stream")
    }
    
    @Test
    func `The Debug loopback host gets no stream: the feed is mTLS only`() throws {
        let configuration = try APIConfiguration.resolve(rawValue: Self.debugHost, requiresHTTPS: false)
        
        #expect(ConfigurationStreamRequest.make(configuration: configuration) == nil)
    }
    
    // MARK: - Rejections
    
    @Test(arguments: [
        "https://api.invalid/v1",
        "https://api.invalid/v1/",
        "http://127.0.0.1:8080/v1",
        "https://api.invalid/api",
        "https://api.invalid//"
    ])
    func `A path in API_BASE_URL is malformed, so the prefix has one source`(rawValue: String) {
        #expect(throws: APIConfigurationError.malformed) {
            try APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: false)
        }
    }
    
    @Test(arguments: ["", "/", "v1", "/v1/", "//v1", "/v1//auth"])
    func `A servers path that cannot prefix routes is refused`(path: String) {
        #expect(throws: APIConfigurationError.invalidContractPath) {
            try APIConfiguration.validateContractPath(path)
        }
    }
    
    @Test(arguments: ["/v1", "/api/v1"])
    func `A nested servers path is accepted`(path: String) throws {
        #expect(try APIConfiguration.validateContractPath(path) == path)
    }
}
