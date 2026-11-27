//
//  ApplicationMatcherTests.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Testing
import WardAxisCore

@Suite("Application matcher validation")
struct ApplicationMatcherTests {
    private func matcher(bundleIdentifier: String?) -> ApplicationMatcher {
        ApplicationMatcher(signingIdentifier: "com.example.browser", teamIdentifier: "EXAMPLE001", isPlatformBinary: false, bundleIdentifier: bundleIdentifier)
    }
    
    @Test(arguments: [nil, "com.example.browser", String(repeating: "a", count: SchemaLimits.maximumSigningIdentifierLength)])
    func `A pinned matcher with a well-formed or absent bundle ID is valid`(bundleIdentifier: String?) throws {
        try matcher(bundleIdentifier: bundleIdentifier).validate(at: "$")
    }
    
    @Test(arguments: [
        "",
        ".com.example",
        "com.example/browser",
        "com.example.browser\u{0}",
        "com.exämple.browser",
        String(repeating: "a", count: SchemaLimits.maximumSigningIdentifierLength + 1)
    ])
    func `A malformed bundle ID is refused at its path`(bundleIdentifier: String) {
        #expect(throws: SchemaViolation(path: "$.bundleIdentifier", reason: .malformedIdentifier)) {
            try matcher(bundleIdentifier: bundleIdentifier).validate(at: "$")
        }
    }
    
    @Test
    func `A bundle ID does not replace the Team ID pin`() {
        let unpinned = ApplicationMatcher(signingIdentifier: "com.example.browser", teamIdentifier: nil, isPlatformBinary: false, bundleIdentifier: "com.example.browser")
        #expect(throws: SchemaViolation(path: "$.teamIdentifier", reason: .missingRequired)) {
            try unpinned.validate(at: "$")
        }
    }
}
