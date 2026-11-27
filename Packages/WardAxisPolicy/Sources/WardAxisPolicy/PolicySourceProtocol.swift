//
//  PolicySourceProtocol.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisCore

/// Supplies the policy that a component enforces.
public protocol PolicySourceProtocol: Sendable {
    /// The current policy, decoded through ``SchemaCodec``. A refusal leaves
    /// the caller on its last good policy.
    func currentPolicy() async throws(SchemaError) -> SecurityPolicy
}
