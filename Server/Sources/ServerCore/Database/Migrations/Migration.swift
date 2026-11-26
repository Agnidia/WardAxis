//
//  Migration.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// One forward-only schema change.
///
/// `statements` holds one SQL statement per element, because the extended query
/// protocol that PostgresNIO uses runs a single statement per query. The SQL must be
/// a compile-time literal: the runner executes it without parameter binding.
package struct Migration: Sendable, Equatable {
    /// Strictly increasing across ``Migrations/all``; never reused or renumbered.
    package let version: Int
    /// Recorded in `schema_migrations`; a later rename is reported as drift.
    package let name: String
    package let statements: [String]
    
    package init(version: Int, name: String, statements: [String]) {
        self.version = version
        self.name = name
        self.statements = statements
    }
}

/// A row read back from `schema_migrations`.
package struct AppliedMigration: Sendable, Equatable {
    package let version: Int
    package let name: String
    
    package init(version: Int, name: String) {
        self.version = version
        self.name = name
    }
}
