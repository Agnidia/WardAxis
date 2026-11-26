//
//  SchemaFixtureTests.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisCore

enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}

/// Expects `decode` to throw exactly `expected`.
private func expectRefusal<Body: SchemaBody>(_: Body.Type, fixture: String, _ expected: SchemaError) throws {
    let data = try Fixture.data(fixture)
    #expect(throws: expected) {
        try SchemaCodec.decode(Body.self, from: data)
    }
}

@Suite("Schema fixtures")
struct SchemaFixtureTests {
    // MARK: - Valid documents
    
    @Test
    func `The policy fixture decodes with its rules in order`() throws {
        let policy = try SchemaCodec.decode(SecurityPolicy.self, from: Fixture.data("policy.v1"))
        
        #expect(policy.identifier == "office-network")
        #expect(policy.revision == 7)
        #expect(policy.defaultAction == .deny)
        #expect(policy.rules.map(\.identifier) == ["browser-web", "system-curl", "block-tracker"])
        #expect(policy.rules[0].application == ApplicationMatcher(signingIdentifier: "com.example.browser", teamIdentifier: "EXAMPLE001", isPlatformBinary: false))
        #expect(policy.rules[1].application?.isPlatformBinary == true)
        #expect(policy.rules[2].application == nil)
        #expect(policy.rules[2].destinationHosts == ["tracker.example.net"])
    }
    
    @Test
    func `The event fixtures decode with their kind and provenance`() throws {
        let flow = try SchemaCodec.decode(SecurityEvent.self, from: Fixture.data("event-flow-decision.v1"))
        let applied = try SchemaCodec.decode(SecurityEvent.self, from: Fixture.data("event-policy-applied.v1"))
        
        #expect(flow.kind == .flowDecision)
        #expect(flow.provenance == .synthetic)
        #expect(flow.occurredAt == Date(timeIntervalSince1970: 1_795_687_200))
        #expect(flow.flow == FlowSummary(remoteHost: "tracker.example.net", remotePort: 443, transport: .tcp, action: .deny, ruleIdentifier: "block-tracker"))
        #expect(applied.kind == .policyApplied)
        #expect(applied.provenance == .lab)
        #expect(applied.policy == PolicyReference(identifier: "office-network", revision: 7))
    }
    
    @Test
    func `The identity fixtures decode, platform binaries without a Team ID`() throws {
        let developer = try SchemaCodec.decode(ApplicationIdentity.self, from: Fixture.data("application-identity.v1"))
        let platform = try SchemaCodec.decode(ApplicationIdentity.self, from: Fixture.data("application-identity-platform.v1"))
        
        #expect(developer == ApplicationIdentity(signingIdentifier: "com.example.browser", teamIdentifier: "EXAMPLE001", isPlatformBinary: false, bundleIdentifier: "com.example.browser"))
        #expect(platform == ApplicationIdentity(signingIdentifier: "com.apple.curl", teamIdentifier: nil, isPlatformBinary: true, bundleIdentifier: nil))
    }
    
    @Test(arguments: ["policy.v1", "event-flow-decision.v1", "event-policy-applied.v1", "application-identity.v1"])
    func `A valid fixture survives encode and decode unchanged`(fixture: String) throws {
        let data = try Fixture.data(fixture)
        switch fixture {
        case "policy.v1":
            try expectRoundTrip(SchemaCodec.decode(SecurityPolicy.self, from: data))
        case "application-identity.v1":
            try expectRoundTrip(SchemaCodec.decode(ApplicationIdentity.self, from: data))
        default:
            try expectRoundTrip(SchemaCodec.decode(SecurityEvent.self, from: data))
        }
    }
    
    private func expectRoundTrip<Body: SchemaBody>(_ body: Body) throws {
        let encoded = try SchemaCodec.encode(body)
        #expect(try SchemaCodec.decode(Body.self, from: encoded) == body)
    }
    
    // MARK: - Version
    
    @Test
    func `A policy with an unknown schema version is refused with a typed error`() throws {
        try expectRefusal(SecurityPolicy.self, fixture: "policy-unknown-version", .unsupportedVersion(2, supported: SchemaVersion.onlyV1))
    }
    
    @Test
    func `An event with an unknown schema version is refused with a typed error`() throws {
        try expectRefusal(SecurityEvent.self, fixture: "event-unknown-version", .unsupportedVersion(99, supported: SchemaVersion.onlyV1))
    }
    
    @Test
    func `An identity with schema version zero is refused with a typed error`() throws {
        try expectRefusal(ApplicationIdentity.self, fixture: "application-identity-unknown-version", .unsupportedVersion(0, supported: SchemaVersion.onlyV1))
    }
    
    // MARK: - Envelope
    
    @Test
    func `A document of another schema is refused, so an event never passes as a policy`() throws {
        try expectRefusal(SecurityPolicy.self, fixture: "policy-wrong-kind", .wrongKind(expected: .securityPolicy))
        try expectRefusal(SecurityEvent.self, fixture: "policy.v1", .wrongKind(expected: .securityEvent))
    }
    
    @Test(arguments: ["policy-missing-version", "policy-version-as-string"])
    func `An envelope without an integer version is malformed`(fixture: String) throws {
        try expectRefusal(SecurityPolicy.self, fixture: fixture, .malformed)
    }
    
    // MARK: - Shape
    
    @Test
    func `A rule list sent as an object is a wrong shape`() throws {
        try expectRefusal(SecurityPolicy.self, fixture: "policy-wrong-shape", .wrongShape(path: "$.body.rules"))
    }
    
    @Test
    func `An unknown action is a wrong shape, not a fallback to allow`() throws {
        try expectRefusal(SecurityPolicy.self, fixture: "policy-unknown-action", .wrongShape(path: "$.body.rules[0].action"))
    }
    
    @Test
    func `A malformed event identifier is a wrong shape`() throws {
        try expectRefusal(SecurityEvent.self, fixture: "event-bad-uuid", .wrongShape(path: "$.body.identifier"))
    }
    
    @Test
    func `A misspelled optional field is refused instead of ignored`() throws {
        try expectRefusal(SecurityPolicy.self, fixture: "policy-unknown-field", .unknownField(path: "$.body.rules[0]"))
    }
    
    @Test
    func `An explicit null for an optional field is refused`() throws {
        try expectRefusal(SecurityPolicy.self, fixture: "policy-null-optional", .unknownField(path: "$.body.rules[0]"))
    }
    
    @Test(arguments: ["policy-duplicate-key", "policy-duplicate-escaped-key"])
    func `A repeated key is refused, so every parser reads the same policy`(fixture: String) throws {
        try expectRefusal(SecurityPolicy.self, fixture: fixture, .duplicateField)
    }
    
    @Test(arguments: ["event-fractional-time", "event-offset-time"])
    func `A time in any form but whole-second UTC is a wrong shape`(fixture: String) throws {
        try expectRefusal(SecurityEvent.self, fixture: fixture, .wrongShape(path: "$.body.occurredAt"))
    }
    
    @Test
    func `A plain JSONDecoder cannot decode a body and skip the codec's checks`() throws {
        let policy = try Fixture.data("policy-unknown-field")
        let identity = Data(#"{"signingIdentifier":"com.apple.curl","isPlatformBinary":true}"#.utf8)
        
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SchemaDocument<SecurityPolicy>.self, from: policy)
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ApplicationIdentity.self, from: identity)
        }
    }
    
    @Test
    func `An unknown envelope field is refused, so no unchecked signature claim passes`() throws {
        try expectRefusal(SecurityPolicy.self, fixture: "policy-unknown-envelope-field", .unknownField(path: "$"))
    }
    
    // MARK: - Validation
    
    @Test(arguments: [
        ("policy-rule-without-criteria", SchemaViolation(path: "$.body.rules[0]", reason: .missingRequired)),
        ("policy-unpinned-application", SchemaViolation(path: "$.body.rules[0].application.teamIdentifier", reason: .missingRequired)),
        ("policy-duplicate-rule", SchemaViolation(path: "$.body.rules[1].identifier", reason: .duplicate)),
        ("policy-uppercase-host", SchemaViolation(path: "$.body.rules[0].destinationHosts[1]", reason: .malformedHost)),
        ("policy-tld-wildcard", SchemaViolation(path: "$.body.rules[0].destinationHosts[0]", reason: .malformedHost)),
        ("policy-revision-zero", SchemaViolation(path: "$.body.revision", reason: .outOfRange))
    ])
    func `A policy that breaks a rule is refused at the offending path`(fixture: String, violation: SchemaViolation) throws {
        try expectRefusal(SecurityPolicy.self, fixture: fixture, .invalid(violation))
    }
    
    @Test(arguments: [
        ("event-flow-missing", SchemaViolation(path: "$.body.flow", reason: .missingRequired)),
        ("event-port-zero", SchemaViolation(path: "$.body.flow.remotePort", reason: .outOfRange)),
        ("event-url-as-host", SchemaViolation(path: "$.body.flow.remoteHost", reason: .malformedHost))
    ])
    func `An event that breaks a rule is refused at the offending path`(fixture: String, violation: SchemaViolation) throws {
        try expectRefusal(SecurityEvent.self, fixture: fixture, .invalid(violation))
    }
    
    @Test(arguments: [
        ("application-identity-platform-with-team", SchemaViolation(path: "$.body.teamIdentifier", reason: .contradictory)),
        ("application-identity-bad-team", SchemaViolation(path: "$.body.teamIdentifier", reason: .malformedTeamIdentifier))
    ])
    func `An identity that breaks a rule is refused at the offending path`(fixture: String, violation: SchemaViolation) throws {
        try expectRefusal(ApplicationIdentity.self, fixture: fixture, .invalid(violation))
    }
}
