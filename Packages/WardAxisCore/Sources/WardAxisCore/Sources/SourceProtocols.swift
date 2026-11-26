//
//  SourceProtocols.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// A producer of security events: an enforcement component, the lab adapter,
/// or a synthetic stand-in.
public protocol SecurityEventSourceProtocol: Sendable {
    /// Up to `maximumCount` events, oldest first, never more than
    /// ``SchemaLimits/maximumBatchSize``. A `maximumCount` of zero or less returns
    /// an empty batch and consumes nothing; otherwise an empty batch means the source is exhausted.
    func nextBatch(maximumCount: Int) async throws -> [SecurityEvent]
}

/// Resolves a process to its code-signing identity.
public protocol ApplicationIdentityResolverProtocol: Sendable {
    /// `nil` when the process has exited, its PID was reused, or its signature
    /// cannot be read. A caller treats `nil` as an unknown application, never as a match.
    func identity(of process: ProcessReference) async -> ApplicationIdentity?
}

/// Supplies the policy that a component enforces.
public protocol PolicySourceProtocol: Sendable {
    /// The current policy, decoded through ``SchemaCodec``. A refusal leaves
    /// the caller on its last good policy.
    func currentPolicy() async throws(SchemaError) -> SecurityPolicy
}
