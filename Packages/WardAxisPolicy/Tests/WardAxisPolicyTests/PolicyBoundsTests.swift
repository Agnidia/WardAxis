//
//  PolicyBoundsTests.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisCore
import WardAxisPolicy

@Suite("Policy bounds")
struct PolicyBoundsTests {
    private static let hosts = PolicyMatch(destinationHosts: ["example.com"])
    
    private static func policy(_ rules: [PolicyRule]) -> SecurityPolicy {
        SecurityPolicy(identifier: "p", revision: 1, mode: .enforce, defaultAction: .deny, rules: rules)
    }
    
    private static func rule(_ match: PolicyMatch, priority: Int = 100) -> PolicyRule {
        PolicyRule(identifier: "r", priority: priority, enabled: true, action: .deny, match: match)
    }
    
    @Test
    func `A policy over the rule limit is refused`() {
        let rules = (0...PolicyLimits.maximumRuleCount).map {
            PolicyRule(identifier: "r\($0)", priority: 100, enabled: true, action: .deny, match: Self.hosts)
        }
        #expect(throws: SchemaViolation(path: "$.body.rules", reason: .tooMany)) {
            try Self.policy(rules).validate()
        }
    }
    
    @Test
    func `The priority bounds are inclusive`() throws {
        try Self.policy([Self.rule(Self.hosts, priority: PolicyLimits.priorityRange.lowerBound)]).validate()
        try Self.policy([Self.rule(Self.hosts, priority: PolicyLimits.priorityRange.upperBound)]).validate()
    }
    
    @Test
    func `A criterion list over its limit is refused`() {
        let hosts = (0...PolicyLimits.maximumHostsPerRule).map { "h\($0).example.com" }
        let networks = (0...PolicyLimits.maximumNetworksPerRule).map { "10.0.\($0).0/24" }
        let ports = (1...(PolicyLimits.maximumPortRangesPerRule + 1)).map { PortRange(first: $0, last: $0) }
        
        #expect(throws: SchemaViolation(path: "$.body.rules[0].match.destinationHosts", reason: .tooMany)) {
            try Self.policy([Self.rule(PolicyMatch(destinationHosts: hosts))]).validate()
        }
        #expect(throws: SchemaViolation(path: "$.body.rules[0].match.destinationNetworks", reason: .tooMany)) {
            try Self.policy([Self.rule(PolicyMatch(destinationNetworks: networks))]).validate()
        }
        #expect(throws: SchemaViolation(path: "$.body.rules[0].match.destinationPorts", reason: .tooMany)) {
            try Self.policy([Self.rule(PolicyMatch(destinationPorts: ports))]).validate()
        }
    }
    
    @Test
    func `An empty criterion list is refused, never read as any`() {
        #expect(throws: SchemaViolation(path: "$.body.rules[0].match.destinationHosts", reason: .missingRequired)) {
            try Self.policy([Self.rule(PolicyMatch(destinationHosts: []))]).validate()
        }
        #expect(throws: SchemaViolation(path: "$.body.rules[0].match.destinationPorts", reason: .missingRequired)) {
            try Self.policy([Self.rule(PolicyMatch(destinationPorts: []))]).validate()
        }
    }
    
    @Test
    func `A transport or port alone is a criterion`() throws {
        try Self.policy([Self.rule(PolicyMatch(transport: .udp))]).validate()
        try Self.policy([Self.rule(PolicyMatch(destinationPorts: [PortRange(first: 1, last: 65_535)]))]).validate()
    }
    
    @Test
    func `A disabled rule is validated like an enabled one`() {
        let disabled = PolicyRule(identifier: "r", priority: 100, enabled: false, action: .allow, match: PolicyMatch())
        #expect(throws: SchemaViolation(path: "$.body.rules[0].match", reason: .missingRequired)) {
            try Self.policy([disabled]).validate()
        }
    }
    
    @Test
    func `The encoder refuses a policy that a reader would refuse`() {
        let invalid = Self.policy([Self.rule(PolicyMatch(destinationNetworks: ["192.0.2.1/24"]))])
        #expect(throws: SchemaError.invalid(SchemaViolation(path: "$.body.rules[0].match.destinationNetworks[0]", reason: .malformedNetwork))) {
            try SchemaCodec.encode(invalid)
        }
    }
    
    @Test
    func `A policy at every per-rule limit still fits in one document`() throws {
        let match = PolicyMatch(
            destinationHosts: (0..<PolicyLimits.maximumHostsPerRule).map { "h\($0).example.com" },
            destinationNetworks: (0..<PolicyLimits.maximumNetworksPerRule).map { "10.0.\($0).0/24" },
            destinationPorts: (1...PolicyLimits.maximumPortRangesPerRule).map { PortRange(first: $0, last: $0) }
        )
        let policy = Self.policy([Self.rule(match)])
        #expect(try SchemaCodec.decode(SecurityPolicy.self, from: SchemaCodec.encode(policy)) == policy)
    }
}
