//
//  ConfigChangeRelayTests.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Logging
import ServerCore
import Testing

@Suite("Config change relay")
struct ConfigChangeRelayTests {
    private static func policy(pollInterval: Duration = .seconds(30), batchSize: Int = 256) -> ConfigStreamPolicy {
        var policy = ConfigStreamHarness.quietPolicy
        policy.relayPollInterval = pollInterval
        policy.catchUpBatchSize = batchSize
        return policy
    }
    
    /// Runs the relay for the duration of `body`, then cancels it.
    private static func withRelay(
        store: InMemoryConfigStore,
        notifier: ManualConfigChangeNotifier,
        hub: ConfigConnectionHub,
        policy: ConfigStreamPolicy,
        _ body: () async throws -> Void
    ) async throws {
        let relay = ConfigChangeRelay(store: store, notifier: notifier, hub: hub, policy: policy, logger: Logger(label: "test.relay"))
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await relay.run() }
            defer { group.cancelAll() }
            try await body()
        }
    }
    
    private static func versions(_ subscription: ConfigSubscription, count: Int) async throws -> [Int64] {
        try await withTimeout(.seconds(2), "\(count) relayed frames") {
            var versions: [Int64] = []
            for await frame in subscription.frames {
                let decoded = try JSONDecoder().decode(ConfigMessage.self, from: Data(frame.text.utf8))
                #expect(decoded.version == frame.version)
                versions.append(frame.version)
                if versions.count == count {
                    break
                }
            }
            return versions
        }
    }
    
    @Test
    func `A wake-up publishes the changes after the start version, in order, and nothing from before`() async throws {
        let store = try InMemoryConfigStore(version: 5)
        try store.commit(changedJSON: #"{"a":1}"#)
        let notifier = ManualConfigChangeNotifier()
        let hub = ConfigConnectionHub(maxConnectionsPerClient: 5, bufferSize: 32)
        let subscription = try #require(hub.register(client: .sample()))
        try await Self.withRelay(store: store, notifier: notifier, hub: hub, policy: Self.policy()) {
            try await waitUntil("the relay listens") { notifier.listenerCount == 1 }
            try store.commit(changedJSON: #"{"a":2}"#)
            try store.commit(changedJSON: "{}", removed: ["a"])
            notifier.wake()
            #expect(try await Self.versions(subscription, count: 2) == [7, 8])
        }
    }
    
    @Test
    func `Without any notification the poll relays a change`() async throws {
        let store = try InMemoryConfigStore(version: 0)
        let notifier = ManualConfigChangeNotifier()
        let hub = ConfigConnectionHub(maxConnectionsPerClient: 5, bufferSize: 32)
        let subscription = try #require(hub.register(client: .sample()))
        try await Self.withRelay(store: store, notifier: notifier, hub: hub, policy: Self.policy(pollInterval: .milliseconds(50))) {
            try await waitUntil("the relay listens") { notifier.listenerCount == 1 }
            try store.commit(changedJSON: #"{"a":1}"#)
            #expect(try await Self.versions(subscription, count: 1) == [1])
        }
    }
    
    @Test
    func `A read error loses nothing: the next trigger relays from the same version`() async throws {
        let store = try InMemoryConfigStore(version: 0)
        let notifier = ManualConfigChangeNotifier()
        let hub = ConfigConnectionHub(maxConnectionsPerClient: 5, bufferSize: 32)
        let subscription = try #require(hub.register(client: .sample()))
        try await Self.withRelay(store: store, notifier: notifier, hub: hub, policy: Self.policy()) {
            try await waitUntil("the relay listens") { notifier.listenerCount == 1 }
            try store.commit(changedJSON: #"{"a":1}"#)
            store.setFailing(true)
            notifier.wake()
            try await Task.sleep(for: .milliseconds(100))
            store.setFailing(false)
            try store.commit(changedJSON: #"{"a":2}"#)
            notifier.wake()
            #expect(try await Self.versions(subscription, count: 2) == [1, 2])
        }
    }
    
    @Test
    func `At start the relay retries until the store answers, as it does while migrations run`() async throws {
        let store = try InMemoryConfigStore(version: 3)
        store.setFailing(true)
        let notifier = ManualConfigChangeNotifier()
        let hub = ConfigConnectionHub(maxConnectionsPerClient: 5, bufferSize: 32)
        try await Self.withRelay(store: store, notifier: notifier, hub: hub, policy: Self.policy()) {
            try await Task.sleep(for: .milliseconds(100))
            #expect(notifier.listenerCount == 0)
            store.setFailing(false)
            try await waitUntil("the relay listens") { notifier.listenerCount == 1 }
        }
    }
    
    @Test
    func `The relay marks the hub ready only once it has read its start version`() async throws {
        let store = try InMemoryConfigStore(version: 3)
        store.setFailing(true)
        let notifier = ManualConfigChangeNotifier()
        let hub = ConfigConnectionHub(maxConnectionsPerClient: 5, bufferSize: 32)
        try await Self.withRelay(store: store, notifier: notifier, hub: hub, policy: Self.policy()) {
            try await Task.sleep(for: .milliseconds(100))
            #expect(!hub.isRelayReady)
            store.setFailing(false)
            try await waitUntil("the relay is ready") { hub.isRelayReady }
        }
    }
    
    @Test
    func `A client admitted while the relay starts gets every version after its snapshot, with no gap and no later commit needed`() async throws {
        let store = try InMemoryConfigStore(version: 5, valuesJSON: #"{"a":0}"#)
        let gated = GatedConfigStore(base: store)
        let notifier = ManualConfigChangeNotifier()
        let harness = try await ConfigStreamHarness(configStore: gated, notifier: notifier)
        let user = try harness.enrollDevice()
        try await harness.application().test(.live) { client in
            try await waitUntil("the relay reads its start version") { gated.waitingReads == 1 }
            try await withThrowingTaskGroup(of: StreamRecording.self) { group in
                group.addTask {
                    // Version 7 commits only once the client holds version 6, so the stream
                    // ends only if version 6, committed during start-up, reached the client.
                    try await client.openConfigStream(as: user, timeout: .seconds(5)) { messages in
                        if messages.last?.version == 6 {
                            try store.commit(changedJSON: #"{"a":2}"#)
                            notifier.wake()
                        }
                        return messages.last?.version == 7
                    }
                }
                try await waitUntil("the stream holds its slot") { harness.hub.subscriberCount == 1 }
                try store.commit(changedJSON: #"{"a":1}"#)
                gated.gate.open()
                
                let recording = try #require(try await group.next())
                #expect(recording.messages.first?.isSnapshot == true)
                #expect(recording.messages.map(\.version) == [6, 7])
            }
        }
    }
    
    @Test
    func `A backlog larger than one batch is relayed completely, in order`() async throws {
        let store = try InMemoryConfigStore(version: 0)
        let notifier = ManualConfigChangeNotifier()
        let hub = ConfigConnectionHub(maxConnectionsPerClient: 5, bufferSize: 32)
        let subscription = try #require(hub.register(client: .sample()))
        try await Self.withRelay(store: store, notifier: notifier, hub: hub, policy: Self.policy(batchSize: 2)) {
            try await waitUntil("the relay listens") { notifier.listenerCount == 1 }
            for value in 1...5 {
                try store.commit(changedJSON: #"{"a":\#(value)}"#)
            }
            notifier.wake()
            #expect(try await Self.versions(subscription, count: 5) == [1, 2, 3, 4, 5])
        }
    }
    
    @Test
    func `Retry delays grow exponentially, stay within the cap and never drop below half the step`() {
        let backoff = RetryBackoff(initial: .milliseconds(100), maximum: .seconds(1))
        for _ in 0..<50 {
            let first = backoff.delay(forAttempt: 1)
            #expect(first >= .milliseconds(50) && first <= .milliseconds(100))
            let third = backoff.delay(forAttempt: 3)
            #expect(third >= .milliseconds(200) && third <= .milliseconds(400))
            let late = backoff.delay(forAttempt: 40)
            #expect(late >= .milliseconds(500) && late <= .seconds(1))
        }
    }
}
