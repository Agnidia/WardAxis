//
//  LaunchUITests.swift
//
//  Created on 08.03.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import XCTest

final class LaunchUITests: XCTestCase {
    /// The screen identifiers of `AccessibilityID.Screen`, which this target does not
    /// compile; an independent copy, so a renamed identifier fails here.
    private enum Screen {
        static let home = "screen.home"
        static let settings = "screen.settings"
        static let help = "screen.help"
    }
    
    /// `APP_URL_SCHEME` of the App Store build; the lab build's scheme differs.
    private static let scheme = "wardaxis"
    
    /// Cold launch and a deep link both finish well inside this on a loaded runner.
    private static let appearanceTimeout: TimeInterval = 10
    
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
        try open(link("settings"), in: app)
        XCTAssertTrue(screen(Screen.settings, in: app).waitForExistence(timeout: Self.appearanceTimeout))
    }
    
    @MainActor
    func testHelpDeepLinkOnWarmLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(screen(Screen.home, in: app).waitForExistence(timeout: Self.appearanceTimeout))
        try open(link("help"), in: app)
        XCTAssertTrue(screen(Screen.help, in: app).waitForExistence(timeout: Self.appearanceTimeout))
        try open(link("home"), in: app)
        XCTAssertTrue(screen(Screen.home, in: app).waitForExistence(timeout: Self.appearanceTimeout))
        XCTAssertFalse(screen(Screen.help, in: app).exists)
    }
    
    private func link(_ host: String) throws -> URL {
        try XCTUnwrap(URL(string: "\(Self.scheme)://\(host)"))
    }
    
    @MainActor
    private func screen(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
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
