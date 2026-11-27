//
//  ConfigStore.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import WardAxisAPIServer

/// Read access to the live configuration and its change log.
///
/// Changes arrive through SQL, outside the server. Each committed change advances the
/// version by exactly 1 and is kept in the log, so a reader that knows version `v` can
/// always reach the present by reading the changes after `v`.
package protocol ConfigStore: Sendable {
    /// The current version and every entry, read as one consistent snapshot.
    func snapshot() async throws -> ConfigSnapshotRecord
    func currentVersion() async throws -> Int64
    /// At most `limit` changes with a version above `version`, in ascending version order.
    func changes(after version: Int64, limit: Int) async throws -> [ConfigChange]
}

/// The configuration at one version.
package struct ConfigSnapshotRecord: Sendable, Equatable {
    package let version: Int64
    package let values: Components.Schemas.ConfigEntries
    
    package init(version: Int64, values: Components.Schemas.ConfigEntries) {
        self.version = version
        self.values = values
    }
}

/// One committed change: the entries it set and the keys it deleted.
package struct ConfigChange: Sendable, Equatable {
    package let version: Int64
    package let changed: Components.Schemas.ConfigEntries
    package let removed: [String]
    
    package init(version: Int64, changed: Components.Schemas.ConfigEntries, removed: [String]) {
        self.version = version
        self.changed = changed
        self.removed = removed
    }
}

/// A store whose data breaks the schema's guarantees.
package enum ConfigStoreError: Error, Equatable, Sendable {
    /// `config_version` has no row: migration 0002 did not run, or the row was deleted.
    case missingVersion
}
