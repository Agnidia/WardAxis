//
//  ConfigStreamSnapshotTests.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Hummingbird
import HummingbirdTesting
import NIOConcurrencyHelpers
import NIOWebSocket
import ServerCore
import Testing
import WardAxisAPIContract

@Suite("Config stream snapshot and deltas")
struct ConfigStreamSnapshotTests {
    private static let seed = #"{"theme":"dark","maxItems":20}"#
    
    @Test
    func `Frames encode as the contract's ConfigMessage text, keys sorted`() throws {
        let snapshot = try ConfigSnapshotRecord(version: 41, values: configEntries(Self.seed))
        #expect(try ConfigFrameEncoder.snapshot(snapshot) == #"{"type":"snapshot","values":{"maxItems":20,"theme":"dark"},"version":41}"#)
        let change = try ConfigChange(version: 42, changed: configEntries(#"{"maxItems":25}"#), removed: ["theme"])
        #expect(try ConfigFrameEncoder.delta(change) == ConfigDeltaFrame(
            version: 42,
            text: #"{"changed":{"maxItems":25},"removed":["theme"],"type":"delta","version":42}"#
        ))
        #expect(try ConfigFrameEncoder.heartbeat(version: 42) == #"{"type":"heartbeat","version":42}"#)
    }
    
    @Test
    func `The first frame is a snapshot with the store's version and values`() async throws {
        let store = try InMemoryConfigStore(version: 41, valuesJSON: Self.seed)
        let harness = try await ConfigStreamHarness(configStore: store)
        let user = try harness.enrollDevice()
        try await harness.application().test(.live) { client in
            let recording = try await client.openConfigStream(as: user) { $0.count == 1 }
            guard case .snapshot(let snapshot) = try #require(recording.messages.first) else {
                Issue.record("The first frame is not a snapshot: \(recording.messages)")
                return
            }
            #expect(snapshot.version == 41)
            #expect(try snapshot.values == configEntries(Self.seed))
        }
    }
    
    @Test
    func `Two clients each receive the next version's delta within 1 s of a commit`() async throws {
        let store = try InMemoryConfigStore(version: 41, valuesJSON: Self.seed)
        let notifier = ManualConfigChangeNotifier()
        let harness = try await ConfigStreamHarness(configStore: store, notifier: notifier)
        let alice = try harness.enrollDevice()
        let bob = try harness.enrollDevice()
        try await harness.application().test(.live) { client in
            try await harness.waitForRelay()
            let snapshots = NIOLockedValueBox(0)
            let deliveries = NIOLockedValueBox<[ContinuousClock.Instant]>([])
            try await withThrowingTaskGroup(of: StreamRecording.self) { group in
                for user in [alice, bob] {
                    group.addTask {
                        try await client.openConfigStream(as: user) { messages in
                            if messages.count == 1 {
                                snapshots.withLockedValue { $0 += 1 }
                            } else {
                                deliveries.withLockedValue { $0.append(.now) }
                            }
                            return messages.count == 2
                        }
                    }
                }
                try await waitUntil("both snapshots") { snapshots.withLockedValue { $0 } == 2 }
                let committed = ContinuousClock.now
                try store.commit(changedJSON: #"{"maxItems":25}"#, removed: ["theme"])
                notifier.wake()
                
                var recordings: [StreamRecording] = []
                for try await recording in group {
                    recordings.append(recording)
                }
                #expect(recordings.count == 2)
                for recording in recordings {
                    guard case .delta(let delta) = try #require(recording.messages.last) else {
                        Issue.record("Expected a delta, got \(recording.messages)")
                        continue
                    }
                    #expect(delta.version == 42)
                    #expect(try delta.changed == configEntries(#"{"maxItems":25}"#))
                    #expect(delta.removed == ["theme"])
                }
                for delivered in deliveries.withLockedValue({ $0 }) {
                    #expect(delivered - committed < .seconds(1))
                }
            }
        }
    }
    
    @Test
    func `Frames at or below the session's version are skipped, and a skipped-ahead delta is preceded by the missing ones from the store`() async throws {
        let store = try InMemoryConfigStore(version: 41, valuesJSON: Self.seed)
        let harness = try await ConfigStreamHarness(configStore: store)
        let user = try harness.enrollDevice()
        try await harness.application().test(.live) { client in
            let recording = try await client.openConfigStream(as: user) { messages in
                if messages.count == 1 {
                    // A stale frame first; then 42 and 43 commit, and only 43 is published.
                    harness.hub.publish(ConfigDeltaFrame(version: 41, text: #"{"type":"delta","version":41,"changed":{},"removed":[]}"#))
                    try store.commit(changedJSON: #"{"maxItems":21}"#)
                    try store.commit(changedJSON: #"{"maxItems":22}"#)
                    let latest = try #require(store.change(at: 43))
                    try harness.hub.publish(ConfigFrameEncoder.delta(latest))
                }
                return messages.count == 3
            }
            #expect(recording.messages.map(\.version) == [41, 42, 43])
            guard case .delta(let filled) = recording.messages[1] else {
                Issue.record("Expected delta 42, got \(recording.messages)")
                return
            }
            #expect(try filled.changed == configEntries(#"{"maxItems":21}"#))
        }
    }
    
    @Test
    func `When the store's log cannot fill a gap, the stream closes with 1011 so the client takes a new snapshot`() async throws {
        let store = try InMemoryConfigStore(version: 41, valuesJSON: Self.seed)
        let harness = try await ConfigStreamHarness(configStore: store)
        let user = try harness.enrollDevice()
        try await harness.application().test(.live) { client in
            let recording = try await client.openConfigStream(as: user) { messages in
                if messages.count == 1 {
                    try store.commit(changedJSON: #"{"maxItems":21}"#)
                    try store.commit(changedJSON: #"{"maxItems":22}"#)
                    store.pruneLog(through: 42)
                    let latest = try #require(store.change(at: 43))
                    try harness.hub.publish(ConfigFrameEncoder.delta(latest))
                }
                return false
            }
            #expect(recording.closeCode == .unexpectedServerError)
            #expect(recording.messages.map(\.version) == [41])
        }
    }
    
    @Test
    func `A store error while reading the snapshot closes the stream with 1011 before any frame`() async throws {
        let store = try InMemoryConfigStore(version: 41, valuesJSON: Self.seed)
        let harness = try await ConfigStreamHarness(configStore: store)
        let user = try harness.enrollDevice()
        try await harness.application().test(.live) { client in
            try await harness.waitForRelay()
            store.setFailing(true)
            let recording = try await client.openConfigStream(as: user)
            #expect(recording.closeCode == .unexpectedServerError)
            #expect(recording.messages.isEmpty)
            try await waitUntil("every slot released") { harness.hub.subscriberCount == 0 }
        }
    }
    
    @Test(arguments: [
        // One byte past the frame bound once the envelope is added.
        #"{"blob":"\#(String(repeating: "x", count: ConfigStreamLimits.maximumFrameBytes))"}"#,
        // One level deeper than the client accepts: envelope, `values`, then the nest.
        #"{"deep":\#(String(repeating: "[", count: ConfigStreamLimits.maximumNestingDepth - 1))\#(String(repeating: "]", count: ConfigStreamLimits.maximumNestingDepth - 1))}"#
    ])
    func `A snapshot the client would refuse is never sent; the stream closes with 1011 before any frame`(valuesJSON: String) async throws {
        let store = try InMemoryConfigStore(version: 41, valuesJSON: valuesJSON)
        let harness = try await ConfigStreamHarness(configStore: store)
        let user = try harness.enrollDevice()
        try await harness.application().test(.live) { client in
            try await harness.waitForRelay()
            let recording = try await client.openConfigStream(as: user)
            #expect(recording.closeCode == .unexpectedServerError)
            #expect(recording.messages.isEmpty)
        }
    }
    
    @Test
    func `A delta the client would refuse is never sent; the stream closes with 1011 after the snapshot`() async throws {
        let store = try InMemoryConfigStore(version: 41, valuesJSON: Self.seed)
        let harness = try await ConfigStreamHarness(configStore: store)
        let user = try harness.enrollDevice()
        let nest = String(repeating: "[", count: ConfigStreamLimits.maximumNestingDepth - 1)
            + String(repeating: "]", count: ConfigStreamLimits.maximumNestingDepth - 1)
        try await harness.application().test(.live) { client in
            try await harness.waitForRelay()
            let recording = try await client.openConfigStream(as: user) { messages in
                if messages.count == 1 {
                    try store.commit(changedJSON: #"{"deep":\#(nest)}"#)
                    let change = try #require(store.change(at: 42))
                    try harness.hub.publish(ConfigFrameEncoder.delta(change))
                }
                return false
            }
            #expect(recording.closeCode == .unexpectedServerError)
            #expect(recording.messages.map(\.version) == [41])
        }
    }
}
