//
//  LabExclusionTests.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing

/// The App Store scheme's test host must never be a lab build (ADR 0003): lab code
/// paths and the lab identity stay out of every configuration that can be archived
/// for App Store Connect.
@Suite("Lab build exclusion")
struct LabExclusionTests {
    @Test
    func `The WARDAXIS_LAB condition is not defined`() {
#if WARDAXIS_LAB
        Issue.record("WARDAXIS_LAB is defined in an App Store configuration")
#endif
    }
    
    @Test
    func `The host bundle ID is outside the lab namespace`() throws {
        let bundleID = try #require(Bundle.main.bundleIdentifier)
        
        #expect(!bundleID.split(separator: ".").contains("lab"))
    }
}
