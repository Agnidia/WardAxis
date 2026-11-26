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
    
    @MainActor
    func testSettingsDeepLinkOnColdLaunch() throws {
        let app = XCUIApplication()
        app.terminate()
        try open(XCTUnwrap(URL(string: "wardaxis://settings")), in: app)
        XCTAssertTrue(app.descendants(matching: .any)["screen.settings"].firstMatch.waitForExistence(timeout: 10))
    }
    
    @MainActor
    func testHelpDeepLinkOnWarmLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["screen.home"].firstMatch.waitForExistence(timeout: 10))
        try open(XCTUnwrap(URL(string: "wardaxis://help")), in: app)
        XCTAssertTrue(app.descendants(matching: .any)["screen.help"].firstMatch.waitForExistence(timeout: 10))
        try open(XCTUnwrap(URL(string: "wardaxis://home")), in: app)
        XCTAssertTrue(app.descendants(matching: .any)["screen.home"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["screen.help"].firstMatch.exists)
    }
    
    @MainActor
    private func open(_ url: URL, in app: XCUIApplication) {
#if os(macOS)
        // Pin the reviewed build when another installed copy may own the scheme.
        app.open(url)
#else
        XCUIDevice.shared.system.open(url)
#endif
    }
}
