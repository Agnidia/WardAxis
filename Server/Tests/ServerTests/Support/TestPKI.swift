//
//  TestPKI.swift
//
//  Created on 24.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Crypto
import Foundation
import NIOSSL
import ServerCore
import SwiftASN1
import X509

/// A P-256 certificate authority made for one test run. No key or certificate is committed.
struct TestAuthority: Sendable {
    let name: String
    let key: P256.Signing.PrivateKey
    let certificate: Certificate

    init(name: String) throws {
        self.name = name
        key = P256.Signing.PrivateKey()
        let subject = try DistinguishedName {
            CommonName(name)
        }
        let now = Date()
        certificate = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: Certificate.PublicKey(key.publicKey),
            notValidBefore: now.addingTimeInterval(-3600),
            notValidAfter: now.addingTimeInterval(3600),
            issuer: subject,
            subject: subject,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: Certificate.Extensions {
                Critical(BasicConstraints.isCertificateAuthority(maxPathLength: 0))
                Critical(KeyUsage(keyCertSign: true))
            },
            issuerPrivateKey: Certificate.PrivateKey(key)
        )
    }

    var pem: String {
        get throws {
            try certificate.serializeAsPEM().pemString
        }
    }

    var nioCertificate: NIOSSLCertificate {
        get throws {
            try NIOSSLCertificate(bytes: Array(pem.utf8), format: .pem)
        }
    }

    /// A server leaf for `localhost` and `127.0.0.1`, as the listener presents it.
    func issueServerLeaf() throws -> (certificate: Certificate, key: P256.Signing.PrivateKey) {
        let leafKey = P256.Signing.PrivateKey()
        let certificate = try issue(
            subject: DistinguishedName { CommonName("localhost") },
            key: leafKey,
            extensions: Certificate.Extensions {
                Critical(BasicConstraints.notCertificateAuthority)
                SubjectAlternativeNames([.dnsName("localhost"), .ipAddress(ASN1OctetString(contentBytes: [127, 0, 0, 1]))])
                Critical(KeyUsage(digitalSignature: true))
                try ExtendedKeyUsage([.serverAuth])
            }
        )
        return (certificate, leafKey)
    }

    /// A device client identity, as enrollment would issue it: no host name, client auth only.
    func issueClientIdentity(commonName: String = "device-\(UUID().uuidString.lowercased())") throws -> TestClientIdentity {
        let leafKey = P256.Signing.PrivateKey()
        let certificate = try issue(
            subject: DistinguishedName { CommonName(commonName) },
            key: leafKey,
            extensions: Certificate.Extensions {
                Critical(BasicConstraints.notCertificateAuthority)
                Critical(KeyUsage(digitalSignature: true))
                try ExtendedKeyUsage([.clientAuth])
            }
        )
        return try TestClientIdentity(
            certificate: NIOSSLCertificate(bytes: Array(certificate.serializeAsPEM().pemString.utf8), format: .pem),
            key: NIOSSLPrivateKey(bytes: Array(leafKey.pemRepresentation.utf8), format: .pem)
        )
    }

    private func issue(subject: DistinguishedName, key leafKey: P256.Signing.PrivateKey, extensions: Certificate.Extensions) throws -> Certificate {
        let now = Date()
        return try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: Certificate.PublicKey(leafKey.publicKey),
            notValidBefore: now.addingTimeInterval(-3600),
            notValidAfter: now.addingTimeInterval(3600),
            issuer: certificate.subject,
            subject: subject,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: extensions,
            issuerPrivateKey: Certificate.PrivateKey(key)
        )
    }
}

/// A client certificate and its key, in the form NIOSSL takes.
struct TestClientIdentity: Sendable {
    let certificate: NIOSSLCertificate
    let key: NIOSSLPrivateKey

    /// The slot key the server derives from this certificate.
    var streamClient: ConfigStreamClient {
        get throws {
            try ConfigStreamClient(certificateDER: certificate.toDERBytes())
        }
    }
}

/// The listener's TLS files under a private temporary directory, removed after `body`.
enum TestServerFiles {
    struct FileNotCreated: Error {}

    /// Writes the server chain, its key and, when `clientCA` is set, the device CA bundle.
    ///
    /// - Parameters:
    ///   - serverAuthority: Signs the server leaf; clients trust it.
    ///   - clientCAs: The PEM bundle written to the `TLS_CLIENT_CA_PATH` file; `nil` writes none.
    static func with<Value>(
        serverAuthority: TestAuthority,
        clientCAs: [TestAuthority]?,
        _ body: (TLSFiles, URL) async throws -> Value
    ) async throws -> Value {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent("server-mtls-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? fileManager.removeItem(at: directory) }

        let leaf = try serverAuthority.issueServerLeaf()
        let chainURL = directory.appendingPathComponent("chain.pem")
        let keyURL = directory.appendingPathComponent("key.pem")
        try Data(leaf.certificate.serializeAsPEM().pemString.utf8).write(to: chainURL)
        guard fileManager.createFile(atPath: keyURL.path, contents: Data(leaf.key.pemRepresentation.utf8), attributes: [.posixPermissions: 0o600]) else {
            throw FileNotCreated()
        }
        var clientCAPath: String?
        if let clientCAs {
            let caURL = directory.appendingPathComponent("device-ca.pem")
            try Data(clientCAs.map { try $0.pem }.joined(separator: "\n").utf8).write(to: caURL)
            clientCAPath = caURL.path
        }
        let files = TLSFiles(certificateChainPath: chainURL.path, privateKeyPath: keyURL.path, clientCertificateAuthorityPath: clientCAPath)
        return try await body(files, directory)
    }

    /// The listener's TLS configuration, loaded by the production loader; the files are
    /// removed before this returns.
    static func serverConfiguration(serverAuthority: TestAuthority, clientCAs: [TestAuthority]?) async throws -> TLSConfiguration {
        try await with(serverAuthority: serverAuthority, clientCAs: clientCAs) { files, _ in
            try ServerTLS.configuration(for: files)
        }
    }
}

extension TLSConfiguration {
    /// A client that trusts only `serverAuthority`, checks the host name `localhost`, and
    /// presents `identity` when one is given.
    static func testClient(trusting serverAuthority: TestAuthority, identity: TestClientIdentity?) throws -> TLSConfiguration {
        var configuration = TLSConfiguration.makeClientConfiguration()
        configuration.trustRoots = try .certificates([serverAuthority.nioCertificate])
        configuration.certificateVerification = .fullVerification
        if let identity {
            configuration.certificateChain = [.certificate(identity.certificate)]
            configuration.privateKey = .privateKey(identity.key)
        }
        return configuration
    }
}
