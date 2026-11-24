//
//  WarmupStopRule.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Decides when a key-result phase has warmed up enough to start measuring.
///
/// A cold simulator makes the first iterations several times slower than the app is, and
/// the slowdown fades over a varying number of iterations, so a fixed count either keeps
/// slow samples or wastes runs. The rule takes at least ``minimum`` warm-ups, then
/// stops as soon as the last two are stable (see ``isStable(_:_:)``), and never takes
/// more than ``maximum``. When `minimum == maximum` it is a fixed count.
///
/// Pure: no clock, no environment, so the unit suite can replay recorded sequences.
struct WarmupStopRule: Sendable, Equatable {
    enum Decision: Sendable, Equatable {
        case warmUpAgain
        /// `capped` is true when the cap ended the warm-up before two samples agreed,
        /// so the measured samples may still carry cold-start cost.
        case measure(capped: Bool)
    }

    /// The outcome of replaying a recorded sequence through the rule.
    struct Outcome: Sendable, Equatable {
        let warmupCount: Int
        let capped: Bool
    }

    /// The absolute part of the tolerance. It keeps sub-second samples, whose 20 % is
    /// smaller than network jitter, from never counting as stable.
    static let toleranceFloorMs: Int64 = 250

    let minimum: Int
    let maximum: Int

    /// `maximum` below `minimum` is raised to `minimum`.
    init(minimum: Int, maximum: Int) {
        self.minimum = max(0, minimum)
        self.maximum = max(self.minimum, maximum)
    }

    /// Whether two consecutive warm-up durations, in milliseconds, agree:
    /// `|a - b| <= max(250, floor(0.2 * min(a, b)))`. Durations are non-negative.
    static func isStable(_ first: Int64, _ second: Int64) -> Bool {
        let tolerance = max(toleranceFloorMs, min(first, second) / 5)
        return abs(first - second) <= tolerance
    }

    /// What to do after the warm-ups taken so far, in run order.
    func decision(after warmups: [Int64]) -> Decision {
        let count = warmups.count
        guard count >= minimum else {
            return .warmUpAgain
        }
        if minimum == maximum {
            return .measure(capped: false)
        }
        if count >= 2, Self.isStable(warmups[count - 2], warmups[count - 1]) {
            return .measure(capped: false)
        }
        return count >= maximum ? .measure(capped: true) : .warmUpAgain
    }

    /// Replays `sequence` one sample at a time; `nil` when it ends before the rule stops.
    func outcome(replaying sequence: [Int64]) -> Outcome? {
        for count in 0...sequence.count {
            if case let .measure(capped) = decision(after: Array(sequence.prefix(count))) {
                return Outcome(warmupCount: count, capped: capped)
            }
        }
        return nil
    }
}
