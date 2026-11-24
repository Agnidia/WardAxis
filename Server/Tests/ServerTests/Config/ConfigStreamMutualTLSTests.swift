//
//  ConfigStreamMutualTLSTests.swift
//
//  Created on 24.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import NIOSSL
import NIOWebSocket
import ServerCore
import Testing

/// The config stream's only credential is a client certificate from the device CA, checked
/// in the TLS handshake. These tests attack that boundary on the real listener: no
/// certificate, a certificate from another CA, spoofed identity headers, a listener without
/// a device CA, and a stream held past its lifetime.
@Suite("Config stream mutual TLS")
struct ConfigStreamMutualTLSTests {
    @Test("A client without a certificate fails the handshake and never holds a slot")
    func noCertificateFailsHandshake() async throws {
        let harness = try await ConfigStreamHarness(configStore: InMemoryConfigStore(version: 41))
        let anonymous = try harness.anonymousClient()
        try await harness.application().test(.live) { client in
            await #expect(throws: (any Error).self) {
                _ = try await client.openConfigStream(as: anonymous)
            }
            #expect(harness.hub.subscriberCount == 0)
        }
    }

    @Test("A client certificate from another CA fails the handshake, whatever identity headers it sends")
    func foreignCertificateFailsHandshake() async throws {
        let harness = try await ConfigStreamHarness(configStore: InMemoryConfigStore(version: 41))
        let enrolled = try harness.enrollDevice()
        let foreign = try harness.foreignDevice()
        let spoofed = [
            "Authorization: Bearer sample-token",
            "X-Client-Cert: sample",
            "X-Forwarded-Client-Cert: Hash=sample",
            "X-Device-ID: sample-device"
        ]
        try await harness.application().test(.live) { client in
            await #expect(throws: (any Error).self) {
                _ = try await client.openConfigStream(as: foreign, extraHeaders: spoofed)
            }
            #expect(harness.hub.subscriberCount == 0)
            // The same listener still serves an enrolled device.
            let recording = try await client.openConfigStream(as: enrolled) { $0.count == 1 }
            #expect(recording.messages.first?.isSnapshot == true)
        }
    }

    @Test("A device-CA certificate connects without any Authorization header and gets the snapshot first")
    func deviceCertificateGetsSnapshot() async throws {
        let store = try InMemoryConfigStore(version: 41, valuesJSON: #"{"theme":"dark"}"#)
        let harness = try await ConfigStreamHarness(configStore: store)
        let device = try harness.enrollDevice()
        try await harness.application().test(.live) { client in
            let recording = try await client.openConfigStream(as: device) { messages in
                #expect(harness.hub.connectionCount(for: device.slot) == 1)
                return messages.count == 1
            }
            guard case let .snapshot(snapshot) = try #require(recording.messages.first) else {
                Issue.record("Expected a snapshot first, got \(recording.messages)")
                return
            }
            #expect(snapshot.version == 41)
            #expect(snapshot.values == (try configEntries(#"{"theme":"dark"}"#)))
            try await waitUntil("the slot is released") { harness.hub.subscriberCount == 0 }
        }
    }

    @Test("Two certificates from the device CA hold separate slots")
    func slotsArePerCertificate() async throws {
        let harness = try await ConfigStreamHarness(configStore: InMemoryConfigStore(version: 41))
        let first = try harness.enrollDevice()
        let second = try harness.enrollDevice()
        #expect(first.slot != second.slot)
    }

    @Test("Without TLS_CLIENT_CA_PATH, GET /v1/config/stream answers 404 over TLS, and a handshake is refused without an upgrade")
    func routeAbsentWithoutClientCA() async throws {
        let harness = try await ConfigStreamHarness(configStore: InMemoryConfigStore(version: 41))
        let logs = LogCapture()
        try await harness.application(listener: .serverTLSOnly, logger: logs.makeLogger()).test(.live) { client in
            let port = try #require(client.port)
            let tls = try TLSConfiguration.testClient(trusting: harness.serverAuthority, identity: nil)
            let plain = try await TestClient.withClient(
                host: "localhost",
                port: port,
                configuration: .init(tlsConfiguration: tls, timeout: .seconds(5))
            ) { client in
                try await client.get("/v1/config/stream")
            }
            #expect(plain.status == .notFound)
            #expect(try decodeJSON(ErrorBody.self, from: #require(plain.body)).code == "not_found")

            // No WebSocket route exists, so the library refuses the handshake as it refuses
            // every one it does not upgrade: a bare 400.
            let handshake = try await client.rawWebSocketHandshake(headers: [.authorization: "Bearer sample-token"], tlsConfiguration: tls)
            #expect(handshake.status == .badRequest)
            #expect(harness.hub.subscriberCount == 0)
        }
        let notices = logs.records.filter { $0.message.hasPrefix("Config stream disabled") }
        #expect(notices.count == 1)
        #expect(notices.first?.level == .notice)
    }

    @Test("The lifetime cap closes an open stream with 1000 lifetime and releases its slot")
    func lifetimeCapClosesStream() async throws {
        var policy = ConfigStreamHarness.quietPolicy
        policy.maximumConnectionLifetime = .milliseconds(400)
        let harness = try await ConfigStreamHarness(policy: policy, configStore: InMemoryConfigStore(version: 41))
        let device = try harness.enrollDevice()
        try await harness.application().test(.live) { client in
            try await harness.waitForRelay()
            let started = ContinuousClock.now
            let recording = try await client.openConfigStream(as: device, timeout: .seconds(5))
            let elapsed = ContinuousClock.now - started
            #expect(recording.closeCode == .normalClosure)
            #expect(recording.messages.map(\.isSnapshot) == [true])
            #expect(elapsed >= .milliseconds(350))
            #expect(elapsed < .seconds(3))
            try await waitUntil("the slot is released") { harness.hub.subscriberCount == 0 }

            // The device reconnects with a new handshake and gets a new snapshot.
            let again = try await client.openConfigStream(as: device) { $0.count == 1 }
            #expect(again.messages.first?.isSnapshot == true)
        }
    }

    @Test("Each stream's lifetime lies between the maximum less the jitter and the maximum")
    func lifetimeJitterBounds() {
        var policy = ConfigStreamPolicy.standard
        for _ in 0..<200 {
            let lifetime = policy.connectionLifetime()
            #expect(lifetime <= policy.maximumConnectionLifetime)
            #expect(lifetime >= policy.maximumConnectionLifetime - policy.connectionLifetimeJitter)
        }
        policy.connectionLifetimeJitter = .zero
        #expect(policy.connectionLifetime() == policy.maximumConnectionLifetime)
        policy.connectionLifetimeJitter = policy.maximumConnectionLifetime * 2
        for _ in 0..<50 {
            #expect(policy.connectionLifetime() >= .zero)
        }
    }

    // MARK: Loader

    @Test("A device CA bundle makes the listener require a verified client certificate without a host name check")
    func loaderRequiresClientCertificates() async throws {
        let server = try TestAuthority(name: "Server CA")
        let devices = try [TestAuthority(name: "Device CA 1"), TestAuthority(name: "Device CA 2")]
        let mutual = try await TestServerFiles.serverConfiguration(serverAuthority: server, clientCAs: devices)
        #expect(mutual.certificateVerification == .noHostnameVerification)
        #expect(mutual.sendCANameList)
        guard case let .certificates(roots) = mutual.trustRoots else {
            Issue.record("Expected the device CA bundle as trust roots")
            return
        }
        #expect(roots.count == 2)
        #expect(ServerTLS.requiresClientCertificates(mutual))
        #expect(mutual.minimumTLSVersion == .tlsv12)

        let serverOnly = try await TestServerFiles.serverConfiguration(serverAuthority: server, clientCAs: nil)
        #expect(!ServerTLS.requiresClientCertificates(serverOnly))
        var optional = mutual
        optional.certificateVerification = .optionalVerification
        #expect(!ServerTLS.requiresClientCertificates(optional))
    }

    @Test("A missing, malformed or empty device CA file fails start-up naming TLS_CLIENT_CA_PATH and never its path")
    func loaderRejectsBadClientCA() async throws {
        let server = try TestAuthority(name: "Server CA")
        try await TestServerFiles.with(serverAuthority: server, clientCAs: nil) { files, directory in
            let missing = directory.appendingPathComponent("missing.pem").path
            let garbage = directory.appendingPathComponent("garbage.pem")
            try Data("not a PEM file\n".utf8).write(to: garbage)
            let empty = directory.appendingPathComponent("empty.pem")
            try Data().write(to: empty)
            for path in [missing, garbage.path, empty.path] {
                let candidate = TLSFiles(
                    certificateChainPath: files.certificateChainPath,
                    privateKeyPath: files.privateKeyPath,
                    clientCertificateAuthorityPath: path
                )
                do throws(ConfigurationError) {
                    _ = try ServerTLS.configuration(for: candidate)
                    Issue.record("Expected the device CA file to be rejected")
                } catch {
                    guard case let .invalid(variable, _) = error else {
                        Issue.record("Expected .invalid, got \(error)")
                        continue
                    }
                    #expect(variable == AppConfiguration.Variable.tlsClientCAPath)
                    #expect(!error.description.contains(directory.lastPathComponent))
                }
            }
        }
    }
}
