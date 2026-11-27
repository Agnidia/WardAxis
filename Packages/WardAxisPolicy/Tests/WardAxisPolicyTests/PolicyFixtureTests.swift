//
//  PolicyFixtureTests.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisCore
import WardAxisPolicy
import WardAxisPolicyTestSupport

enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}

/// Expects `decode` to throw exactly `expected`.
private func expectRefusal(fixture: String, _ expected: SchemaError) throws {
    let data = try Fixture.data(fixture)
    #expect(throws: expected) {
        try SchemaCodec.decode(SecurityPolicy.self, from: data)
    }
}

@Suite("Policy fixtures")
struct PolicyFixtureTests {
    // MARK: - Valid documents
    
    @Test
    func `A valid policy decodes to a typed policy with its version, mode and rules`() throws {
        let policy = try SchemaCodec.decode(SecurityPolicy.self, from: Fixture.data("policy.v1"))
        
        #expect(SecurityPolicy.currentVersion == SchemaVersion.v1)
        #expect(policy.identifier == "office-network")
        #expect(policy.revision == 7)
        #expect(policy.mode == .enforce)
        #expect(policy.defaultAction == .deny)
        #expect(policy.rules.map(\.identifier) == ["browser-web", "system-curl", "block-tracker", "block-test-networks"])
        #expect(policy.rules.map(\.priority) == [100, 50, 900, 800])
        #expect(policy.rules.map(\.enabled) == [true, true, true, false])
        #expect(policy.rules[0].match == PolicyMatch(
            application: ApplicationMatcher(
                signingIdentifier: "com.example.browser",
                teamIdentifier: "EXAMPLE001",
                isPlatformBinary: false,
                bundleIdentifier: "com.example.browser"
            ),
            destinationHosts: ["example.com", "*.example.org"],
            transport: .tcp,
            destinationPorts: [PortRange(first: 443, last: 443), PortRange(first: 8000, last: 8099)]
        ))
        #expect(policy.rules[1].match.application?.isPlatformBinary == true)
        #expect(policy.rules[2].match == PolicyMatch(destinationHosts: ["tracker.example.net"]))
        #expect(policy.rules[3].match.destinationNetworks == ["198.51.100.0/24", "2001:db8::/32", "0.0.0.0/0"])
        #expect(policy.rules[3].match.transport == .udp)
    }
    
    @Test
    func `An audit policy decodes with its mode`() throws {
        let policy = try SchemaCodec.decode(SecurityPolicy.self, from: Fixture.data("policy-audit.v1"))
        #expect(policy.mode == .audit)
    }
    
    @Test(arguments: ["policy.v1", "policy-audit.v1"])
    func `A valid policy survives encode and decode unchanged`(fixture: String) throws {
        let policy = try SchemaCodec.decode(SecurityPolicy.self, from: Fixture.data(fixture))
        let encoded = try SchemaCodec.encode(policy)
        #expect(try SchemaCodec.decode(SecurityPolicy.self, from: encoded) == policy)
    }
    
    @Test
    func `The fixture policy source applies every codec refusal`() async throws {
        let valid = try FixturePolicySource(data: Fixture.data("policy.v1"))
        let newer = try FixturePolicySource(data: Fixture.data("policy-unknown-version"))
        
        #expect(try await valid.currentPolicy().identifier == "office-network")
        await #expect(throws: SchemaError.unsupportedVersion(2, supported: SchemaVersion.onlyV1)) {
            try await newer.currentPolicy()
        }
    }
    
    // MARK: - Envelope
    
    @Test
    func `A policy with an unknown schema version is refused with a typed error`() throws {
        try expectRefusal(fixture: "policy-unknown-version", .unsupportedVersion(2, supported: SchemaVersion.onlyV1))
    }
    
    @Test
    func `A document of another schema is refused, so an event never passes as a policy`() throws {
        try expectRefusal(fixture: "policy-wrong-kind", .wrongKind(expected: .securityPolicy))
        let policy = try Fixture.data("policy.v1")
        #expect(throws: SchemaError.wrongKind(expected: .securityEvent)) {
            try SchemaCodec.decode(SecurityEvent.self, from: policy)
        }
    }
    
    @Test(arguments: ["policy-missing-version", "policy-version-as-string"])
    func `An envelope without an integer version is malformed`(fixture: String) throws {
        try expectRefusal(fixture: fixture, .malformed)
    }
    
    @Test
    func `An unknown envelope field is refused, so no unchecked signature claim passes`() throws {
        try expectRefusal(fixture: "policy-unknown-envelope-field", .unknownField(path: "$"))
    }
    
    // MARK: - Shape
    
    @Test(arguments: [
        ("policy-wrong-shape", "$.body.rules"),
        ("policy-unknown-action", "$.body.rules[0].action"),
        ("policy-missing-mode", "$.body.mode"),
        ("policy-unknown-mode", "$.body.mode"),
        ("policy-missing-priority", "$.body.rules[0].priority"),
        ("policy-missing-enabled", "$.body.rules[0].enabled"),
        ("policy-rule-without-criteria", "$.body.rules[0].match"),
        ("policy-unknown-transport", "$.body.rules[0].match.transport")
    ])
    func `A missing required field or an unknown case is a wrong shape, never a default`(fixture: String, path: String) throws {
        try expectRefusal(fixture: fixture, .wrongShape(path: path))
    }
    
    @Test
    func `A misspelled optional criterion is refused instead of ignored`() throws {
        try expectRefusal(fixture: "policy-unknown-field", .unknownField(path: "$.body.rules[0].match"))
    }
    
    @Test
    func `An explicit null for an optional criterion is refused`() throws {
        try expectRefusal(fixture: "policy-null-optional", .unknownField(path: "$.body.rules[0].match"))
    }
    
    @Test(arguments: ["policy-duplicate-key", "policy-duplicate-escaped-key"])
    func `A repeated key is refused, so every parser reads the same policy`(fixture: String) throws {
        try expectRefusal(fixture: fixture, .duplicateField)
    }
    
    @Test
    func `A plain JSONDecoder cannot decode a policy and skip the codec's checks`() throws {
        let policy = try Fixture.data("policy-unknown-field")
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SchemaDocument<SecurityPolicy>.self, from: policy)
        }
    }
    
    // MARK: - Validation
    
    @Test(arguments: [
        ("policy-empty-match", SchemaViolation(path: "$.body.rules[0].match", reason: .missingRequired)),
        ("policy-unpinned-application", SchemaViolation(path: "$.body.rules[0].match.application.teamIdentifier", reason: .missingRequired)),
        ("policy-malformed-bundle-identifier", SchemaViolation(path: "$.body.rules[0].match.application.bundleIdentifier", reason: .malformedIdentifier)),
        ("policy-duplicate-rule", SchemaViolation(path: "$.body.rules[1].identifier", reason: .duplicate)),
        ("policy-uppercase-host", SchemaViolation(path: "$.body.rules[0].match.destinationHosts[1]", reason: .malformedHost)),
        ("policy-tld-wildcard", SchemaViolation(path: "$.body.rules[0].match.destinationHosts[0]", reason: .malformedHost)),
        ("policy-revision-zero", SchemaViolation(path: "$.body.revision", reason: .outOfRange)),
        ("policy-priority-negative", SchemaViolation(path: "$.body.rules[0].priority", reason: .outOfRange)),
        ("policy-priority-too-high", SchemaViolation(path: "$.body.rules[0].priority", reason: .outOfRange)),
        ("policy-empty-networks", SchemaViolation(path: "$.body.rules[0].match.destinationNetworks", reason: .missingRequired)),
        ("policy-network-duplicate", SchemaViolation(path: "$.body.rules[0].match.destinationNetworks[1]", reason: .duplicate)),
        ("policy-port-zero", SchemaViolation(path: "$.body.rules[0].match.destinationPorts[0]", reason: .outOfRange)),
        ("policy-port-too-high", SchemaViolation(path: "$.body.rules[0].match.destinationPorts[0]", reason: .outOfRange)),
        ("policy-port-inverted", SchemaViolation(path: "$.body.rules[0].match.destinationPorts[0]", reason: .outOfRange)),
        ("policy-port-duplicate", SchemaViolation(path: "$.body.rules[0].match.destinationPorts[1]", reason: .duplicate))
    ])
    func `A policy that breaks a rule is refused at the offending path`(fixture: String, violation: SchemaViolation) throws {
        try expectRefusal(fixture: fixture, .invalid(violation))
    }
    
    @Test(arguments: [
        "policy-network-host-bits",
        "policy-network-leading-zero",
        "policy-network-prefix-leading-zero",
        "policy-network-ipv4-prefix-too-long",
        "policy-network-ipv6-prefix-too-long",
        "policy-network-ipv6-noncanonical",
        "policy-network-ipv6-host-bits",
        "policy-network-zone",
        "policy-network-mapped-ipv4",
        "policy-network-missing-prefix"
    ])
    func `A network in any but its one canonical CIDR spelling is refused`(fixture: String) throws {
        try expectRefusal(fixture: fixture, .invalid(SchemaViolation(path: "$.body.rules[0].match.destinationNetworks[1]", reason: .malformedNetwork)))
    }
}
