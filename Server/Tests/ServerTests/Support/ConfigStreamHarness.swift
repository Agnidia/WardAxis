//
//  ConfigStreamHarness.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdWSClient
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix
import NIOSSL
import NIOWebSocket
import ServerCore
import Testing
import WardAxisAPIServer

typealias ConfigMessage = Components.Schemas.ConfigMessage

/// The config stream on the real application core (HTTP, WebSocket upgrade and relay)
/// over in-memory doubles, behind the production TLS loader with a device CA, so every
/// stream test runs through the same mutual-TLS handshake that production requires.
/// WebSocket tests need `.live`: the router test mode has no port and no TLS.
struct ConfigStreamHarness: Sendable {
    /// Long heartbeat, idle and lifetime periods, so a test sees only the frames it provokes.
    static let quietPolicy: ConfigStreamPolicy = .init(
        maxConnectionsPerClient: 5,
        heartbeatInterval: .seconds(30),
        idleTimeout: .seconds(30),
        maximumConnectionLifetime: .seconds(3600),
        connectionLifetimeJitter: .zero,
        relayPollInterval: .seconds(30),
        subscriberBufferSize: 32,
        catchUpBatchSize: 256,
        retryBackoff: RetryBackoff(initial: .milliseconds(10), maximum: .milliseconds(50)),
        closeGracePeriod: .milliseconds(500)
    )
    
    let dependencies: ServerDependencies
    let configStore: any ConfigStore
    let notifier: any ConfigChangeNotifier
    /// Signs the listener's certificate; every test client trusts it.
    let serverAuthority: TestAuthority
    /// The CA in the listener's `TLS_CLIENT_CA_PATH` bundle.
    let deviceAuthority: TestAuthority
    private let mutualTLS: TLSConfiguration
    private let serverOnlyTLS: TLSConfiguration
    
    var hub: ConfigConnectionHub {
        dependencies.configHub
    }
    
    init(
        policy: ConfigStreamPolicy = ConfigStreamHarness.quietPolicy,
        configStore: any ConfigStore,
        notifier: any ConfigChangeNotifier = ManualConfigChangeNotifier()
    ) async throws {
        self.configStore = configStore
        self.notifier = notifier
        dependencies = ServerDependencies.testing(
            configStore: configStore,
            configNotifier: notifier,
            configStreamPolicy: policy
        )
        serverAuthority = try TestAuthority(name: "WardAxis test server CA")
        deviceAuthority = try TestAuthority(name: "WardAxis test device CA")
        mutualTLS = try await TestServerFiles.serverConfiguration(serverAuthority: serverAuthority, clientCAs: [deviceAuthority])
        serverOnlyTLS = try await TestServerFiles.serverConfiguration(serverAuthority: serverAuthority, clientCAs: nil)
    }
    
    /// How the listener terminates connections.
    enum Listener {
        /// TLS with the device CA: the production configuration that serves the stream.
        case mutualTLS
        /// TLS without `TLS_CLIENT_CA_PATH`: the stream route is not registered.
        case serverTLSOnly
        /// Plain TCP, for tests of the HTTP layer below TLS.
        case plain
    }
    
    func application(
        listener: Listener = .mutualTLS,
        httpIdleTimeout: TimeAmount = HTTPServerLimits.idleTimeout,
        logger: Logger = Logger(label: "test.config-stream")
    ) throws -> some ApplicationProtocol {
        let tlsConfiguration: TLSConfiguration? = switch listener {
        case .mutualTLS: mutualTLS
        case .serverTLSOnly: serverOnlyTLS
        case .plain: nil
        }
        return try buildApplicationCore(
            dependencies: dependencies,
            address: .hostname("127.0.0.1", port: 0),
            logger: logger,
            httpIdleTimeout: httpIdleTimeout,
            tlsConfiguration: tlsConfiguration
        )
    }
    
    /// A device holding a certificate the device CA issued, as enrollment leaves it.
    func enrollDevice() throws -> StreamDevice {
        let identity = try deviceAuthority.issueClientIdentity()
        return try StreamDevice(
            tlsConfiguration: .testClient(trusting: serverAuthority, identity: identity),
            client: identity.streamClient
        )
    }
    
    /// A client whose certificate another CA issued.
    func foreignDevice() throws -> StreamDevice {
        let identity = try TestAuthority(name: "Foreign CA").issueClientIdentity()
        return try StreamDevice(
            tlsConfiguration: .testClient(trusting: serverAuthority, identity: identity),
            client: identity.streamClient
        )
    }
    
    /// A client that trusts the server but presents no certificate.
    func anonymousClient() throws -> StreamDevice {
        try StreamDevice(tlsConfiguration: .testClient(trusting: serverAuthority, identity: nil), client: nil)
    }
    
    /// Waits until the relay has read its start version and listens for wake-ups.
    func waitForRelay() async throws {
        guard let manual = notifier as? ManualConfigChangeNotifier else { return }
        try await waitUntil("the relay listens") { manual.listenerCount > 0 }
    }
}

/// One stream client: its TLS settings and the slot key the server derives for it.
struct StreamDevice: Sendable {
    let tlsConfiguration: TLSConfiguration
    /// `nil` for a client without a certificate.
    let client: ConfigStreamClient?
    
    /// The slot key of a client with a certificate.
    var slot: ConfigStreamClient {
        guard let client else { preconditionFailure("A client without a certificate holds no slot") }
        return client
    }
}

/// What a client saw on one stream.
struct StreamRecording: Sendable {
    let messages: [ConfigMessage]
    /// The code of the server's close frame; `nil` when the stream ended without one.
    let closeCode: WebSocketErrorCode?
}

struct StreamTimeout: Error, CustomStringConvertible {
    let what: String
    var description: String {
        "Timed out waiting for \(what)"
    }
}

/// Polls `condition` every 10 ms; throws ``StreamTimeout`` after `timeout`.
func waitUntil(_ what: String, timeout: Duration = .seconds(3), _ condition: @Sendable () async throws -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while try await !condition() {
        guard ContinuousClock.now < deadline else { throw StreamTimeout(what: what) }
        try await Task.sleep(for: .milliseconds(10))
    }
}

/// Runs `operation`, or throws ``StreamTimeout`` when it takes longer than `timeout`, so a
/// stream that never closes fails the test instead of hanging the run.
func withTimeout<Value: Sendable>(
    _ timeout: Duration,
    _ what: String,
    _ operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw StreamTimeout(what: what)
        }
        defer { group.cancelAll() }
        guard let value = try await group.next() else { throw StreamTimeout(what: what) }
        return value
    }
}

/// Opens a TCP connection to the server, writes `bytes`, and returns once the server
/// closes the connection, so a test can observe a server-side timeout.
func holdRawConnection(port: Int, sending bytes: String) async throws {
    try await RawConnection.open(port: port).hold(sending: bytes)
}

/// A TCP connection that sends no request unless a test writes one.
struct RawConnection: Sendable {
    private let channel: NIOAsyncChannel<ByteBuffer, ByteBuffer>
    
    static func open(port: Int) async throws -> RawConnection {
        let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .connect(host: "localhost", port: port) { channel in
                channel.eventLoop.makeCompletedFuture {
                    try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                }
            }
        return RawConnection(channel: channel)
    }
    
    /// Writes `bytes`, then returns once the server closes the connection.
    func hold(sending bytes: String) async throws {
        try await channel.executeThenClose { inbound, outbound in
            if !bytes.isEmpty {
                try await outbound.write(ByteBuffer(string: bytes))
            }
            do {
                for try await _ in inbound {}
            } catch {
                // A reset ends the connection as a close does.
            }
        }
    }
}

extension TestClientProtocol {
    /// Opens `GET /v1/config/stream` as `device` over TLS and records every decoded frame.
    ///
    /// After each frame `stop` sees all frames so far; when it returns `true` the client
    /// closes normally. Otherwise recording ends when the server closes the stream.
    ///
    /// The stream runs on ``RawWebSocketClient``, not WSClient, which can miss a close frame
    /// sent right after the upgrade.
    ///
    /// - Parameters:
    ///   - extraHeaders: Raw header lines for the handshake, such as a spoofed identity.
    ///   - answerPings: `false` makes a client that never sends a pong.
    /// - Throws: `WebSocketClientError.webSocketUpgradeFailed` when the server does not
    ///   upgrade, the TLS error when the handshake fails, and ``StreamTimeout`` when the
    ///   stream is still open after `timeout`.
    func openConfigStream(
        as device: StreamDevice,
        path: String = "/v1/config/stream",
        extraHeaders: [String] = [],
        answerPings: Bool = true,
        timeout: Duration = .seconds(5),
        stop: @escaping @Sendable ([ConfigMessage]) async throws -> Bool = { _ in false }
    ) async throws -> StreamRecording {
        let port = try #require(port, "Needs a live server")
        let received = NIOLockedValueBox<[ConfigMessage]>([])
        let closeCode = try await withTimeout(timeout, "the config stream to end") {
            try await RawWebSocketClient.run(
                port: port,
                path: path,
                tlsConfiguration: device.tlsConfiguration,
                extraHeaders: extraHeaders,
                answerPings: answerPings
            ) { text in
                let decoded = try JSONDecoder().decode(ConfigMessage.self, from: Data(text.utf8))
                let all = received.withLockedValue { messages in
                    messages.append(decoded)
                    return messages
                }
                return try await stop(all)
            }
        }
        return StreamRecording(messages: received.withLockedValue { $0 }, closeCode: closeCode)
    }
    
    /// Sends a complete WebSocket handshake over a raw HTTP/1.1 connection and returns
    /// the response to it, so a test can read the status of a refused upgrade.
    /// Use it only where the upgrade must fail: a `101` leaves this client nothing to read.
    ///
    /// - Parameter tlsConfiguration: The client TLS settings; `nil` speaks plain HTTP.
    func rawWebSocketHandshake(
        path: String = "/v1/config/stream",
        headers extra: HTTPFields = [:],
        tlsConfiguration: TLSConfiguration? = nil
    ) async throws -> TestClient.Response {
        let port = try #require(port, "Needs a live server")
        var headers: HTTPFields = [
            .connection: "Upgrade",
            .upgrade: "websocket",
            .secWebSocketKey: "dGhlIHNhbXBsZSBub25jZQ==",
            .secWebSocketVersion: "13"
        ]
        headers.append(contentsOf: extra)
        let request = TestClient.Request(path, method: .get, authority: "localhost", headers: headers)
        return try await TestClient.withClient(
            host: "localhost",
            port: port,
            configuration: .init(tlsConfiguration: tlsConfiguration, timeout: .seconds(5))
        ) { client in
            try await client.execute(request)
        }
    }
}

extension ConfigMessage {
    var version: Int64 {
        switch self {
        case let .snapshot(snapshot): snapshot.version
        case let .delta(delta): delta.version
        case let .heartbeat(heartbeat): heartbeat.version
        }
    }
    
    var isSnapshot: Bool {
        if case .snapshot = self {
            true
        } else {
            false
        }
    }
    
    var isHeartbeat: Bool {
        if case .heartbeat = self {
            true
        } else {
            false
        }
    }
}

/// Decodes a JSON object literal into contract entries, for comparisons.
func configEntries(_ json: String) throws -> Components.Schemas.ConfigEntries {
    try JSONDecoder().decode(Components.Schemas.ConfigEntries.self, from: Data(json.utf8))
}

/// A one-way gate a test opens to let a waiting stream handler finish.
final class Gate: Sendable {
    private let opened: NIOLockedValueBox<Bool> = .init(false)
    
    func open() {
        opened.withLockedValue { $0 = true }
    }
    
    func wait() async throws {
        try await waitUntil("the gate to open", timeout: .seconds(10)) { self.opened.withLockedValue { $0 } }
    }
}
