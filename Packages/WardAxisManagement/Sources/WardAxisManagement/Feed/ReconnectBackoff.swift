//
//  ReconnectBackoff.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Exponential reconnect delay with full jitter.
///
/// Attempt `n` waits a jittered value in `[floor, min(cap, base × 2^n)]`. Full
/// jitter spreads the clients that one server restart disconnects together; the
/// floor keeps a zero draw from turning a repeated close into a tight loop.
public struct ReconnectBackoff: Sendable {
    static let base: Duration = .seconds(1)
    static let cap: Duration = .seconds(60)
    static let floor: Duration = .milliseconds(250)

    /// A uniform random delay in `[0, upper]`, at millisecond resolution.
    public static let fullJitter: @Sendable (Duration) -> Duration = { upper in
        let milliseconds = max(0, Int64(upper / .milliseconds(1)))
        return .milliseconds(Int64.random(in: 0...milliseconds))
    }

    /// Picks the delay within `[0, upper]`. Tests pass the identity.
    let jitter: @Sendable (Duration) -> Duration

    public init(jitter: @escaping @Sendable (Duration) -> Duration = Self.fullJitter) {
        self.jitter = jitter
    }

    func upperBound(forAttempt attempt: Int) -> Duration {
        // 2^6 s already exceeds the cap; saturating here keeps the shift from overflowing.
        let exponent = min(max(attempt, 0), 6)
        return min(Self.cap, Self.base * (1 << exponent))
    }

    /// The jittered delay, clamped to `[floor, upperBound]` whatever the jitter returns.
    func delay(forAttempt attempt: Int) -> Duration {
        let upper = upperBound(forAttempt: attempt)
        return min(max(jitter(upper), Self.floor), upper)
    }
}
