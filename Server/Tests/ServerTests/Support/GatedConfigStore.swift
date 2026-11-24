//
//  GatedConfigStore.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import NIOConcurrencyHelpers
import ServerCore

/// ``InMemoryConfigStore`` whose `currentVersion()` waits until a test opens ``gate``.
///
/// The relay reads `currentVersion()` once at start, so the gate holds the relay in its
/// start-up window: a test can admit a stream and commit a change before the relay knows
/// where it starts. Snapshots and change reads pass straight through.
final class GatedConfigStore: ConfigStore, Sendable {
    let base: InMemoryConfigStore
    let gate: Gate = .init()
    private let waiting: NIOLockedValueBox<Int> = .init(0)

    init(base: InMemoryConfigStore) {
        self.base = base
    }

    /// `currentVersion()` calls now waiting at the gate.
    var waitingReads: Int {
        waiting.withLockedValue { $0 }
    }

    func snapshot() async throws -> ConfigSnapshotRecord {
        try await base.snapshot()
    }

    func currentVersion() async throws -> Int64 {
        waiting.withLockedValue { $0 += 1 }
        defer { waiting.withLockedValue { $0 -= 1 } }
        try await gate.wait()
        return try await base.currentVersion()
    }

    func changes(after version: Int64, limit: Int) async throws -> [ConfigChange] {
        try await base.changes(after: version, limit: limit)
    }
}
