//
//  ServerTLS.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import NIOSSL

/// The PEM files the listener terminates TLS with, from `TLS_CERTIFICATE_CHAIN_PATH`,
/// `TLS_PRIVATE_KEY_PATH` and, for client-certificate verification, `TLS_CLIENT_CA_PATH`.
/// Paths only: the files stay outside the repository and the image.
package struct TLSFiles: Sendable, Equatable {
    /// The leaf certificate first, then any intermediates.
    package let certificateChainPath: String
    /// An unencrypted PEM key for the leaf certificate.
    package let privateKeyPath: String
    /// The device CA bundle (one or more PEM certificates) that every client certificate
    /// must chain to; `nil` means the listener asks for no client certificate.
    package let clientCertificateAuthorityPath: String?
    
    package init(certificateChainPath: String, privateKeyPath: String, clientCertificateAuthorityPath: String? = nil) {
        self.certificateChainPath = certificateChainPath
        self.privateKeyPath = privateKeyPath
        self.clientCertificateAuthorityPath = clientCertificateAuthorityPath
    }
}

/// Builds the listener's TLS settings from ``TLSFiles``.
package enum ServerTLS {
    /// TLS 1.2 suites with forward secrecy and an AEAD cipher only, the set App Transport
    /// Security accepts. TLS 1.3 negotiates its own suites, which are all of that kind.
    package static let cipherSuites: String = "ECDHE+AESGCM:ECDHE+CHACHA20"
    
    /// Loads the chain, the key and the optional device CA bundle, and checks them with one
    /// TLS context, so a bad file fails start-up before the listener binds.
    ///
    /// With a device CA, every handshake must present a client certificate that chains to
    /// it; a client without one, or with one from another CA, fails the handshake and never
    /// reaches HTTP. Host names are not checked (`noHostnameVerification`), because a
    /// device certificate names a device, not a host; the chain to the CA is the check.
    ///
    /// - Throws: ``ConfigurationError/invalid(variable:reason:)`` naming the variable whose
    ///   file is unreadable, malformed or does not match. The reason never quotes the path
    ///   or the file's bytes.
    package static func configuration(for files: TLSFiles) throws(ConfigurationError) -> TLSConfiguration {
        let chainVariable = AppConfiguration.Variable.tlsCertificateChainPath
        let keyVariable = AppConfiguration.Variable.tlsPrivateKeyPath
        
        guard let chainPEM = FileManager.default.contents(atPath: files.certificateChainPath) else {
            throw .invalid(variable: chainVariable, reason: "must name a readable file")
        }
        let chain: [NIOSSLCertificate]
        do {
            chain = try NIOSSLCertificate.fromPEMBytes(Array(chainPEM))
        } catch {
            throw .invalid(variable: chainVariable, reason: "must hold a PEM certificate chain")
        }
        guard !chain.isEmpty else {
            throw .invalid(variable: chainVariable, reason: "must hold a PEM certificate chain")
        }
        
        guard let keyPEM = FileManager.default.contents(atPath: files.privateKeyPath) else {
            throw .invalid(variable: keyVariable, reason: "must name a readable file")
        }
        let key: NIOSSLPrivateKey
        do {
            key = try NIOSSLPrivateKey(bytes: Array(keyPEM), format: .pem)
        } catch {
            throw .invalid(variable: keyVariable, reason: "must hold an unencrypted PEM private key")
        }
        
        var configuration = TLSConfiguration.makeServerConfiguration(
            certificateChain: chain.map { .certificate($0) },
            privateKey: .privateKey(key)
        )
        configuration.minimumTLSVersion = .tlsv12
        configuration.cipherSuites = cipherSuites
        configuration.applicationProtocols = ["http/1.1"]
        if let authorityPath = files.clientCertificateAuthorityPath {
            let authorities = try loadClientCertificateAuthorities(at: authorityPath)
            configuration.trustRoots = .certificates(authorities)
            configuration.certificateVerification = .noHostnameVerification
            // Lists the device CA in the CertificateRequest, so a client that holds several
            // identities offers the one this server accepts.
            configuration.sendCANameList = true
        }
        do {
            _ = try NIOSSLContext(configuration: configuration)
        } catch {
            throw .invalid(variable: keyVariable, reason: "must be the private key of the chain's first certificate")
        }
        return configuration
    }
    
    /// Whether `configuration` makes every handshake present a verified client certificate.
    /// The config stream is mounted only when this is `true`.
    package static func requiresClientCertificates(_ configuration: TLSConfiguration) -> Bool {
        guard case .certificates(let roots) = configuration.trustRoots, !roots.isEmpty else {
            return false
        }
        // `.none` includes optional verification, which admits a client with no certificate.
        switch configuration.certificateVerification {
        case .fullVerification, .noHostnameVerification:
            return true
        case .none:
            return false
        }
    }
    
    private static func loadClientCertificateAuthorities(at path: String) throws(ConfigurationError) -> [NIOSSLCertificate] {
        let variable = AppConfiguration.Variable.tlsClientCAPath
        guard let pem = FileManager.default.contents(atPath: path) else {
            throw .invalid(variable: variable, reason: "must name a readable file")
        }
        let authorities: [NIOSSLCertificate]
        do {
            authorities = try NIOSSLCertificate.fromPEMBytes(Array(pem))
        } catch {
            throw .invalid(variable: variable, reason: "must hold one or more PEM CA certificates")
        }
        guard !authorities.isEmpty else {
            throw .invalid(variable: variable, reason: "must hold one or more PEM CA certificates")
        }
        return authorities
    }
}
