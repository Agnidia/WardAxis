//
//  ServerEnvironment.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// The deployment the server runs in, from `SERVER_ENVIRONMENT`.
///
/// An absent value means ``production``, so a deployment that forgets the variable gets
/// the strict checks rather than the relaxed ones.
package enum ServerEnvironment: String, Sendable, Equatable, CaseIterable {
    /// A developer machine or the compose stack: allows plain HTTP and serves the API
    /// reference.
    case development
    /// Any shared deployment.
    case production
}
