//
//  MigrationPlanner.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// Decides which migrations to apply. Pure: no I/O, so every policy is unit-testable.
package enum MigrationPlanner {
    /// Returns the migrations in `all` that are not yet applied, in code order.
    ///
    /// - Parameters:
    ///   - all: Every migration the binary knows: versions 1, 2, 3, … in order, with no gap.
    ///   - applied: The rows recorded in `schema_migrations`, in any order.
    /// - Throws: ``MigrationError`` when the code list has a gap or is out of order, when
    ///   the database holds a version the code renamed or does not know, or when a pending
    ///   migration sorts below one the database already applied.
    package static func pending(
        all: [Migration],
        applied: [AppliedMigration]
    ) throws(MigrationError) -> [Migration] {
        // Contiguity, not just ordering: a gap means a migration from another branch is
        // missing, and the out-of-order check below could not see it.
        for (index, migration) in all.enumerated() where migration.version != index + 1 {
            throw .invalidOrder(version: migration.version)
        }
        
        let knownNames: [Int: String] = Dictionary(uniqueKeysWithValues: all.map { ($0.version, $0.name) })
        // Ascending, so the first reported error is the lowest offending version.
        for row in applied.sorted(by: { $0.version < $1.version }) {
            guard let name = knownNames[row.version] else {
                throw .databaseAhead(version: row.version)
            }
            guard name == row.name else {
                throw .drift(version: row.version)
            }
        }
        
        let appliedVersions: Set<Int> = Set(applied.map(\.version))
        let pending = all.filter { !appliedVersions.contains($0.version) }
        if let highestApplied = appliedVersions.max(), let lowestPending = pending.first,
           lowestPending.version < highestApplied
        {
            throw .pendingBelowApplied(version: lowestPending.version)
        }
        return pending
    }
}
