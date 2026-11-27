//
//  SchemaBoundsTests.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisCore

@Suite("Schema bounds and encoding")
struct SchemaBoundsTests {
    private static let envelope = #"{"schema":"wardaxis.application-identity","schemaVersion":1,"body":{"signingIdentifier":"com.apple.curl","isPlatformBinary":true}"#
    
    @Test
    func `A document over the byte limit is refused before decoding`() {
        let padding = String(repeating: " ", count: SchemaLimits.maximumDocumentSize)
        let data = Data((Self.envelope + padding + "}").utf8)
        
        #expect(throws: SchemaError.outOfBounds) {
            try SchemaCodec.decode(ApplicationIdentity.self, from: data)
        }
    }
    
    @Test
    func `Nesting past the depth limit is refused, even inside an unknown field`() {
        let depth = SchemaLimits.maximumNestingDepth
        let nested = String(repeating: "[", count: depth) + String(repeating: "]", count: depth)
        let data = Data((Self.envelope.dropLast() + #","x":\#(nested)}}"#).utf8)
        
        #expect(throws: SchemaError.outOfBounds) {
            try SchemaCodec.decode(ApplicationIdentity.self, from: data)
        }
    }
    
    @Test(arguments: [
        "[]",
        "\"wardaxis\"",
        "{\"schema\":\"wardaxis.application-identity\"\u{0}}",
        "{\"schema\":\"\\x41\"}",
        "{\"schema\":\"wardaxis",
        ""
    ])
    func `Anything but one strict JSON object is refused`(raw: String) {
        #expect(throws: SchemaError.outOfBounds) {
            try SchemaCodec.decode(ApplicationIdentity.self, from: Data(raw.utf8))
        }
    }
    
    @Test(arguments: ["{\"a\":1}{\"b\":2}", "{\"a\":1},", "{\"a\":[1}]", "{\"a\":{\"b\":1]}"])
    func `Trailing data and mismatched brackets are refused`(raw: String) {
        #expect(!BoundedJSON.isWithinBounds(Data(raw.utf8), maximumSize: 1024, maximumDepth: 8))
    }
    
    @Test
    func `Keys repeat only across objects, never within one`() {
        let distinct = Data(#"{"a":{"a":1},"b":[{"a":1},{"a":2}],"c":"a"}"#.utf8)
        let repeated = Data(#"{"a":{"x":1,"y":2,"x":3}}"#.utf8)
        
        #expect(BoundedJSON.scan(distinct, maximumSize: 1024, maximumDepth: 8) == .accepted)
        #expect(BoundedJSON.scan(repeated, maximumSize: 1024, maximumDepth: 8) == .duplicateKey)
    }
    
    @Test
    func `Encoding refuses an event time with a fraction, which the wire would drop`() {
        let event = SecurityEvent(
            identifier: UUID(),
            occurredAt: Date(timeIntervalSince1970: 1_795_687_200.5),
            provenance: .live,
            kind: .policyApplied,
            application: nil,
            flow: nil,
            policy: PolicyReference(identifier: "office-network", revision: 7)
        )
        
        #expect(throws: SchemaError.invalid(SchemaViolation(path: "$.body.occurredAt", reason: .outOfRange))) {
            try SchemaCodec.encode(event)
        }
    }
    
    @Test
    func `Encoding refuses a body that decoding would refuse`() {
        let forged = ApplicationIdentity(signingIdentifier: "com.apple.curl", teamIdentifier: "EXAMPLE001", isPlatformBinary: true, bundleIdentifier: nil)
        
        #expect(throws: SchemaError.invalid(SchemaViolation(path: "$.body.teamIdentifier", reason: .contradictory))) {
            try SchemaCodec.encode(forged)
        }
    }
    
    @Test
    func `Encoding writes the current version and the schema name`() throws {
        let identity = ApplicationIdentity(signingIdentifier: "com.apple.curl", teamIdentifier: nil, isPlatformBinary: true, bundleIdentifier: nil)
        
        let json = try #require(String(data: SchemaCodec.encode(identity), encoding: .utf8))
        
        #expect(json == #"{"body":{"isPlatformBinary":true,"signingIdentifier":"com.apple.curl"},"schema":"wardaxis.application-identity","schemaVersion":1}"#)
    }
}
