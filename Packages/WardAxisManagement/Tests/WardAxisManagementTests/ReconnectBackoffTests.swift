//
//  ReconnectBackoffTests.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisManagementTestSupport
@testable import WardAxisManagement

@Suite("ReconnectBackoff")
struct ReconnectBackoffTests {
    @Test(arguments: zip(0...7, [1, 2, 4, 8, 16, 32, 60, 60]))
    func `The upper bound doubles from 1 s and stops at 60 s`(attempt: Int, seconds: Int) {
        let backoff = ReconnectBackoff(jitter: { $0 })
        
        #expect(backoff.upperBound(forAttempt: attempt) == .seconds(seconds))
        #expect(backoff.delay(forAttempt: attempt) == .seconds(seconds))
    }
    
    @Test
    func `Full jitter stays within [250 ms, min(60 s, 2^n s)]`() {
        let backoff = ReconnectBackoff()
        
        for attempt in 0...10 {
            let upper = backoff.upperBound(forAttempt: attempt)
            for _ in 0..<200 {
                let delay = backoff.delay(forAttempt: attempt)
                #expect(delay >= ReconnectBackoff.floor && delay <= upper)
            }
        }
    }
    
    @Test(arguments: [
        (Int.max, 60), (63, 60), (64, 60), (-1, 1), (Int.min, 1)
    ])
    func `A huge or negative attempt neither overflows nor leaves the bounds`(attempt: Int, seconds: Int) {
        let backoff = ReconnectBackoff(jitter: { $0 })
        
        #expect(backoff.delay(forAttempt: attempt) == .seconds(seconds))
    }
    
    @Test
    func `A jitter outside the range, or below the 250 ms floor, is clamped to it`() {
        let tooLong = ReconnectBackoff(jitter: { _ in .seconds(1000) })
        let negative = ReconnectBackoff(jitter: { _ in .seconds(-5) })
        
        #expect(tooLong.delay(forAttempt: 2) == .seconds(4))
        #expect(negative.delay(forAttempt: 2) == .milliseconds(250))
        #expect(ReconnectBackoff(jitter: { _ in .zero }).delay(forAttempt: 0) == .milliseconds(250))
    }
}
