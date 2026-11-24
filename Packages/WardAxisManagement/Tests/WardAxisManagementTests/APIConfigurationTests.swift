//
//  APIConfigurationTests.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisManagementTestSupport
@testable import WardAxisManagement

@Suite("APIConfiguration")
struct APIConfigurationTests {
    @Test("A local http URL is accepted when https is not required")
    func acceptsLocalHTTPInDebug() throws {
        let configuration = try APIConfiguration.resolve(rawValue: "http://localhost:8080", requiresHTTPS: false)

        #expect(configuration.baseURL.absoluteString == "http://localhost:8080/v1")
    }

    @Test("The Release placeholder https://api.invalid is accepted")
    func acceptsReleasePlaceholder() throws {
        let configuration = try APIConfiguration.resolve(rawValue: "https://api.invalid", requiresHTTPS: true)

        #expect(configuration.baseURL.host() == "api.invalid")
    }

    @Test("Surrounding whitespace is ignored")
    func trimsWhitespace() throws {
        let configuration = try APIConfiguration.resolve(rawValue: "  https://api.invalid\n", requiresHTTPS: true)

        #expect(configuration.baseURL.absoluteString == "https://api.invalid/v1")
    }

    @Test("A Release build rejects an http URL")
    func releaseRejectsHTTP() {
        #expect(throws: APIConfigurationError.insecureScheme) {
            try APIConfiguration.resolve(rawValue: "http://example.com", requiresHTTPS: true)
        }
    }

    @Test("Debug accepts http to a loopback host", arguments: ["http://localhost:8080", "http://127.0.0.1:8080", "http://[::1]:8080"])
    func debugAcceptsLoopbackHTTP(rawValue: String) {
        #expect(throws: Never.self) {
            try APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: false)
        }
    }

    @Test(
        "Debug rejects http to any other host",
        arguments: ["http://192.168.1.10:8080", "http://devbox.local:8080", "http://devbox:8080", "http://example.com"]
    )
    func debugRejectsRemoteHTTP(rawValue: String) {
        #expect(throws: APIConfigurationError.insecureScheme) {
            try APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: false)
        }
    }

    @Test("A missing or blank value is reported as missing", arguments: [nil, "", "   "] as [String?])
    func missingValue(rawValue: String?) {
        #expect(throws: APIConfigurationError.missing) {
            try APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: false)
        }
    }

    @Test(
        "An unusable value is reported as malformed",
        arguments: [
            "not a url",
            "/relative/path",
            "ftp://example.com",
            "https://user:secret@example.com",
            "https://example.com?debug=1",
            "https://example.com#fragment",
            "$(API_BASE_URL)"
        ]
    )
    func malformedValue(rawValue: String) {
        #expect(throws: APIConfigurationError.malformed) {
            try APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: false)
        }
    }
}
