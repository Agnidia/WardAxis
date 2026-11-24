//
//  previewUITests.swift
//
//  Created on 08.03.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest

final class previewUITests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        
        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
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
