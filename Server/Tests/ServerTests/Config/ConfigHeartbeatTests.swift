//
//  ConfigHeartbeatTests.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdWSClient
import HummingbirdWSTesting
import NIOConcurrencyHelpers
import NIOWebSocket
import ServerCore
import Testing

@Suite("Config stream heartbeat, idle close and connection deadlines")
struct ConfigHeartbeatTests {
    /// Heartbeat 100 ms and idle close 300 ms, as AC-9 names them.
    private static let fastPolicy: ConfigStreamPolicy = {
        var policy = ConfigStreamHarness.quietPolicy
        policy.heartbeatInterval = .milliseconds(100)
        policy.idleTimeout = .milliseconds(300)
        return policy
    }()

    @Test("The production policy: heartbeat 30 s, idle close 90 s, ping 45 s, lifetime 12 to 15 min, cap 5")
    func productionDefaults() {
        let policy = ConfigStreamPolicy.standard
        #expect(policy.heartbeatInterval == .seconds(30))
        #expect(policy.idleTimeout == .seconds(90))
        #expect(policy.pingInterval == .seconds(45))
        #expect(policy.maximumConnectionLifetime == .seconds(15 * 60))
        #expect(policy.connectionLifetimeJitter == .seconds(3 * 60))
        #expect(policy.relayPollInterval == .seconds(30))
        #expect(policy.maxConnectionsPerClient == 5)
    }

    @Test("A client that answers pings gets heartbeats with the current version and stays open past the idle timeout")
    func heartbeatsCarryCurrentVersion() async throws {
        let store = try InMemoryConfigStore(version: 41)
        let notifier = ManualConfigChangeNotifier()
        let harness = try await ConfigStreamHarness(policy: Self.fastPolicy, configStore: store, notifier: notifier)
        let user = try harness.enrollDevice()
        try await harness.application().test(.live) { client in
            try await harness.waitForRelay()
            let recording = try await client.openConfigStream(as: user) { messages in
                let heartbeats = messages.filter(\.isHeartbeat).count
                if heartbeats == 1, messages.last?.isHeartbeat == true {
                    try store.commit(changedJSON: #"{"theme":"light"}"#)
                    notifier.wake()
                }
                // Five heartbeats take at least 500 ms, beyond the 300 ms idle timeout.
                return heartbeats == 5
            }
            #expect(recording.closeCode != .goingAway)
            let heartbeats = recording.messages.filter(\.isHeartbeat)
            #expect(heartbeats.count == 5)
            #expect(heartbeats.first?.version == 41)
            #expect(heartbeats.last?.version == 42)
            // Each heartbeat carries the version the client has at that moment.
            var current: Int64 = -1
            for message in recording.messages {
                if message.isHeartbeat {
                    #expect(message.version == current)
                } else {
                    current = message.version
                }
            }
        }
    }

    @Test("The server closes a connection that answers no ping once the idle timeout passes")
    func silentClientIsClosed() async throws {
        var policy = ConfigStreamHarness.quietPolicy
        policy.idleTimeout = .milliseconds(300)
        let harness = try await ConfigStreamHarness(policy: policy, configStore: InMemoryConfigStore(version: 41))
        let user = try harness.enrollDevice()
        try await harness.application().test(.live) { client in
            try await withThrowingTaskGroup(of: StreamRecording.self) { group in
                group.addTask {
                    try await client.openConfigStream(as: user, answerPings: false)
                }
                try await waitUntil("the stream to open") { harness.hub.connectionCount(for: user.slot) == 1 }
                let opened = ContinuousClock.now
                try await waitUntil("the idle close") { harness.hub.connectionCount(for: user.slot) == 0 }
                let lifetime = ContinuousClock.now - opened
                #expect(lifetime >= .milliseconds(150))
                #expect(lifetime < .seconds(2))
                let recording = try #require(try await group.next())
                #expect(recording.closeCode == .goingAway)
            }
        }
    }

    @Test("An upgraded connection outlives the HTTP idle timeout")
    func httpIdleTimeoutDoesNotCloseStreams() async throws {
        let harness = try await ConfigStreamHarness(configStore: InMemoryConfigStore(version: 41))
        let user = try harness.enrollDevice()
        let openAfterWait = NIOLockedValueBox(false)
        try await harness.application(httpIdleTimeout: .milliseconds(200)).test(.live) { client in
            let recording = try await client.openConfigStream(as: user) { _ in
                try await Task.sleep(for: .milliseconds(600))
                openAfterWait.withLockedValue { $0 = harness.hub.connectionCount(for: user.slot) == 1 }
                return true
            }
            #expect(recording.messages.count == 1)
        }
        #expect(openAfterWait.withLockedValue { $0 })
    }

    @Test(
        "A connection that sends nothing, or only part of a request head, is closed at the HTTP idle timeout",
        arguments: ["", "GET /v1/config/stream HTTP/1.1\r\nHost: localhost\r\n"]
    )
    func incompleteFirstRequestIsClosed(sent: String) async throws {
        let harness = try await ConfigStreamHarness(configStore: InMemoryConfigStore(version: 41))
        // Plain TCP: the deadline sits below TLS, and a raw socket can stall at any byte.
        try await harness.application(listener: .plain, httpIdleTimeout: .milliseconds(300)).test(.live) { client in
            let port = try #require(client.port, "Needs a live server")
            let started = ContinuousClock.now
            try await withTimeout(.seconds(3), "the server to close the connection") {
                try await holdRawConnection(port: port, sending: sent)
            }
            // Closed by the deadline, not on arrival.
            #expect(ContinuousClock.now - started >= .milliseconds(250))
        }
    }

    @Test("Graceful shutdown closes a connection that has sent no request at once, not at the 30 s first-request deadline")
    func shutdownClosesSilentConnection() async throws {
        let harness = try await ConfigStreamHarness(configStore: InMemoryConfigStore(version: 41))
        let silent = NIOLockedValueBox<RawConnection?>(nil)
        let started = ContinuousClock.now
        try await harness.application(listener: .plain).test(.live) { client in
            let port = try #require(client.port, "Needs a live server")
            let connection = try await RawConnection.open(port: port)
            silent.withLockedValue { $0 = connection }
            // The listener accepts in order, so an answer on a later connection means the
            // silent one is accepted and shutdown has to close it.
            _ = try await client.rawWebSocketHandshake()
        }
        #expect(ContinuousClock.now - started < .seconds(10))
        let connection = try #require(silent.withLockedValue { $0 })
        try await withTimeout(.seconds(3), "the server to close the silent connection") {
            try await connection.hold(sending: "")
        }
    }
}
