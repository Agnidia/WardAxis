//
//  ConfigFanOutTests.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import NIOConcurrencyHelpers
import PostgresNIO
import ServerCore
import Testing

extension DatabaseSuites {
    /// The configuration store, change feed and stream on a real PostgreSQL.
    ///
    /// Enabled only when `TEST_DATABASE_URL` is set; CI sets it. Empties the config tables.
    @Suite(
        "Config feed (PostgreSQL)",
        .enabled(if: TestDatabase.url != nil, "Set TEST_DATABASE_URL to run")
    )
    struct ConfigFanOutTests {
        private struct RollbackRequested: Error {}
        
        /// Capped like production: below notice the driver logs bind values.
        private let logger: Logger = {
            var logger = Logger(label: "test.config.postgres")
            logger.logLevel = .notice
            return logger
        }()
        
        private static let policy: ConfigStreamPolicy = {
            var policy = ConfigStreamHarness.quietPolicy
            policy.retryBackoff = RetryBackoff(initial: .milliseconds(50), maximum: .milliseconds(200))
            return policy
        }()
        
        @Test
        func `Each statement that changes something adds exactly one version and one log row; no-ops, rollbacks and TRUNCATE add none`() async throws {
            try await TestDatabase.withClient(logger: logger) { client in
                try await TestDatabase.resetConfigData(on: client, logger: logger)
                let store = PostgresConfigStore(client: client, logger: logger)
                #expect(try await store.snapshot() == ConfigSnapshotRecord(version: 0, values: .init()))
                
                try await client.query(#"INSERT INTO config_entries (key, value) VALUES ('theme', '"dark"'), ('maxItems', '20')"#, logger: logger)
                #expect(try await store.currentVersion() == 1)
                try await client.query("UPDATE config_entries SET value = value", logger: logger)
                try await client.query("DELETE FROM config_entries WHERE key = 'missing'", logger: logger)
                #expect(try await store.currentVersion() == 1)
                try await client.query("UPDATE config_entries SET value = '25' WHERE key = 'maxItems'", logger: logger)
                try await client.query("DELETE FROM config_entries WHERE key = 'theme'", logger: logger)
                #expect(try await store.currentVersion() == 3)
                
                // PostgresNIO wraps the closure's error; an empty rollbackError means ROLLBACK ran.
                let rollback = await #expect(throws: PostgresTransactionError.self) {
                    try await client.withTransaction(logger: logger) { connection in
                        try await connection.query(#"INSERT INTO config_entries (key, value) VALUES ('rolledBack', 'true')"#, logger: logger)
                        throw RollbackRequested()
                    }
                }
                #expect(rollback?.closureError is RollbackRequested)
                #expect(rollback?.rollbackError == nil)
                await #expect(throws: (any Error).self) {
                    try await client.query("TRUNCATE config_entries", logger: logger)
                }
                #expect(try await store.currentVersion() == 3)
                try await client.query(#"INSERT INTO config_entries (key, value) VALUES ('flag', 'null')"#, logger: logger)
                
                let changes = try await store.changes(after: 0, limit: 10)
                #expect(changes.map(\.version) == [1, 2, 3, 4])
                #expect(try changes[0] == ConfigChange(version: 1, changed: configEntries(#"{"theme":"dark","maxItems":20}"#), removed: []))
                #expect(try changes[1] == ConfigChange(version: 2, changed: configEntries(#"{"maxItems":25}"#), removed: []))
                #expect(changes[2] == ConfigChange(version: 3, changed: .init(), removed: ["theme"]))
                #expect(try changes[3] == ConfigChange(version: 4, changed: configEntries(#"{"flag":null}"#), removed: []))
                #expect(try await store.changes(after: 1, limit: 1).map(\.version) == [2])
                #expect(try await store.snapshot() == ConfigSnapshotRecord(version: 4, values: configEntries(#"{"maxItems":25,"flag":null}"#)))
            }
        }
        
        @Test
        func `Two clients both get the next version's delta within 1 s of a commit in PostgreSQL`() async throws {
            try await TestDatabase.withClient(logger: logger) { client in
                try await TestDatabase.resetConfigData(on: client, logger: logger)
                try await client.query(#"INSERT INTO config_entries (key, value) VALUES ('theme', '"dark"')"#, logger: logger)
                let harness = try await makeHarness(client: client)
                let alice = try harness.enrollDevice()
                let bob = try harness.enrollDevice()
                try await harness.application().test(.live) { http in
                    _ = try await waitForListener(on: client)
                    let snapshots = NIOLockedValueBox(0)
                    let deliveries = NIOLockedValueBox<[ContinuousClock.Instant]>([])
                    try await withThrowingTaskGroup(of: StreamRecording.self) { group in
                        for user in [alice, bob] {
                            group.addTask {
                                try await http.openConfigStream(as: user) { messages in
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
                        try await client.query(#"UPDATE config_entries SET value = '"light"' WHERE key = 'theme'"#, logger: logger)
                        for try await recording in group {
                            #expect(recording.messages.map(\.version) == [1, 2])
                            guard case let .delta(delta) = recording.messages.last else {
                                Issue.record("Expected a delta, got \(recording.messages)")
                                continue
                            }
                            #expect(try delta.changed == configEntries(#"{"theme":"light"}"#))
                        }
                        for delivered in deliveries.withLockedValue({ $0 }) {
                            #expect(delivered - committed < .seconds(1))
                        }
                    }
                }
            }
        }
        
        @Test
        func `After the listener's connection drops, clients get the changes committed meanwhile, in order with no gap`() async throws {
            try await TestDatabase.withClient(logger: logger) { client in
                try await TestDatabase.resetConfigData(on: client, logger: logger)
                try await client.query(#"INSERT INTO config_entries (key, value) VALUES ('theme', '"dark"')"#, logger: logger)
                let harness = try await makeHarness(client: client)
                let alice = try harness.enrollDevice()
                let bob = try harness.enrollDevice()
                try await harness.application().test(.live) { http in
                    let listener = try await waitForListener(on: client)
                    let snapshots = NIOLockedValueBox(0)
                    try await withThrowingTaskGroup(of: StreamRecording.self) { group in
                        for user in [alice, bob] {
                            group.addTask {
                                try await http.openConfigStream(as: user, timeout: .seconds(10)) { messages in
                                    if messages.count == 1 {
                                        snapshots.withLockedValue { $0 += 1 }
                                    }
                                    return messages.count == 3
                                }
                            }
                        }
                        try await waitUntil("both snapshots") { snapshots.withLockedValue { $0 } == 2 }
                        try await client.query("SELECT pg_terminate_backend(\(listener))", logger: logger)
                        try await client.query(#"UPDATE config_entries SET value = '"light"' WHERE key = 'theme'"#, logger: logger)
                        try await client.query(#"INSERT INTO config_entries (key, value) VALUES ('maxItems', '25')"#, logger: logger)
                        for try await recording in group {
                            #expect(recording.messages.map(\.version) == [1, 2, 3])
                        }
                    }
                    let replacement = try await waitForListener(on: client)
                    #expect(replacement != listener)
                }
            }
        }
        
        private func makeHarness(client: PostgresClient) async throws -> ConfigStreamHarness {
            try await ConfigStreamHarness(
                policy: Self.policy,
                configStore: PostgresConfigStore(client: client, logger: logger),
                notifier: PostgresConfigChangeNotifier(client: client, backoff: Self.policy.retryBackoff, logger: logger)
            )
        }
        
        /// Waits for the backend that runs the relay's LISTEN and returns its process ID.
        private func waitForListener(on client: PostgresClient) async throws -> Int32 {
            let found = NIOLockedValueBox<Int32?>(nil)
            try await waitUntil("a LISTEN backend", timeout: .seconds(5)) {
                let rows = try await client.query(
                    """
                    SELECT pid FROM pg_stat_activity
                    WHERE datname = current_database() AND pid <> pg_backend_pid() AND query ILIKE 'LISTEN%config_changes%'
                    """,
                    logger: logger
                )
                for try await pid in rows.decode(Int32.self) {
                    found.withLockedValue { $0 = pid }
                }
                return found.withLockedValue { $0 } != nil
            }
            return try #require(found.withLockedValue { $0 })
        }
    }
}
