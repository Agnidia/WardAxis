//
//  SecurityPolicy.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisCore

/// Whether a policy's decisions take effect.
public enum PolicyMode: String, Sendable, Hashable, Codable {
    /// Decisions are applied to flows.
    case enforce
    
    /// Decisions are evaluated and reported but never applied (NET-014).
    case audit
}

/// A security policy: data only, with no expression or control flow (ADR 0010 D3).
///
/// Decode it only through ``SchemaCodec``; the rules it must satisfy are in ADR 0015.
public struct SecurityPolicy: SchemaBody {
    public static let schemaKind = SchemaKind.securityPolicy
    public static let supportedVersions = SchemaVersion.onlyV1
    public static let currentVersion = SchemaVersion.v1
    
    public let identifier: String
    
    /// Grows with every change the issuer makes, so a consumer can refuse a replayed older policy.
    public let revision: Int64
    
    /// Required, so a reader never guesses between enforcing and only reporting.
    public let mode: PolicyMode
    
    /// The action when no rule matches. Required, so a policy never inherits a fail-open default.
    public let defaultAction: PolicyAction
    
    /// Array order carries no meaning; precedence comes from ``PolicyRule/priority``
    /// and the resolution order in ADR 0015 D3.
    public let rules: [PolicyRule]
    
    public init(identifier: String, revision: Int64, mode: PolicyMode, defaultAction: PolicyAction, rules: [PolicyRule]) {
        self.identifier = identifier
        self.revision = revision
        self.mode = mode
        self.defaultAction = defaultAction
        self.rules = rules
    }
    
    public init(from decoder: any Decoder) throws {
        try SchemaCodec.requireCodec(decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decode(String.self, forKey: .identifier)
        revision = try container.decode(Int64.self, forKey: .revision)
        mode = try container.decode(PolicyMode.self, forKey: .mode)
        defaultAction = try container.decode(PolicyAction.self, forKey: .defaultAction)
        rules = try container.decode([PolicyRule].self, forKey: .rules)
    }
    
    public func validate() throws(SchemaViolation) {
        guard FieldRules.isIdentifier(identifier) else {
            throw SchemaViolation(path: SchemaPath.member(SchemaPath.body, CodingKeys.identifier), reason: .malformedIdentifier)
        }
        guard revision >= SchemaLimits.minimumRevision else {
            throw SchemaViolation(path: SchemaPath.member(SchemaPath.body, CodingKeys.revision), reason: .outOfRange)
        }
        let rulesPath = SchemaPath.member(SchemaPath.body, CodingKeys.rules)
        guard rules.count <= PolicyLimits.maximumRuleCount else {
            throw SchemaViolation(path: rulesPath, reason: .tooMany)
        }
        var seen = Set<String>()
        for (index, rule) in rules.enumerated() {
            let path = SchemaPath.index(rulesPath, index)
            try rule.validate(at: path)
            // The rule identifier is the last tie-breaker of precedence, so it must be unique.
            guard seen.insert(rule.identifier).inserted else {
                throw SchemaViolation(path: PolicyRule.identifierPath(at: path), reason: .duplicate)
            }
        }
    }
}
