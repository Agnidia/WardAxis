//
//  RetryBackoff.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// Capped exponential backoff with jitter, for loops that retry a database read or connect.
package struct RetryBackoff: Sendable, Equatable {
    package var initial: Duration
    package var maximum: Duration

    package static let standard: RetryBackoff = .init(initial: .milliseconds(250), maximum: .seconds(30))

    package init(initial: Duration, maximum: Duration) {
        self.initial = initial
        self.maximum = maximum
    }

    /// The wait before retry `attempt` (1-based): between half and all of
    /// `min(maximum, initial × 2^(attempt − 1))`. The random half spreads the retries of
    /// many server instances after a shared database restart.
    package func delay(forAttempt attempt: Int) -> Duration {
        let exponent = min(max(attempt - 1, 0), 30)
        let ceiling = min(maximum, initial * (1 << exponent))
        return ceiling / 2 + ceiling * (Double.random(in: 0...1) / 2)
    }
}
