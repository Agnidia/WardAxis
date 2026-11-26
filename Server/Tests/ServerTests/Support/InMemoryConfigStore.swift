//
//  InMemoryConfigStore.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import NIOConcurrencyHelpers
import OpenAPIRuntime
import ServerCore
import WardAxisAPIServer

/// ``ConfigStore`` in memory, versioned like migration 6: each commit that changes
/// something advances the version by exactly 1 and appends one change to the log.
final class InMemoryConfigStore: ConfigStore, Sendable {
    struct StoreFailure: Error {}
    
    private struct State {
        var version: Int64
        var values: [String: OpenAPIValueContainer]
        var log: [ConfigChange] = []
        var failing: Bool = false
    }
    
    private let state: NIOLockedValueBox<State>
    
    /// - Parameter valuesJSON: The entries at `version`, as a JSON object.
    init(version: Int64 = 0, valuesJSON: String = "{}") throws {
        let values = try JSONDecoder().decode([String: OpenAPIValueContainer].self, from: Data(valuesJSON.utf8))
        state = NIOLockedValueBox(State(version: version, values: values))
    }
    
    /// Applies one change, as one SQL statement would; returns the version after it.
    @discardableResult
    func commit(changedJSON: String = "{}", removed: [String] = []) throws -> Int64 {
        let changed = try JSONDecoder().decode([String: OpenAPIValueContainer].self, from: Data(changedJSON.utf8))
        let entries = try Self.entries(changed)
        return state.withLockedValue { state in
            let removedKeys = removed.filter { state.values[$0] != nil }.sorted()
            let changedKeys = changed.filter { state.values[$0.key] != $0.value }
            guard !changedKeys.isEmpty || !removedKeys.isEmpty else { return state.version }
            for key in removedKeys {
                state.values[key] = nil
            }
            state.values.merge(changed) { _, new in new }
            state.version += 1
            state.log.append(ConfigChange(version: state.version, changed: entries, removed: removedKeys))
            return state.version
        }
    }
    
    /// Drops logged changes up to `version`, as a future retention job could.
    func pruneLog(through version: Int64) {
        state.withLockedValue { $0.log.removeAll { $0.version <= version } }
    }
    
    /// Makes every read throw ``StoreFailure`` until reset.
    func setFailing(_ failing: Bool) {
        state.withLockedValue { $0.failing = failing }
    }
    
    func change(at version: Int64) -> ConfigChange? {
        state.withLockedValue { $0.log.first { $0.version == version } }
    }
    
    // MARK: ConfigStore
    
    func snapshot() async throws -> ConfigSnapshotRecord {
        let (version, values) = try state.withLockedValue { state in
            guard !state.failing else { throw StoreFailure() }
            return (state.version, state.values)
        }
        return try ConfigSnapshotRecord(version: version, values: Self.entries(values))
    }
    
    func currentVersion() async throws -> Int64 {
        try state.withLockedValue { state in
            guard !state.failing else { throw StoreFailure() }
            return state.version
        }
    }
    
    func changes(after version: Int64, limit: Int) async throws -> [ConfigChange] {
        try state.withLockedValue { state in
            guard !state.failing else { throw StoreFailure() }
            return Array(state.log.filter { $0.version > version }.prefix(limit))
        }
    }
    
    private static func entries(_ values: [String: OpenAPIValueContainer]) throws -> Components.Schemas.ConfigEntries {
        try JSONDecoder().decode(Components.Schemas.ConfigEntries.self, from: JSONEncoder().encode(values))
    }
}
