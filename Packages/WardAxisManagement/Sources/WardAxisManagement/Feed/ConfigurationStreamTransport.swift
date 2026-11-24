//
//  ConfigurationStreamTransport.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Opens one configuration feed connection.
///
/// The returned stream yields ``ConfigurationStreamEvent/opened`` at most once,
/// then each frame, and ends after exactly one ``ConfigurationStreamEvent/closed(_:)``.
/// When the consumer stops iterating (its task is cancelled or it drops the
/// stream), the transport closes the connection with a normal closure.
public protocol ConfigurationStreamTransport: Sendable {
    /// Opens `request`, answering a client-certificate challenge with `identity` only.
    func open(_ request: URLRequest, identity: ClientIdentity) -> AsyncStream<ConfigurationStreamEvent>
}

/// What one connection reports.
public enum ConfigurationStreamEvent: Sendable, Equatable {
    /// The WebSocket handshake completed.
    case opened

    /// One frame's payload.
    case message(Data)

    /// The connection ended. Always the last event.
    case closed(ConfigurationStreamClose)
}

/// Why a connection ended, in the terms the close routing needs.
public enum ConfigurationStreamClose: Sendable, Equatable {
    /// The WebSocket closed with this close code.
    case closeCode(Int)

    /// The server answered the upgrade with this HTTP status instead of `101`.
    case handshakeRejected(statusCode: Int)

    /// The TLS handshake failed because the server refused, or required and did
    /// not get, the client certificate.
    case clientCertificateRejected

    /// The connection failed without a close code or an HTTP status.
    case connectionFailed
}
