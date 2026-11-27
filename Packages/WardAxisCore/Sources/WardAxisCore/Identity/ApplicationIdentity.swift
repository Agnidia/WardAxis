//
//  ApplicationIdentity.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// The code-signing identity of an application, as a resolver reads it from
/// the code signature. Never derived from a process name or a path, which the
/// process controls.
public struct ApplicationIdentity: SchemaBody, Hashable {
    public static let schemaKind = SchemaKind.applicationIdentity
    public static let supportedVersions = SchemaVersion.onlyV1
    public static let currentVersion = SchemaVersion.v1
    
    public let signingIdentifier: String
    
    /// `nil` for Apple platform binaries and for ad hoc signatures.
    public let teamIdentifier: String?
    
    public let isPlatformBinary: Bool
    
    public let bundleIdentifier: String?
    
    public init(signingIdentifier: String, teamIdentifier: String?, isPlatformBinary: Bool, bundleIdentifier: String?) {
        self.signingIdentifier = signingIdentifier
        self.teamIdentifier = teamIdentifier
        self.isPlatformBinary = isPlatformBinary
        self.bundleIdentifier = bundleIdentifier
    }
    
    public init(from decoder: any Decoder) throws {
        try SchemaCodec.requireCodec(decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        signingIdentifier = try container.decode(String.self, forKey: .signingIdentifier)
        teamIdentifier = try container.decodeIfPresent(String.self, forKey: .teamIdentifier)
        isPlatformBinary = try container.decode(Bool.self, forKey: .isPlatformBinary)
        bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
    }
    
    public func validate() throws(SchemaViolation) {
        try validate(at: SchemaPath.body)
    }
    
    func validate(at path: String) throws(SchemaViolation) {
        try FieldRules.requireSigningIdentifier(signingIdentifier, at: path, CodingKeys.signingIdentifier)
        if let teamIdentifier {
            guard FieldRules.isTeamIdentifier(teamIdentifier) else {
                throw SchemaViolation(path: SchemaPath.member(path, CodingKeys.teamIdentifier), reason: .malformedTeamIdentifier)
            }
            // Apple signs platform binaries with no Team ID; a claim of both is forged.
            guard !isPlatformBinary else {
                throw SchemaViolation(path: SchemaPath.member(path, CodingKeys.teamIdentifier), reason: .contradictory)
            }
        }
        try FieldRules.requireSigningIdentifier(bundleIdentifier, at: path, CodingKeys.bundleIdentifier)
    }
}

/// A policy's reference to one application.
///
/// A signing identifier alone is chosen by the developer, so any team can
/// claim any identifier. A matcher therefore pins the Team ID, or names an
/// Apple platform binary. `WardAxisPolicy` evaluates a matcher against a flow
/// (ADR 0016).
public struct ApplicationMatcher: Sendable, Hashable, Codable {
    public let signingIdentifier: String
    public let teamIdentifier: String?
    public let isPlatformBinary: Bool
    
    /// An extra criterion that narrows the match; `nil` accepts any bundle. It
    /// never replaces the Team ID pin, because a bundle ID is as claimable as a
    /// signing identifier.
    public let bundleIdentifier: String?
    
    public init(signingIdentifier: String, teamIdentifier: String?, isPlatformBinary: Bool, bundleIdentifier: String? = nil) {
        self.signingIdentifier = signingIdentifier
        self.teamIdentifier = teamIdentifier
        self.isPlatformBinary = isPlatformBinary
        self.bundleIdentifier = bundleIdentifier
    }
    
    /// Refuses a matcher that names a signing identifier alone, which any developer can claim (ADR 0011 D3).
    public func validate(at path: String) throws(SchemaViolation) {
        try FieldRules.requireSigningIdentifier(signingIdentifier, at: path, CodingKeys.signingIdentifier)
        switch (teamIdentifier, isPlatformBinary) {
        case (.some(let team), false):
            guard FieldRules.isTeamIdentifier(team) else {
                throw SchemaViolation(path: SchemaPath.member(path, CodingKeys.teamIdentifier), reason: .malformedTeamIdentifier)
            }
        case (nil, true):
            break
        case (nil, false):
            throw SchemaViolation(path: SchemaPath.member(path, CodingKeys.teamIdentifier), reason: .missingRequired)
        case (.some, true):
            throw SchemaViolation(path: SchemaPath.member(path, CodingKeys.teamIdentifier), reason: .contradictory)
        }
        try FieldRules.requireSigningIdentifier(bundleIdentifier, at: path, CodingKeys.bundleIdentifier)
    }
}

/// One process, as the kernel's audit token names it.
///
/// The PID version changes when a PID is reused, so a resolver keyed by both
/// never attributes a new process to the identity of an exited one.
public struct ProcessReference: Sendable, Hashable {
    public let pid: Int32
    public let pidVersion: Int32
    
    public init(pid: Int32, pidVersion: Int32) {
        self.pid = pid
        self.pidVersion = pidVersion
    }
}
