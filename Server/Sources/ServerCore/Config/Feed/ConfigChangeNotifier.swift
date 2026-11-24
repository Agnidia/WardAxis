//
//  ConfigChangeNotifier.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// Wakes the relay when the configuration may have changed.
///
/// A wake-up carries no data: the relay reads the store, which is the source of truth,
/// so a coalesced or lost wake-up costs latency, never a change. An implementation also
/// wakes once after every (re)connect, because changes can commit while it is not
/// listening.
package protocol ConfigChangeNotifier: Sendable {
    /// A stream of wake-ups that stops its producer when the consumer stops iterating.
    func wakeUps() -> AsyncStream<Void>
}
