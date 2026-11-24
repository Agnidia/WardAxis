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
    @Test
    func `A local http URL is accepted when https is not required`() throws {
        let configuration = try APIConfiguration.resolve(rawValue: "http://localhost:8080", requiresHTTPS: false)
        
        #expect(configuration.baseURL.absoluteString == "http://localhost:8080/v1")
    }
    
    @Test
    func `The Release placeholder https://api.invalid is accepted`() throws {
        let configuration = try APIConfiguration.resolve(rawValue: "https://api.invalid", requiresHTTPS: true)
        
        #expect(configuration.baseURL.host() == "api.invalid")
    }
    
    @Test
    func `Surrounding whitespace is ignored`() throws {
        let configuration = try APIConfiguration.resolve(rawValue: "  https://api.invalid\n", requiresHTTPS: true)
        
        #expect(configuration.baseURL.absoluteString == "https://api.invalid/v1")
    }
    
    @Test
    func `A Release build rejects an http URL`() {
        #expect(throws: APIConfigurationError.insecureScheme) {
            try APIConfiguration.resolve(rawValue: "http://example.com", requiresHTTPS: true)
        }
    }
    
    @Test(arguments: ["http://localhost:8080", "http://127.0.0.1:8080", "http://[::1]:8080"])
    func `Debug accepts http to a loopback host`(rawValue: String) {
        #expect(throws: Never.self) {
            try APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: false)
        }
    }
    
    @Test(
        arguments: ["http://192.168.1.10:8080", "http://devbox.local:8080", "http://devbox:8080", "http://example.com"]
    )
    func `Debug rejects http to any other host`(rawValue: String) {
        #expect(throws: APIConfigurationError.insecureScheme) {
            try APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: false)
        }
    }
    
    @Test(arguments: [nil, "", "   "] as [String?])
    func `A missing or blank value is reported as missing`(rawValue: String?) {
        #expect(throws: APIConfigurationError.missing) {
            try APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: false)
        }
    }
    
    @Test(
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
    func `An unusable value is reported as malformed`(rawValue: String) {
        #expect(throws: APIConfigurationError.malformed) {
            try APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: false)
        }
    }
}
