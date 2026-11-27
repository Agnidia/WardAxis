//
//  MigrationPlannerTests.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import ServerCore
import Testing

@Suite("Migration planner")
struct MigrationPlannerTests {
    private static let first: Migration = .init(version: 1, name: "baseline", statements: [])
    private static let second: Migration = .init(version: 2, name: "users", statements: ["SELECT 1"])
    private static let third: Migration = .init(version: 3, name: "sessions", statements: ["SELECT 1"])
    
    @Test
    func `An empty database gets every migration, in order`() throws {
        let pending = try MigrationPlanner.pending(all: [Self.first, Self.second], applied: [])
        #expect(pending == [Self.first, Self.second])
    }
    
    @Test
    func `Only migrations missing from the database are pending`() throws {
        let applied = [AppliedMigration(version: 1, name: "baseline")]
        let pending = try MigrationPlanner.pending(all: [Self.first, Self.second, Self.third], applied: applied)
        #expect(pending == [Self.second, Self.third])
    }
    
    @Test
    func `A current database has nothing pending`() throws {
        let applied = [AppliedMigration(version: 2, name: "users"), AppliedMigration(version: 1, name: "baseline")]
        let pending = try MigrationPlanner.pending(all: [Self.first, Self.second], applied: applied)
        #expect(pending.isEmpty)
    }
    
    @Test
    func `Code versions that are not contiguous from 1 are rejected at the first misplaced version`() {
        #expect(throws: MigrationError.invalidOrder(version: 2)) {
            try MigrationPlanner.pending(all: [Self.second, Self.first], applied: [])
        }
        #expect(throws: MigrationError.invalidOrder(version: 2)) {
            try MigrationPlanner.pending(all: [Self.first, Self.second, Self.second], applied: [])
        }
        let fourth = Migration(version: 4, name: "fourth", statements: [])
        #expect(throws: MigrationError.invalidOrder(version: 4)) {
            try MigrationPlanner.pending(all: [Self.first, Self.second, fourth], applied: [])
        }
    }
    
    @Test
    func `A pending version below the highest applied one refuses start-up`() throws {
        let gapped = [AppliedMigration(version: 1, name: "baseline"), AppliedMigration(version: 3, name: "sessions")]
        #expect(throws: MigrationError.pendingBelowApplied(version: 2)) {
            try MigrationPlanner.pending(all: [Self.first, Self.second, Self.third], applied: gapped)
        }
        
        let contiguous = [AppliedMigration(version: 1, name: "baseline"), AppliedMigration(version: 2, name: "users")]
        #expect(try MigrationPlanner.pending(all: [Self.first, Self.second, Self.third], applied: contiguous) == [Self.third])
    }
    
    @Test
    func `A recorded version with a different name is drift`() {
        let applied = [AppliedMigration(version: 1, name: "renamed")]
        #expect(throws: MigrationError.drift(version: 1)) {
            try MigrationPlanner.pending(all: [Self.first, Self.second], applied: applied)
        }
    }
    
    @Test
    func `A recorded version unknown to the code means the database is ahead`() {
        let applied = [AppliedMigration(version: 1, name: "baseline"), AppliedMigration(version: 7, name: "future")]
        #expect(throws: MigrationError.databaseAhead(version: 7)) {
            try MigrationPlanner.pending(all: [Self.first, Self.second], applied: applied)
        }
    }
    
    @Test
    func `The shipped registry is valid and starts with the baseline`() throws {
        let pending = try MigrationPlanner.pending(all: Migrations.all, applied: [])
        #expect(pending == Migrations.all)
        #expect(Migrations.all.first?.version == 1)
        #expect(Migrations.all.first?.name == "baseline")
        #expect(Migrations.all.map(\.version) == Array(1...Migrations.all.count))
        // The rate limiter is in memory: no shipped migration creates a table for it.
        #expect(!Migrations.all.flatMap(\.statements).contains { $0.localizedCaseInsensitiveContains("rate_limit") })
    }
    
    @Test
    func `The shipped registry is exactly the baseline and the configuration migration`() {
        #expect(Migrations.all.map(\.version) == [1, 2])
        #expect(Migrations.all.map(\.name) == ["baseline", "create_configuration"])
        // No account, token or one-time-code table ships.
        let sql = Migrations.all.flatMap(\.statements).joined(separator: "\n").lowercased()
        for table in ["users", "refresh_token", "otp_codes", "email_verification"] {
            #expect(!sql.contains(table), "\(table)")
        }
    }
    
    @Test
    func `The configuration migration is version 2 and creates the config tables and triggers`() throws {
        let migration = try #require(Migrations.all.first { $0.version == 2 })
        #expect(migration.name == "create_configuration")
        let sql = migration.statements.joined(separator: "\n")
        for object in ["config_entries", "config_version", "config_changes", "config_record_change", "config_reject_truncate"] {
            #expect(sql.contains(object), "\(object)")
        }
        #expect(sql.contains("BEFORE TRUNCATE ON config_entries"))
        #expect(sql.contains("pg_notify('config_changes'"))
    }
    
    @Test
    func `The configuration migration's trigger notifies the channel the listener listens on`() throws {
        let migration = try #require(Migrations.all.first { $0.name == "create_configuration" })
        let sql = migration.statements.joined(separator: "\n")
        #expect(sql.contains("pg_notify('\(PostgresConfigChangeNotifier.channel)'"))
    }
}
