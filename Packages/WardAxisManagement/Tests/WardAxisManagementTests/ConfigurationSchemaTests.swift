//
//  ConfigurationSchemaTests.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisCore
import WardAxisPolicy
@testable import WardAxisManagement

@Suite("Typed configuration values")
struct ConfigurationSchemaTests {
    private static let policyFrame = #"""
    {"type":"snapshot","version":3,"values":{"policy":{"schema":"wardaxis.security-policy","schemaVersion":1,"body":{"identifier":"office-network","revision":7,"mode":"enforce","defaultAction":"deny","rules":[{"identifier":"block-tracker","priority":100,"enabled":true,"action":"deny","match":{"destinationHosts":["tracker.example.net"]}}]}}}}
    """#
    
    private static func configuration(policy: ConfigurationValue) -> ManagedConfiguration {
        ManagedConfiguration(version: 1, values: ["policy": policy])
    }
    
    @Test
    func `A policy from a feed snapshot decodes through the schema`() throws {
        guard case .snapshot(let configuration) = try #require(ConfigurationFrameDecoder().decode(Data(Self.policyFrame.utf8))) else {
            Issue.record("Expected a snapshot")
            return
        }
        
        let policy = try #require(try configuration.document(SecurityPolicy.self, forKey: "policy"))
        
        #expect(policy.defaultAction == .deny)
        #expect(policy.rules.map(\.identifier) == ["block-tracker"])
    }
    
    @Test
    func `An absent key is nil, not a default policy`() throws {
        #expect(try ManagedConfiguration(version: 1, values: [:]).document(SecurityPolicy.self, forKey: "policy") == nil)
    }
    
    @Test
    func `A server value of the wrong shape is refused`() {
        let rulesAsString = Self.configuration(policy: .object([
            "schema": .string("wardaxis.security-policy"),
            "schemaVersion": .integer(1),
            "body": .object([
                "identifier": .string("p"),
                "revision": .integer(1),
                "mode": .string("enforce"),
                "defaultAction": .string("deny"),
                "rules": .string("allow everything")
            ])
        ]))
        
        #expect(throws: SchemaError.wrongShape(path: "$.body.rules")) {
            try rulesAsString.document(SecurityPolicy.self, forKey: "policy")
        }
    }
    
    @Test
    func `A server value with an unknown schema version is refused`() {
        let newer = Self.configuration(policy: .object([
            "schema": .string("wardaxis.security-policy"),
            "schemaVersion": .integer(2),
            "body": .object([:])
        ]))
        
        #expect(throws: SchemaError.unsupportedVersion(2, supported: SchemaVersion.onlyV1)) {
            try newer.document(SecurityPolicy.self, forKey: "policy")
        }
    }
    
    @Test
    func `A feed frame that repeats a key is dropped before any decode`() {
        let frame = #"{"type":"snapshot","version":3,"values":{"mode":"deny","mode":"allow"}}"#
        
        #expect(ConfigurationFrameDecoder().decode(Data(frame.utf8)) == nil)
    }
    
    @Test(arguments: [ConfigurationValue.string("deny"), .array([]), .integer(1), .null])
    func `A server value that is not a JSON object is refused`(value: ConfigurationValue) {
        #expect(throws: SchemaError.outOfBounds) {
            try Self.configuration(policy: value).document(SecurityPolicy.self, forKey: "policy")
        }
    }
}
