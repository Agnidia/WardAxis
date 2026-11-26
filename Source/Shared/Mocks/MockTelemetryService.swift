//
//  MockTelemetryService.swift
//
//  Created on 15.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisTelemetry

/// In-memory analytics service that captures every event for tests.
///
/// `nonisolated` `track(_:)` matches the protocol shape; concurrent
/// access is serialised through an `NSLock` so the type is `Sendable`
/// without requiring callers to hop to a specific actor. The
/// `recorded` accessor takes the same lock so test assertions see a
/// consistent snapshot.
final class MockTelemetryService: TelemetryServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _recorded: [TelemetryEvent] = []
    
    init() {}
    
    func track(_ event: TelemetryEvent) {
        lock.lock()
        _recorded.append(event)
        lock.unlock()
    }
    
    /// Snapshot of every event recorded so far.
    var recorded: [TelemetryEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _recorded
    }
}
