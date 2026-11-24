//
//  LaunchUITests.swift
//
//  Created on 08.03.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest

final class LaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        // Launch-performance metrics are non-deterministic on the macOS unit-test target
        // (no simulator cold-launch semantics). Skip to avoid flaky CI failures.
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["SIMULATOR_RUNTIME_VERSION"] == nil,
            "Launch performance skipped on macOS — non-deterministic on unit-test target"
        )
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
