//
//  SecurityPolicy.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

public enum PolicyAction: String, Sendable, Hashable, Codable {
    case allow
    case deny
}

/// A security policy: data only, with no expression or control flow (ADR 0010 D3).
public struct SecurityPolicy: SchemaBody {
    public static let schemaKind = SchemaKind.securityPolicy
    public static let supportedVersions = SchemaVersion.onlyV1
    public static let currentVersion = SchemaVersion.v1
    
    public let identifier: String
    
    /// Grows with every change the issuer makes, so a consumer can refuse a replayed older policy.
    public let revision: Int64
    
    /// The action when no rule matches. Required, so a policy never inherits a fail-open default.
    public let defaultAction: PolicyAction
    
    /// In order; the first match wins.
    public let rules: [PolicyRule]
    
    public init(identifier: String, revision: Int64, defaultAction: PolicyAction, rules: [PolicyRule]) {
        self.identifier = identifier
        self.revision = revision
        self.defaultAction = defaultAction
        self.rules = rules
    }
    
    public init(from decoder: any Decoder) throws {
        try SchemaCodec.requireCodec(decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decode(String.self, forKey: .identifier)
        revision = try container.decode(Int64.self, forKey: .revision)
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
        guard rules.count <= SchemaLimits.maximumRuleCount else {
            throw SchemaViolation(path: SchemaPath.member(SchemaPath.body, CodingKeys.rules), reason: .tooMany)
        }
        var seen = Set<String>()
        for (index, rule) in rules.enumerated() {
            let path = SchemaPath.index(SchemaPath.member(SchemaPath.body, CodingKeys.rules), index)
            try rule.validate(at: path)
            guard seen.insert(rule.identifier).inserted else {
                throw SchemaViolation(path: PolicyRule.identifierPath(at: path), reason: .duplicate)
            }
        }
    }
}

/// One rule. It matches when every criterion it names matches.
public struct PolicyRule: Sendable, Hashable, Codable {
    public let identifier: String
    public let action: PolicyAction
    public let application: ApplicationMatcher?
    
    /// Host names or `*.` patterns (see ``SecurityPolicy``); one of them must match.
    public let destinationHosts: [String]?
    
    public init(identifier: String, action: PolicyAction, application: ApplicationMatcher?, destinationHosts: [String]?) {
        self.identifier = identifier
        self.action = action
        self.application = application
        self.destinationHosts = destinationHosts
    }
    
    static func identifierPath(at path: String) -> String {
        SchemaPath.member(path, CodingKeys.identifier)
    }
    
    func validate(at path: String) throws(SchemaViolation) {
        guard FieldRules.isIdentifier(identifier) else {
            throw SchemaViolation(path: Self.identifierPath(at: path), reason: .malformedIdentifier)
        }
        // A rule with no criterion would match everything and override `defaultAction`.
        guard application != nil || destinationHosts != nil else {
            throw SchemaViolation(path: path, reason: .missingRequired)
        }
        try application?.validate(at: SchemaPath.member(path, CodingKeys.application))
        if let destinationHosts {
            let hostsPath = SchemaPath.member(path, CodingKeys.destinationHosts)
            guard !destinationHosts.isEmpty else {
                throw SchemaViolation(path: hostsPath, reason: .missingRequired)
            }
            guard destinationHosts.count <= SchemaLimits.maximumHostsPerRule else {
                throw SchemaViolation(path: hostsPath, reason: .tooMany)
            }
            var seen = Set<String>()
            for (index, host) in destinationHosts.enumerated() {
                guard FieldRules.isHostPattern(host) else {
                    throw SchemaViolation(path: SchemaPath.index(hostsPath, index), reason: .malformedHost)
                }
                guard seen.insert(host).inserted else {
                    throw SchemaViolation(path: SchemaPath.index(hostsPath, index), reason: .duplicate)
                }
            }
        }
    }
}
