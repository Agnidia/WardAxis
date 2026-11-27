//
//  TLSListenerTests.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Crypto
import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import NIOCore
import NIOPosix
import NIOSSL
import NIOTLS
import ServerCore
import SwiftASN1
import Testing
import X509

/// The listener with TLS on, and the loader that reads its PEM files.
///
/// Each test makes its own certificates: a P-256 CA and a leaf it signs for `localhost` and
/// `127.0.0.1`, valid from one hour ago to one hour ahead. The leaf and its key go to a
/// private temporary directory that the test removes. No key or certificate is committed.
@Suite("TLS listener")
struct TLSListenerTests {
    @Test(arguments: [TLSVersion.tlsv12, .tlsv13])
    func `GET /v1/health over TLS 1.2 and TLS 1.3, with full certificate verification, answers 200`(version: TLSVersion) async throws {
        try await TestCertificate.withFiles { certificate in
            try await Self.withTLSServer(certificate.files) { port in
                let response = try await TestClient.withClient(
                    host: "localhost",
                    port: port,
                    configuration: .init(tlsConfiguration: certificate.clientConfiguration(minimum: version, maximum: version), timeout: .seconds(5))
                ) { client in
                    try await client.get("/v1/health")
                }
                #expect(response.status == .ok)
            }
        }
    }
    
    @Test
    func `A plaintext HTTP request to the TLS port gets no HTTP response`() async throws {
        try await TestCertificate.withFiles { certificate in
            try await Self.withTLSServer(certificate.files) { port in
                _ = try await TestClient.withClient(host: "localhost", port: port, configuration: .init(timeout: .seconds(5))) { client in
                    await #expect(throws: (any Error).self) {
                        _ = try await client.get("/v1/health")
                    }
                }
            }
        }
    }
    
    @Test
    func `A client limited to TLS 1.1 is refused with a protocol-version alert, while TLS 1.2 completes the handshake`() async throws {
        try await TestCertificate.withFiles { certificate in
            try await Self.withTLSServer(certificate.files) { port in
                try await TLSHandshake.run(port: port, configuration: certificate.clientConfiguration(minimum: .tlsv12, maximum: .tlsv12))
                let error = await #expect(throws: NIOSSLError.self) {
                    try await TLSHandshake.run(port: port, configuration: certificate.clientConfiguration(minimum: .tlsv1, maximum: .tlsv11))
                }
                // A protocol-version alert, not a cipher mismatch: the version floor refused it.
                #expect(String(describing: error).contains("PROTOCOL_VERSION"), "\(String(describing: error))")
            }
        }
    }
    
    @Test
    func `A TLS 1.2 client that offers only RSA key-exchange and CBC suites cannot complete the handshake`() async throws {
        // ECDHE-ECDSA-*-SHA is CBC and would work with the test's ECDSA certificate, so only the server's suite list stops it.
        let weakOnly = "AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA:AES256-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA"
        try await TestCertificate.withFiles { certificate in
            try await Self.withTLSServer(certificate.files) { port in
                var weak = try certificate.clientConfiguration(minimum: .tlsv12, maximum: .tlsv12)
                weak.cipherSuites = weakOnly
                let rejected = weak
                await #expect(throws: NIOSSLError.self) {
                    try await TLSHandshake.run(port: port, configuration: rejected)
                }
                try await TLSHandshake.run(port: port, configuration: certificate.clientConfiguration(minimum: .tlsv12, maximum: .tlsv12))
            }
        }
    }
    
    // MARK: Loader
    
    @Test
    func `The loader sets TLS 1.2 as the floor, forward-secret AEAD suites and HTTP/1.1 only`() async throws {
        try await TestCertificate.withFiles { certificate in
            let configuration = try ServerTLS.configuration(for: certificate.files)
            #expect(configuration.minimumTLSVersion == .tlsv12)
            #expect(configuration.maximumTLSVersion == nil)
            #expect(configuration.cipherSuites == ServerTLS.cipherSuites)
            #expect(configuration.applicationProtocols == ["http/1.1"])
            #expect(configuration.certificateChain.count == 1)
        }
    }
    
    @Test
    func `A missing, malformed or mismatched file fails with the variable's name and never its path`() async throws {
        try await TestCertificate.withFiles { certificate in
            let directory = certificate.directory
            let missing = directory.appendingPathComponent("missing.pem").path
            let garbage = directory.appendingPathComponent("garbage.pem")
            try Data("not a PEM file\n".utf8).write(to: garbage)
            let otherKey = directory.appendingPathComponent("other-key.pem")
            try Data(P256.Signing.PrivateKey().pemRepresentation.utf8).write(to: otherKey)
            
            let chainVariable = AppConfiguration.Variable.tlsCertificateChainPath
            let keyVariable = AppConfiguration.Variable.tlsPrivateKeyPath
            let cases: [(TLSFiles, String)] = [
                (TLSFiles(certificateChainPath: missing, privateKeyPath: certificate.files.privateKeyPath), chainVariable),
                (TLSFiles(certificateChainPath: garbage.path, privateKeyPath: certificate.files.privateKeyPath), chainVariable),
                (TLSFiles(certificateChainPath: certificate.files.certificateChainPath, privateKeyPath: missing), keyVariable),
                (TLSFiles(certificateChainPath: certificate.files.certificateChainPath, privateKeyPath: garbage.path), keyVariable),
                (TLSFiles(certificateChainPath: certificate.files.certificateChainPath, privateKeyPath: otherKey.path), keyVariable)
            ]
            for (files, variable) in cases {
                do throws(ConfigurationError) {
                    _ = try ServerTLS.configuration(for: files)
                    Issue.record("Expected \(variable) to be rejected")
                } catch {
                    guard case .invalid(let reported, _) = error else {
                        Issue.record("Expected .invalid, got \(error)")
                        continue
                    }
                    #expect(reported == variable)
                    #expect(!error.description.contains(directory.lastPathComponent))
                }
            }
        }
    }
    
    /// Runs the production application core with TLS on an ephemeral port.
    private static func withTLSServer(_ files: TLSFiles, _ body: @escaping @Sendable (Int) async throws -> Void) async throws {
        let dependencies = ServerDependencies.testing()
        let application = try buildApplicationCore(
            dependencies: dependencies,
            address: .hostname("127.0.0.1", port: 0),
            logger: Logger(label: "test.tls"),
            tlsConfiguration: ServerTLS.configuration(for: files)
        )
        // The live framework's own client speaks plain HTTP; the tests open their own.
        try await application.test(.live) { client in
            let port = try #require(client.port)
            try await body(port)
        }
    }
}

/// A server leaf in PEM files under a private directory, from ``TestServerFiles``, and
/// the CA that signed it.
private struct TestCertificate: Sendable {
    let directory: URL
    let files: TLSFiles
    let authority: TestAuthority
    
    /// A client that trusts only the test CA and checks the host name `localhost`.
    func clientConfiguration(minimum: TLSVersion, maximum: TLSVersion) throws -> TLSConfiguration {
        var configuration = try TLSConfiguration.testClient(trusting: authority, identity: nil)
        configuration.minimumTLSVersion = minimum
        configuration.maximumTLSVersion = maximum
        return configuration
    }
    
    /// Creates the files, runs `body`, then deletes the directory whatever `body` does.
    static func withFiles<Value>(_ body: (TestCertificate) async throws -> Value) async throws -> Value {
        let authority = try TestAuthority(name: "WardAxis test CA")
        return try await TestServerFiles.with(serverAuthority: authority, clientCAs: nil) { files, directory in
            try await body(TestCertificate(directory: directory, files: files, authority: authority))
        }
    }
}

/// A TLS handshake alone, with no HTTP after it, so a test reads the handshake's own
/// outcome rather than a later write's failure on a closed channel.
private enum TLSHandshake {
    /// Returns once the handshake completes; throws the handshake's error otherwise.
    static func run(port: Int, configuration: TLSConfiguration) async throws {
        let context = try NIOSSLContext(configuration: configuration)
        let outcome = MultiThreadedEventLoopGroup.singleton.any().makePromise(of: Void.self)
        let channel: any Channel
        do {
            channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
                .channelInitializer { channel in
                    channel.eventLoop.makeCompletedFuture {
                        try channel.pipeline.syncOperations.addHandler(NIOSSLClientHandler(context: context, serverHostname: "localhost"))
                        try channel.pipeline.syncOperations.addHandler(OutcomeHandler(outcome: outcome))
                    }
                }
                .connect(host: "localhost", port: port)
                .get()
        } catch {
            // A promise dropped uncompleted is a leak NIO reports; a second completion is ignored.
            outcome.fail(error)
            throw error
        }
        defer { channel.close(promise: nil) }
        try await outcome.futureResult.get()
    }
    
    /// Completes `outcome` once: on the handshake event, the first error, or a close.
    private final class OutcomeHandler: ChannelInboundHandler {
        typealias InboundIn = ByteBuffer
        
        private let outcome: EventLoopPromise<Void>
        private var completed: Bool = false
        
        init(outcome: EventLoopPromise<Void>) {
            self.outcome = outcome
        }
        
        func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
            if case TLSUserEvent.handshakeCompleted = event {
                complete(.success(()))
            }
            context.fireUserInboundEventTriggered(event)
        }
        
        func errorCaught(context: ChannelHandlerContext, error: any Error) {
            complete(.failure(error))
            context.close(promise: nil)
        }
        
        func channelInactive(context: ChannelHandlerContext) {
            complete(.failure(ChannelError.eof))
            context.fireChannelInactive()
        }
        
        private func complete(_ result: Result<Void, any Error>) {
            guard !completed else { return }
            completed = true
            outcome.completeWith(result)
        }
    }
}
