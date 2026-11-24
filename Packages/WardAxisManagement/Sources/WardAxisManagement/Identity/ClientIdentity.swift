//
//  ClientIdentity.swift
//
//  Created on 24.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Security

/// The device's TLS client identity: a certificate issued by the management
/// server's device CA and the private key it certifies.
///
/// The private key stays in the Keychain (ideally non-extractable); this value
/// only references it, so passing it around never copies key material.
public struct ClientIdentity: @unchecked Sendable {
    // @unchecked: the credential wraps immutable SecIdentity and SecCertificate
    // objects, which the Security framework documents as safe from any thread.

    /// The credential for a client-certificate challenge. Scoped to the URL
    /// session, which the feed creates per connection.
    public let credential: URLCredential

    /// - Parameter intermediates: Sent after the leaf, so the server can build the
    ///   chain to its device CA without fetching anything.
    public init(identity: SecIdentity, intermediates: [SecCertificate] = []) {
        credential = URLCredential(identity: identity, certificates: intermediates, persistence: .forSession)
    }

    /// A stand-in for tests that never reach a TLS stack.
    init(testCredential: URLCredential) {
        credential = testCredential
    }
}

public enum ClientIdentityError: Error, Sendable, Equatable {
    /// The Keychain refused the read. The identity may be readable later, for
    /// example after the first unlock.
    case osStatus(Int32)
}

/// Supplies the identity the feed presents in the TLS handshake.
public protocol ClientIdentityProvider: Sendable {
    /// The current identity, or `nil` when the device holds none (not enrolled).
    func currentIdentity() async throws(ClientIdentityError) -> ClientIdentity?
}
