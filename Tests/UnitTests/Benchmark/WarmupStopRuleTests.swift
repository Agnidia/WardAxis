//
//  WarmupStopRuleTests.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
@testable import WardAxis

/// The sign-in warm-up rule the driver uses: at least 3, at most 8. The sequences come
/// from the iOS job of PR #69, with the warm-up the old driver discarded put back first.
@Suite("Warm-up stop rule")
struct WarmupStopRuleTests {
    private let signInRule = WarmupStopRule(minimum: 3, maximum: 8)

    @Test("A slow cold start ends at the first stable pair (PR #69, chunk 1)")
    func slowColdStartStopsAtStablePair() {
        // 13081 through 4378 are the cold-start tail; 2029 and 1710 are the first stable pair.
        let outcome = signInRule.outcome(replaying: [15_000, 13_081, 9847, 8081, 4378, 2029, 1710, 839, 1156])

        #expect(outcome == WarmupStopRule.Outcome(warmupCount: 7, capped: false))
    }

    @Test("A warm simulator stops at the minimum (PR #69, chunk 2)")
    func warmSimulatorStopsAtMinimum() {
        let outcome = signInRule.outcome(replaying: [1700, 1621, 1569, 623])

        #expect(outcome == WarmupStopRule.Outcome(warmupCount: 3, capped: false))
    }

    @Test("The minimum holds when the samples are stable sooner")
    func minimumHoldsForEarlyStability() {
        #expect(signInRule.decision(after: [700, 700]) == .warmUpAgain)
        #expect(signInRule.outcome(replaying: [700, 700, 700, 700]) == WarmupStopRule.Outcome(warmupCount: 3, capped: false))
    }

    @Test("A sequence that never settles stops at the cap with the flag set")
    func neverSettlingSequenceHitsCap() {
        // Every consecutive pair differs by more than its tolerance, the last one too.
        let outcome = signInRule.outcome(replaying: [9000, 6000, 4000, 2600, 1700, 1100, 700, 400, 200])

        #expect(outcome == WarmupStopRule.Outcome(warmupCount: 8, capped: true))
    }

    @Test("A steady decline within 20 % counts as stable")
    func steadyDeclineWithinToleranceIsStable() {
        // 8000 → 7000 differs by 1000, and 20 % of 7000 is 1400.
        let outcome = signInRule.outcome(replaying: [9000, 8000, 7000, 6000, 5000, 4000, 3000, 2000, 1000])

        #expect(outcome == WarmupStopRule.Outcome(warmupCount: 3, capped: false))
    }

    @Test(
        "The tolerance is max(250 ms, floor(20 % of the smaller sample))",
        arguments: [
            (Int64(2029), Int64(1710), true), // 319 <= 342
            (Int64(2060), Int64(1710), false), // 350 > 342
            (Int64(1000), Int64(750), true), // 250 <= 250, the floor
            (Int64(1000), Int64(749), false), // 251 > 250
            (Int64(4378), Int64(2029), false) // 2349 > 405
        ]
    )
    func tolerance(first: Int64, second: Int64, stable: Bool) {
        #expect(WarmupStopRule.isStable(first, second) == stable)
        #expect(WarmupStopRule.isStable(second, first) == stable)
    }

    @Test("Equal minimum and maximum is a fixed count")
    func equalBoundsAreFixed() {
        let fixed = WarmupStopRule(minimum: 2, maximum: 2)

        #expect(fixed.outcome(replaying: [9000, 100, 50]) == WarmupStopRule.Outcome(warmupCount: 2, capped: false))
        #expect(WarmupStopRule(minimum: 0, maximum: 0).decision(after: []) == .measure(capped: false))
    }

    @Test("A sequence too short to settle has no outcome")
    func shortSequenceHasNoOutcome() {
        #expect(signInRule.outcome(replaying: [9000, 6000, 4000]) == nil)
    }
}
