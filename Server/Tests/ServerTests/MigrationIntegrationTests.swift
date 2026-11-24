//
//  MigrationIntegrationTests.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Logging
import PostgresNIO
import ServerCore
import Testing

extension DatabaseSuites {
    /// Runs the migration runner against a real database.
    ///
    /// Enabled only when `TEST_DATABASE_URL` is set (CI sets it for its `postgres:18`
    /// service). The tests drop `schema_migrations` and every shipped table, so point the
    /// variable at a disposable database only. Serialized by ``DatabaseSuites``: every test
    /// resets one schema.
    @Suite(
        "Migration runner (PostgreSQL)",
        .enabled(if: TestDatabase.url != nil, "Set TEST_DATABASE_URL to run")
    )
    struct MigrationIntegrationTests {
        private static let testMigrations: [Migration] = [
            Migration(version: 1, name: "baseline", statements: []),
            Migration(
                version: 2,
                name: "create_widgets",
                statements: [
                    "CREATE TABLE migration_test_widgets (id integer PRIMARY KEY)",
                    "CREATE INDEX migration_test_widgets_id_idx ON migration_test_widgets (id)"
                ]
            )
        ]

        private let logger: Logger = .init(label: "test.migrations")

        @Test("The first run applies every shipped migration; the second applies none")
        func shippedMigrationsApplyOnce() async throws {
            try await withDatabase { client in
                let runner = MigrationRunner(logger: logger)

                let firstRun = try await runner.run(on: client)
                #expect(firstRun == Migrations.all)

                let secondRun = try await runner.run(on: client)
                #expect(secondRun.isEmpty)

                #expect(try await recordedCount(on: client) == Migrations.all.count)
            }
        }

        @Test("Statements run, and each migration is recorded once")
        func statementsRunAndAreRecorded() async throws {
            try await withDatabase { client in
                let runner = MigrationRunner(migrations: Self.testMigrations, logger: logger)

                #expect(try await runner.run(on: client) == Self.testMigrations)
                #expect(try await runner.run(on: client).isEmpty)
                #expect(try await recordedCount(on: client) == Self.testMigrations.count)

                // The table exists only if migration 2's statements ran.
                try await client.query("INSERT INTO migration_test_widgets (id) VALUES (1)", logger: logger)
            }
        }

        @Test("Concurrent runners apply each migration exactly once")
        func concurrentRunnersApplyOnce() async throws {
            try await withDatabase { client in
                let runner = MigrationRunner(migrations: Self.testMigrations, logger: logger)

                let appliedCounts = try await withThrowingTaskGroup(of: Int.self) { group in
                    for _ in 0..<4 {
                        group.addTask { try await runner.run(on: client).count }
                    }
                    return try await group.reduce(into: []) { $0.append($1) }
                }

                #expect(appliedCounts.reduce(0, +) == Self.testMigrations.count)
                #expect(try await recordedCount(on: client) == Self.testMigrations.count)
            }
        }

        @Test("A database version unknown to the code stops the run")
        func databaseAheadStopsTheRun() async throws {
            try await withDatabase { client in
                try await MigrationRunner(migrations: Self.testMigrations, logger: logger).run(on: client)

                let olderBinary = MigrationRunner(migrations: [Self.testMigrations[0]], logger: logger)
                await #expect(throws: MigrationError.databaseAhead(version: 2)) {
                    try await olderBinary.run(on: client)
                }
            }
        }

        // MARK: - Helpers

        /// Runs `body` with a running client against a reset schema.
        private func withDatabase(_ body: @Sendable (PostgresClient) async throws -> Void) async throws {
            try await TestDatabase.withClient(logger: logger) { client in
                try await resetSchema(on: client)
                try await body(client)
                // Leave no test version behind: a server started on this database
                // afterwards would refuse to start with `databaseAhead`.
                try await resetSchema(on: client)
            }
        }

        private func resetSchema(on client: PostgresClient) async throws {
            try await client.query("DROP TABLE IF EXISTS migration_test_widgets", logger: logger)
            // The shipped migrations create these; without the drop, a second run of the
            // shipped list fails with "relation already exists".
            try await client.query(
                """
                DROP TABLE IF EXISTS config_changes, config_version, config_entries
                """,
                logger: logger
            )
            try await client.query(
                "DROP FUNCTION IF EXISTS config_record_change(), config_reject_truncate()",
                logger: logger
            )
            try await client.query("DROP TABLE IF EXISTS schema_migrations", logger: logger)
        }

        private func recordedCount(on client: PostgresClient) async throws -> Int {
            let rows = try await client.query("SELECT count(*) FROM schema_migrations", logger: logger)
            for try await count in rows.decode(Int.self) {
                return count
            }
            return 0
        }
    }
}
