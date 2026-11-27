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
    
    @Test(arguments: ["event-flow-decision.v1", "event-policy-applied.v1", "application-identity.v1"])
    func `A valid fixture survives encode and decode unchanged`(fixture: String) throws {
        let data = try Fixture.data(fixture)
        switch fixture {
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
    func `An event with an unknown schema version is refused with a typed error`() throws {
        try expectRefusal(SecurityEvent.self, fixture: "event-unknown-version", .unsupportedVersion(99, supported: SchemaVersion.onlyV1))
    }
    
    @Test
    func `An identity with schema version zero is refused with a typed error`() throws {
        try expectRefusal(ApplicationIdentity.self, fixture: "application-identity-unknown-version", .unsupportedVersion(0, supported: SchemaVersion.onlyV1))
    }
    
    // MARK: - Envelope
    
    @Test
    func `A document of another schema is refused, so an event never passes as an identity`() throws {
        try expectRefusal(ApplicationIdentity.self, fixture: "event-flow-decision.v1", .wrongKind(expected: .applicationIdentity))
        try expectRefusal(SecurityEvent.self, fixture: "application-identity.v1", .wrongKind(expected: .securityEvent))
    }
    
    @Test(arguments: ["application-identity-missing-version", "application-identity-version-as-string"])
    func `An envelope without an integer version is malformed`(fixture: String) throws {
        try expectRefusal(ApplicationIdentity.self, fixture: fixture, .malformed)
    }
    
    // MARK: - Shape
    
    @Test
    func `An unknown provenance is a wrong shape, not a fallback to live`() throws {
        try expectRefusal(SecurityEvent.self, fixture: "event-unknown-provenance", .wrongShape(path: "$.body.provenance"))
    }
    
    @Test
    func `A malformed event identifier is a wrong shape`() throws {
        try expectRefusal(SecurityEvent.self, fixture: "event-bad-uuid", .wrongShape(path: "$.body.identifier"))
    }
    
    @Test
    func `A misspelled optional field is refused instead of ignored`() throws {
        try expectRefusal(ApplicationIdentity.self, fixture: "application-identity-unknown-field", .unknownField(path: "$.body"))
    }
    
    @Test
    func `An explicit null for an optional field is refused`() throws {
        try expectRefusal(ApplicationIdentity.self, fixture: "application-identity-null-optional", .unknownField(path: "$.body"))
    }
    
    @Test(arguments: ["application-identity-duplicate-key", "application-identity-duplicate-escaped-key"])
    func `A repeated key is refused, so every parser reads the same document`(fixture: String) throws {
        try expectRefusal(ApplicationIdentity.self, fixture: fixture, .duplicateField)
    }
    
    @Test(arguments: ["event-fractional-time", "event-offset-time"])
    func `A time in any form but whole-second UTC is a wrong shape`(fixture: String) throws {
        try expectRefusal(SecurityEvent.self, fixture: fixture, .wrongShape(path: "$.body.occurredAt"))
    }
    
    @Test
    func `A plain JSONDecoder cannot decode a body and skip the codec's checks`() throws {
        let document = try Fixture.data("application-identity-unknown-field")
        let identity = Data(#"{"signingIdentifier":"com.apple.curl","isPlatformBinary":true}"#.utf8)
        
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SchemaDocument<ApplicationIdentity>.self, from: document)
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ApplicationIdentity.self, from: identity)
        }
    }
    
    @Test
    func `An unknown envelope field is refused, so no unchecked signature claim passes`() throws {
        try expectRefusal(ApplicationIdentity.self, fixture: "application-identity-unknown-envelope-field", .unknownField(path: "$"))
    }
    
    // MARK: - Validation
    
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
