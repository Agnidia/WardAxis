//
//  MigrationRunner.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Logging
import PostgresNIO

/// Applies pending migrations against PostgreSQL.
///
/// Concurrent starts are serialised by a session-level advisory lock, which needs one
/// connection from lock to unlock; if the process dies, the session end frees it.
/// Each migration and its `schema_migrations` row commit in one transaction.
package struct MigrationRunner: Sendable {
    /// ASCII `another1`. Shared by every server instance that migrates this database.
    package static let advisoryLockKey: Int64 = 0x616E6F7468657231
    
    private let migrations: [Migration]
    private let logger: Logger
    
    package init(migrations: [Migration] = Migrations.all, logger: Logger) {
        self.migrations = migrations
        self.logger = logger
    }
    
    /// Applies every pending migration in version order.
    ///
    /// - Returns: The migrations this call applied; empty when the schema is current.
    /// - Throws: ``MigrationError`` on drift or an unknown database version, or the
    ///   driver error of the failing statement. The lock is released on every path.
    @discardableResult
    package func run(on client: PostgresClient) async throws -> [Migration] {
        // The pool retries a failing connect without end, and its own logs sit below
        // the server's level; this line shows where start-up is waiting.
        logger.info("Connecting to the database to apply migrations")
        return try await client.withConnection { connection in
            try await connection.query("SELECT pg_advisory_lock(\(Self.advisoryLockKey))", logger: logger)
            let applied: [Migration]
            do {
                applied = try await migrate(on: connection)
            } catch {
                await unlock(connection)
                throw error
            }
            await unlock(connection)
            return applied
        }
    }
    
    private func migrate(on connection: PostgresConnection) async throws -> [Migration] {
        try await connection.query(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version    integer     PRIMARY KEY,
                name       text        NOT NULL,
                applied_at timestamptz NOT NULL DEFAULT now()
            )
            """,
            logger: logger
        )
        
        var recorded: [AppliedMigration] = []
        let rows = try await connection.query("SELECT version, name FROM schema_migrations", logger: logger)
        for try await (version, name) in rows.decode((Int, String).self) {
            recorded.append(AppliedMigration(version: version, name: name))
        }
        
        let pending = try MigrationPlanner.pending(all: migrations, applied: recorded)
        if pending.isEmpty {
            logger.info("Database schema is current", metadata: ["migrations.applied": "\(recorded.count)"])
            return []
        }
        
        for migration in pending {
            try await connection.withTransaction(logger: logger) { transaction in
                for statement in migration.statements {
                    try await transaction.query(PostgresQuery(unsafeSQL: statement), logger: logger)
                }
                try await transaction.query(
                    "INSERT INTO schema_migrations (version, name) VALUES (\(migration.version), \(migration.name))",
                    logger: logger
                )
            }
            logger.info(
                "Applied migration",
                metadata: ["migration.version": "\(migration.version)", "migration.name": "\(migration.name)"]
            )
        }
        return pending
    }
    
    private func unlock(_ connection: PostgresConnection) async {
        do {
            try await connection.query("SELECT pg_advisory_unlock(\(Self.advisoryLockKey))", logger: logger)
        } catch {
            // An unlock failure almost always means the connection is gone, and a
            // closed session frees its advisory locks.
            logger.warning("Could not release the migration lock", metadata: .errorType(error))
        }
    }
}
