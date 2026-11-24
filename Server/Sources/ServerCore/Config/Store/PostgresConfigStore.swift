//
//  PostgresConfigStore.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import WardAxisAPIServer
import Foundation
import Logging
import PostgresNIO

/// ``ConfigStore`` on the migration 6 tables.
///
/// jsonb is read as text and decoded with `JSONDecoder`, so each value keeps its JSON
/// type: an integer stays an integer in the frames the clients receive.
package struct PostgresConfigStore: ConfigStore {
    private let client: PostgresClient
    /// Keep at `notice` or above: below it the driver logs bind values.
    private let logger: Logger

    package init(client: PostgresClient, logger: Logger) {
        self.client = client
        self.logger = logger
    }

    package func snapshot() async throws -> ConfigSnapshotRecord {
        // One statement, so the version and the entries come from one MVCC snapshot.
        let rows = try await client.query(
            """
            SELECT v.version,
                   COALESCE((SELECT jsonb_object_agg(key, value) FROM config_entries), '{}'::jsonb)::text
            FROM config_version AS v
            """,
            logger: logger
        )
        var record: ConfigSnapshotRecord?
        for try await (version, values) in rows.decode((Int64, String).self) {
            record = try ConfigSnapshotRecord(version: version, values: Self.entries(fromJSON: values))
        }
        guard let record else { throw ConfigStoreError.missingVersion }
        return record
    }

    package func currentVersion() async throws -> Int64 {
        let rows = try await client.query("SELECT version FROM config_version", logger: logger)
        var current: Int64?
        for try await version in rows.decode(Int64.self) {
            current = version
        }
        guard let current else { throw ConfigStoreError.missingVersion }
        return current
    }

    package func changes(after version: Int64, limit: Int) async throws -> [ConfigChange] {
        let rows = try await client.query(
            """
            SELECT version, changed::text, removed
            FROM config_changes
            WHERE version > \(version)
            ORDER BY version
            LIMIT \(limit)
            """,
            logger: logger
        )
        var changes: [ConfigChange] = []
        for try await (changeVersion, changed, removed) in rows.decode((Int64, String, [String]).self) {
            try changes.append(ConfigChange(version: changeVersion, changed: Self.entries(fromJSON: changed), removed: removed))
        }
        return changes
    }

    private static func entries(fromJSON text: String) throws -> Components.Schemas.ConfigEntries {
        try JSONDecoder().decode(Components.Schemas.ConfigEntries.self, from: Data(text.utf8))
    }
}
