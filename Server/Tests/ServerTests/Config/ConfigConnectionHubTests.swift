//
//  ConfigConnectionHubTests.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import ServerCore
import Testing

extension ConfigStreamClient {
    /// A distinct slot key with stand-in bytes; the hub never parses them.
    static func sample() -> ConfigStreamClient {
        ConfigStreamClient(certificateDER: Array(UUID().uuidString.utf8))
    }
}

@Suite("Config connection hub")
struct ConfigConnectionHubTests {
    private static func frame(_ version: Int64) -> ConfigDeltaFrame {
        ConfigDeltaFrame(version: version, text: "v\(version)")
    }
    
    private static func collect(_ subscription: ConfigSubscription, count: Int) async throws -> [Int64] {
        try await withTimeout(.seconds(2), "\(count) frames") {
            var versions: [Int64] = []
            for await frame in subscription.frames {
                versions.append(frame.version)
                if versions.count == count {
                    break
                }
            }
            return versions
        }
    }
    
    @Test
    func `Each client certificate gets at most the cap of slots; a released slot is free again; clients do not share slots`() throws {
        let hub = ConfigConnectionHub(maxConnectionsPerClient: 2, bufferSize: 4)
        let alice = ConfigStreamClient.sample()
        let bob = ConfigStreamClient.sample()
        let first = try #require(hub.register(client: alice))
        _ = try #require(hub.register(client: alice))
        #expect(hub.register(client: alice) == nil)
        #expect(hub.connectionCount(for: alice) == 2)
        #expect(hub.register(client: bob) != nil)
        
        hub.unregister(first)
        hub.unregister(first)
        #expect(hub.connectionCount(for: alice) == 1)
        #expect(hub.register(client: alice) != nil)
        #expect(hub.subscriberCount == 3)
    }
    
    @Test
    func `The slot key never prints the certificate`() {
        let client = ConfigStreamClient(certificateDER: Array("sample-certificate-bytes".utf8))
        #expect(String(describing: client) == "ConfigStreamClient(redacted)")
        var dumped = ""
        dump(client, to: &dumped)
        #expect(!dumped.contains("certificateDER"))
    }
    
    @Test
    func `Concurrent registrations never exceed the cap`() async {
        let hub = ConfigConnectionHub(maxConnectionsPerClient: 5, bufferSize: 4)
        let user = ConfigStreamClient.sample()
        let granted = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<50 {
                group.addTask { hub.register(client: user) != nil }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        #expect(granted == 5)
        #expect(hub.connectionCount(for: user) == 5)
    }
    
    @Test
    func `Every subscriber receives every published frame, in order`() async throws {
        let hub = ConfigConnectionHub(maxConnectionsPerClient: 5, bufferSize: 8)
        let first = try #require(hub.register(client: .sample()))
        let second = try #require(hub.register(client: .sample()))
        for version in Int64(1)...3 {
            hub.publish(Self.frame(version))
        }
        #expect(try await Self.collect(first, count: 3) == [1, 2, 3])
        #expect(try await Self.collect(second, count: 3) == [1, 2, 3])
    }
    
    @Test
    func `A slow subscriber keeps only the newest frames, and unregistering ends its stream`() async throws {
        let hub = ConfigConnectionHub(maxConnectionsPerClient: 5, bufferSize: 2)
        let subscription = try #require(hub.register(client: .sample()))
        for version in Int64(1)...5 {
            hub.publish(Self.frame(version))
        }
        hub.unregister(subscription)
        var versions: [Int64] = []
        for await frame in subscription.frames {
            versions.append(frame.version)
        }
        #expect(versions == [4, 5])
        #expect(hub.subscriberCount == 0)
    }
    
    // MARK: Relay readiness
    
    @Test
    func `Readiness is a one-way latch: every waiter resumes with true, a second mark changes nothing, and a later caller returns at once`() async throws {
        let hub = ConfigConnectionHub(maxConnectionsPerClient: 5, bufferSize: 4)
        #expect(!hub.isRelayReady)
        try await withThrowingTaskGroup(of: Bool.self) { group in
            for _ in 0..<3 {
                group.addTask { await hub.awaitRelayReady() }
            }
            try await Task.sleep(for: .milliseconds(50))
            hub.markRelayReady()
            hub.markRelayReady()
            var results: [Bool] = []
            for try await result in group {
                results.append(result)
            }
            #expect(results == [true, true, true])
        }
        #expect(hub.isRelayReady)
        #expect(try await withTimeout(.seconds(1), "an immediate answer") { await hub.awaitRelayReady() })
    }
    
    @Test
    func `A waiter whose task is cancelled returns false, and the hub stays not ready`() async throws {
        let hub = ConfigConnectionHub(maxConnectionsPerClient: 5, bufferSize: 4)
        let waiter = Task { await hub.awaitRelayReady() }
        try await Task.sleep(for: .milliseconds(50))
        waiter.cancel()
        #expect(await waiter.value == false)
        #expect(!hub.isRelayReady)
        
        let alreadyCancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await hub.awaitRelayReady()
        }
        #expect(await alreadyCancelled.value == false)
    }
}
