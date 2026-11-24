//
//  ConfigStreamLimitTests.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Hummingbird
import HummingbirdTesting
import NIOWebSocket
import ServerCore
import Testing

@Suite("Config stream per-certificate cap")
struct ConfigStreamLimitTests {
    @Test("Over the cap the upgrade closes with 1013 before any frame; a freed slot is reusable and other certificates are unaffected")
    func perClientCap() async throws {
        var policy = ConfigStreamHarness.quietPolicy
        policy.maxConnectionsPerClient = 2
        let harness = try await ConfigStreamHarness(policy: policy, configStore: InMemoryConfigStore(version: 41))
        let alice = try harness.enrollDevice()
        let bob = try harness.enrollDevice()
        try await harness.application().test(.live) { client in
            let gates = [Gate(), Gate()]
            try await withThrowingTaskGroup(of: StreamRecording.self) { group in
                for gate in gates {
                    group.addTask {
                        try await client.openConfigStream(as: alice, timeout: .seconds(15)) { _ in
                            try await gate.wait()
                            return true
                        }
                    }
                }
                try await waitUntil("two open streams") { harness.hub.connectionCount(for: alice.slot) == 2 }

                let refused = try await client.openConfigStream(as: alice)
                #expect(refused.closeCode == .unknown(1013))
                #expect(refused.messages.isEmpty)
                #expect(harness.hub.connectionCount(for: alice.slot) == 2)

                let other = try await client.openConfigStream(as: bob) { $0.count == 1 }
                #expect(other.messages.first?.isSnapshot == true)

                gates[0].open()
                let finished = try await group.next()
                #expect(finished?.messages.first?.isSnapshot == true)
                try await waitUntil("a freed slot") { harness.hub.connectionCount(for: alice.slot) == 1 }

                let reused = try await client.openConfigStream(as: alice) { $0.count == 1 }
                #expect(reused.messages.first?.isSnapshot == true)

                gates[1].open()
                for try await _ in group {}
            }
            try await waitUntil("every slot released") { harness.hub.subscriberCount == 0 }
        }
    }

    @Test("While the relay has not started, a stream holds its slot, then closes with 1013 before any frame after the readiness timeout")
    func relayNotReadyCloses() async throws {
        var policy = ConfigStreamHarness.quietPolicy
        policy.maxConnectionsPerClient = 1
        policy.relayReadyTimeout = .milliseconds(300)
        let gated = try GatedConfigStore(base: InMemoryConfigStore(version: 41))
        let harness = try await ConfigStreamHarness(policy: policy, configStore: gated)
        let alice = try harness.enrollDevice()
        try await harness.application().test(.live) { client in
            try await waitUntil("the relay reads its start version") { gated.waitingReads == 1 }
            try await withThrowingTaskGroup(of: StreamRecording.self) { group in
                group.addTask {
                    try await client.openConfigStream(as: alice)
                }
                try await waitUntil("the stream holds its slot") { harness.hub.connectionCount(for: alice.slot) == 1 }
                let overCap = try await client.openConfigStream(as: alice)
                #expect(overCap.closeCode == .unknown(1013))

                let waited = try #require(try await group.next())
                #expect(waited.closeCode == .unknown(1013))
                #expect(waited.messages.isEmpty)
            }
            #expect(!harness.hub.isRelayReady)
            try await waitUntil("every slot released") { harness.hub.subscriberCount == 0 }
        }
    }
}
