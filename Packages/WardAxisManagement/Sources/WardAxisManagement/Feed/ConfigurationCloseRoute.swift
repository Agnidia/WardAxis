//
//  ConfigurationCloseRoute.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// What the service does after a connection ends.
///
/// Every reconnect waits for the backoff delay, so a server that repeats a close
/// cannot cause a reconnect storm.
enum ConfigurationCloseRoute: Sendable, Equatable {
    /// The server refused the device identity: stop until the enrollment changes.
    case identityRejected
    
    /// The server asked the client to wait, refused the handshake, or the
    /// connection failed: reconnect after the backoff.
    case backOff
    
    /// The server ended a healthy stream: reconnect for a new snapshot.
    case reconnect
    
    /// HTTP statuses that mean "this identity is not allowed", as opposed to a
    /// server that is unavailable or misconfigured.
    static let identityRejectedStatuses: Set<Int> = [401, 403]
    
    static func route(for close: ConfigurationStreamClose) -> ConfigurationCloseRoute {
        switch close {
        case .clientCertificateRejected, .closeCode(1008):
            .identityRejected
        case .handshakeRejected(let status) where identityRejectedStatuses.contains(status):
            .identityRejected
        case .closeCode(1000), .closeCode(1001), .closeCode(1011):
            .reconnect
        case .closeCode, .handshakeRejected, .connectionFailed, .bufferOverflow:
            .backOff
        }
    }
}
