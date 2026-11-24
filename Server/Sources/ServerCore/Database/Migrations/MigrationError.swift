//
//  MigrationError.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// A mismatch between the migrations in code and the rows in `schema_migrations`.
///
/// Each case stops start-up before the HTTP listener binds: hand-written SQL has no
/// ORM layer that would catch an incompatible schema later.
package enum MigrationError: Error, Equatable, Sendable {
    /// The code list is not contiguous from 1 at `version`.
    case invalidOrder(version: Int)
    /// The database recorded `version` under a different name than the code uses.
    case drift(version: Int)
    /// The database recorded `version`, which this binary does not know.
    case databaseAhead(version: Int)
    /// `version` is pending while a higher version is already applied. Applying it now
    /// would run it against a schema its author never saw.
    case pendingBelowApplied(version: Int)
}

// MARK: - CustomStringConvertible

extension MigrationError: CustomStringConvertible {
    package var description: String {
        switch self {
        case let .invalidOrder(version):
            "Migration versions are not contiguous from 1 at version \(version)"
        case let .drift(version):
            "Migration \(version) is recorded under a different name than the code uses"
        case let .databaseAhead(version):
            "The database has migration \(version), which this server does not know"
        case let .pendingBelowApplied(version):
            "Migration \(version) is pending, but the database already has a later migration"
        }
    }
}
