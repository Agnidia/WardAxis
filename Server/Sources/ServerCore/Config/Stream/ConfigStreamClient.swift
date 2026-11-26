//
//  ConfigStreamClient.swift
//
//  Created on 24.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// The connection-slot key of one config stream client: the DER bytes of the leaf
/// certificate that the TLS handshake verified against the device CA.
///
/// A slot key only, never an identity: nothing reads a name, serial or device ID from it,
/// so it grants nothing beyond the per-client connection cap. It comes from the TLS layer
/// alone, never from a header, so a client cannot claim another client's slots without
/// that client's private key.
package struct ConfigStreamClient: Hashable, Sendable, CustomStringConvertible, CustomReflectable {
    private let certificateDER: [UInt8]
    
    package init(certificateDER: [UInt8]) {
        self.certificateDER = certificateDER
    }
    
    /// Never prints the certificate, so the key cannot reach a log line.
    package var description: String {
        "ConfigStreamClient(redacted)"
    }
    
    /// No children, so `dump` and debugger output cannot print the certificate either.
    package var customMirror: Mirror {
        Mirror(self, children: [])
    }
}
