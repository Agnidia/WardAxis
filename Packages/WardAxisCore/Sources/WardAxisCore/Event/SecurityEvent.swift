//
//  SecurityEvent.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Where an event came from. Results from each origin are reported separately,
/// so a synthetic or lab result is never presented as a shipped-build result.
public enum EventProvenance: String, Sendable, Hashable, Codable {
    case live
    case synthetic
    case lab
}

public enum EventKind: String, Sendable, Hashable, Codable {
    /// An enforcement component decided on a network flow; ``SecurityEvent/flow`` is set.
    case flowDecision
    
    /// A component started to enforce a policy; ``SecurityEvent/policy`` is set.
    case policyApplied
}

/// One security event.
///
/// No field holds matched content, a URL path or query, or free text: an
/// event names a host, an application and a decision, and nothing a user typed.
public struct SecurityEvent: SchemaBody {
    public static let schemaKind = SchemaKind.securityEvent
    public static let supportedVersions = SchemaVersion.onlyV1
    public static let currentVersion = SchemaVersion.v1
    
    public let identifier: UUID
    
    /// Whole seconds in UTC, written `yyyy-MM-ddTHH:mm:ssZ`; ``validate()`` refuses a fraction.
    public let occurredAt: Date
    
    public let provenance: EventProvenance
    public let kind: EventKind
    public let application: ApplicationIdentity?
    public let flow: FlowSummary?
    public let policy: PolicyReference?
    
    public init(
        identifier: UUID,
        occurredAt: Date,
        provenance: EventProvenance,
        kind: EventKind,
        application: ApplicationIdentity?,
        flow: FlowSummary?,
        policy: PolicyReference?
    ) {
        self.identifier = identifier
        self.occurredAt = occurredAt
        self.provenance = provenance
        self.kind = kind
        self.application = application
        self.flow = flow
        self.policy = policy
    }
    
    public init(from decoder: any Decoder) throws {
        try SchemaCodec.requireCodec(decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decode(UUID.self, forKey: .identifier)
        occurredAt = try container.decode(Date.self, forKey: .occurredAt)
        provenance = try container.decode(EventProvenance.self, forKey: .provenance)
        kind = try container.decode(EventKind.self, forKey: .kind)
        application = try container.decodeIfPresent(ApplicationIdentity.self, forKey: .application)
        flow = try container.decodeIfPresent(FlowSummary.self, forKey: .flow)
        policy = try container.decodeIfPresent(PolicyReference.self, forKey: .policy)
    }
    
    public func validate() throws(SchemaViolation) {
        // The wire carries whole seconds, so a fraction would not survive an encode and decode.
        guard occurredAt.timeIntervalSince1970.rounded(.down) == occurredAt.timeIntervalSince1970 else {
            throw SchemaViolation(path: SchemaPath.member(SchemaPath.body, CodingKeys.occurredAt), reason: .outOfRange)
        }
        switch kind {
        case .flowDecision:
            guard let flow else {
                throw SchemaViolation(path: SchemaPath.member(SchemaPath.body, CodingKeys.flow), reason: .missingRequired)
            }
            guard policy == nil else {
                throw SchemaViolation(path: SchemaPath.member(SchemaPath.body, CodingKeys.policy), reason: .contradictory)
            }
            try flow.validate(at: SchemaPath.member(SchemaPath.body, CodingKeys.flow))
        case .policyApplied:
            guard let policy else {
                throw SchemaViolation(path: SchemaPath.member(SchemaPath.body, CodingKeys.policy), reason: .missingRequired)
            }
            guard flow == nil else {
                throw SchemaViolation(path: SchemaPath.member(SchemaPath.body, CodingKeys.flow), reason: .contradictory)
            }
            try policy.validate(at: SchemaPath.member(SchemaPath.body, CodingKeys.policy))
        }
        try application?.validate(at: SchemaPath.member(SchemaPath.body, CodingKeys.application))
    }
}

public enum TransportProtocol: String, Sendable, Hashable, Codable {
    case tcp
    case udp
}

public struct FlowSummary: Sendable, Hashable, Codable {
    /// A host name or an IP literal; never a URL.
    public let remoteHost: String
    public let remotePort: Int
    public let transport: TransportProtocol
    public let action: PolicyAction
    
    /// `nil` when the policy's default action decided.
    public let ruleIdentifier: String?
    
    public init(remoteHost: String, remotePort: Int, transport: TransportProtocol, action: PolicyAction, ruleIdentifier: String?) {
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.transport = transport
        self.action = action
        self.ruleIdentifier = ruleIdentifier
    }
    
    func validate(at path: String) throws(SchemaViolation) {
        guard FieldRules.isRemoteHost(remoteHost) else {
            throw SchemaViolation(path: SchemaPath.member(path, CodingKeys.remoteHost), reason: .malformedHost)
        }
        guard FieldRules.isPort(remotePort) else {
            throw SchemaViolation(path: SchemaPath.member(path, CodingKeys.remotePort), reason: .outOfRange)
        }
        if let ruleIdentifier, !FieldRules.isIdentifier(ruleIdentifier) {
            throw SchemaViolation(path: SchemaPath.member(path, CodingKeys.ruleIdentifier), reason: .malformedIdentifier)
        }
    }
}

public struct PolicyReference: Sendable, Hashable, Codable {
    public let identifier: String
    public let revision: Int64
    
    public init(identifier: String, revision: Int64) {
        self.identifier = identifier
        self.revision = revision
    }
    
    func validate(at path: String) throws(SchemaViolation) {
        try FieldRules.requireIdentifier(identifier, at: path, CodingKeys.identifier)
        try FieldRules.requireRevision(revision, at: path, CodingKeys.revision)
    }
}
