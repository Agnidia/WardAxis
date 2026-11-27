//
//  PolicyRule.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisCore

/// One rule of a ``SecurityPolicy``.
public struct PolicyRule: Sendable, Hashable, Codable {
    public let identifier: String
    
    /// A higher value wins, within ``PolicyLimits/priorityRange``. Equal
    /// priorities fall to specificity, then to ``identifier`` (ADR 0015 D3).
    public let priority: Int
    
    /// A disabled rule never matches, but it is validated like any other, so
    /// enabling it later cannot introduce a rule that was never checked.
    public let enabled: Bool
    
    public let action: PolicyAction
    public let match: PolicyMatch
    
    public init(identifier: String, priority: Int, enabled: Bool, action: PolicyAction, match: PolicyMatch) {
        self.identifier = identifier
        self.priority = priority
        self.enabled = enabled
        self.action = action
        self.match = match
    }
    
    static func identifierPath(at path: String) -> String {
        SchemaPath.member(path, CodingKeys.identifier)
    }
    
    func validate(at path: String) throws(SchemaViolation) {
        guard FieldRules.isIdentifier(identifier) else {
            throw SchemaViolation(path: Self.identifierPath(at: path), reason: .malformedIdentifier)
        }
        guard PolicyLimits.priorityRange.contains(priority) else {
            throw SchemaViolation(path: SchemaPath.member(path, CodingKeys.priority), reason: .outOfRange)
        }
        try match.validate(at: SchemaPath.member(path, CodingKeys.match))
    }
}

/// The criteria of a rule. It matches when every criterion it names matches;
/// within a list, one element must match. An absent criterion matches anything.
public struct PolicyMatch: Sendable, Hashable, Codable {
    public let application: ApplicationMatcher?
    
    /// Host names or `*.` patterns (ADR 0011 D3).
    public let destinationHosts: [String]?
    
    /// Canonical CIDR networks, IPv4 or IPv6 (``FieldRules/isCanonicalNetwork(_:)``).
    public let destinationNetworks: [String]?
    
    public let transport: TransportProtocol?
    public let destinationPorts: [PortRange]?
    
    /// ``destinationNetworks`` parsed once per policy, so a flow costs no string
    /// parse. `nil` marks an entry that bypassed validation (ADR 0018 D3).
    let compiledNetworks: [IPNetwork?]?
    
    /// ``destinationHosts`` checked once per policy, for the same reason (ADR 0017 D3).
    let compiledHosts: CompiledHosts?
    
    enum CodingKeys: String, CodingKey {
        case application, destinationHosts, destinationNetworks, transport, destinationPorts
    }
    
    public init(
        application: ApplicationMatcher? = nil,
        destinationHosts: [String]? = nil,
        destinationNetworks: [String]? = nil,
        transport: TransportProtocol? = nil,
        destinationPorts: [PortRange]? = nil
    ) {
        self.application = application
        self.destinationHosts = destinationHosts
        self.destinationNetworks = destinationNetworks
        self.transport = transport
        self.destinationPorts = destinationPorts
        compiledNetworks = destinationNetworks?.map(IPNetwork.init)
        compiledHosts = destinationHosts.map(CompiledHosts.init)
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            application: container.decodeIfPresent(ApplicationMatcher.self, forKey: .application),
            destinationHosts: container.decodeIfPresent([String].self, forKey: .destinationHosts),
            destinationNetworks: container.decodeIfPresent([String].self, forKey: .destinationNetworks),
            transport: container.decodeIfPresent(TransportProtocol.self, forKey: .transport),
            destinationPorts: container.decodeIfPresent([PortRange].self, forKey: .destinationPorts)
        )
    }
    
    func validate(at path: String) throws(SchemaViolation) {
        // A match with no criterion would match every flow and override `defaultAction`.
        guard application != nil || destinationHosts != nil || destinationNetworks != nil || transport != nil || destinationPorts != nil else {
            throw SchemaViolation(path: path, reason: .missingRequired)
        }
        try application?.validate(at: SchemaPath.member(path, CodingKeys.application))
        if let destinationHosts {
            try Self.validateList(
                destinationHosts,
                at: SchemaPath.member(path, CodingKeys.destinationHosts),
                maximumCount: PolicyLimits.maximumHostsPerRule
            ) { FieldRules.isHostPattern($0) ? nil : .malformedHost }
        }
        if let destinationNetworks {
            try Self.validateList(
                destinationNetworks,
                at: SchemaPath.member(path, CodingKeys.destinationNetworks),
                maximumCount: PolicyLimits.maximumNetworksPerRule
            ) { FieldRules.isCanonicalNetwork($0) ? nil : .malformedNetwork }
        }
        if let destinationPorts {
            try Self.validateList(
                destinationPorts,
                at: SchemaPath.member(path, CodingKeys.destinationPorts),
                maximumCount: PolicyLimits.maximumPortRangesPerRule
            ) { $0.isValid ? nil : .outOfRange }
        }
    }
    
    /// An empty list is refused rather than read as "any": absence is the only way to say "any".
    private static func validateList<Element: Hashable>(
        _ list: [Element],
        at path: String,
        maximumCount: Int,
        violation: (Element) -> SchemaViolation.Reason?
    ) throws(SchemaViolation) {
        guard !list.isEmpty else {
            throw SchemaViolation(path: path, reason: .missingRequired)
        }
        guard list.count <= maximumCount else {
            throw SchemaViolation(path: path, reason: .tooMany)
        }
        var seen = Set<Element>()
        for (index, element) in list.enumerated() {
            if let reason = violation(element) {
                throw SchemaViolation(path: SchemaPath.index(path, index), reason: reason)
            }
            guard seen.insert(element).inserted else {
                throw SchemaViolation(path: SchemaPath.index(path, index), reason: .duplicate)
            }
        }
    }
}

/// The validated host patterns of a match, and whether any entry bypassed validation.
struct CompiledHosts: Sendable, Hashable {
    let patterns: [String]
    let hasInvalid: Bool
    
    init(_ hosts: [String]) {
        patterns = hosts.filter(FieldRules.isHostPattern)
        hasInvalid = patterns.count != hosts.count
    }
}
