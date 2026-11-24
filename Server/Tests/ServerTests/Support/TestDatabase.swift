//
//  TestDatabase.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Logging
import PostgresNIO
import ServerCore
import Testing

/// Reads the integration database URL. A separate type, because a suite trait cannot
/// reference the suite's own members.
enum TestDatabase {
    static let url: String? = ProcessInfo.processInfo.environment["TEST_DATABASE_URL"].flatMap {
        $0.isEmpty ? nil : $0
    }

    /// Runs `body` with a running client for `TEST_DATABASE_URL`.
    static func withClient(logger: Logger, _ body: @Sendable (PostgresClient) async throws -> Void) async throws {
        let url = try #require(url)
        let configuration = try DatabaseConfiguration(url: url, variable: "TEST_DATABASE_URL")
        let client = PostgresClientFactory.makeClient(configuration: configuration, logger: logger)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { await client.run() }
            defer { group.cancelAll() }
            try await body(client)
        }
    }

    /// Brings the schema to the shipped migrations and empties the configuration at version 0.
    ///
    /// Test-only: the server has no way around the change triggers. One transaction, so a
    /// concurrent reader never sees the triggers off.
    static func resetConfigData(on client: PostgresClient, logger: Logger) async throws {
        try await MigrationRunner(logger: logger).run(on: client)
        try await client.withTransaction(logger: logger) { connection in
            try await connection.query("ALTER TABLE config_entries DISABLE TRIGGER USER", logger: logger)
            try await connection.query("DELETE FROM config_entries", logger: logger)
            try await connection.query("DELETE FROM config_changes", logger: logger)
            try await connection.query("UPDATE config_version SET version = 0", logger: logger)
            try await connection.query("ALTER TABLE config_entries ENABLE TRIGGER USER", logger: logger)
        }
    }
}

/// The parent of every suite that can touch PostgreSQL.
///
/// Serialized, because the migration suite drops the tables the config suites write to;
/// in-memory runs of the same suites are fast enough to share the queue.
@Suite("Database-backed suites", .serialized)
struct DatabaseSuites {}
