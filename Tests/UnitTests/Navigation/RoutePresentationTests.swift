//
//  RoutePresentationTests.swift
//
//  Created on 19.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
@testable import WardAxis

@Suite("RoutePresentation")
struct RoutePresentationTests {
    // MARK: - Per-case defaults

    @Test(".splash defaults to .fullScreenCover")
    func splashIsFullScreenCover() {
        #expect(Route.splash.defaultPresentation == .fullScreenCover)
    }

    @Test(".settings defaults to .sheet")
    func settingsIsSheet() {
        #expect(Route.settings.defaultPresentation == .sheet)
    }

    @Test(".permissions defaults to .sheet")
    func permissionsIsSheet() {
        #expect(Route.permissions.defaultPresentation == .sheet)
    }

    @Test("push routes default to .push")
    func pushRoutesDefaultToPush() {
        let pushRoutes: [Route] = [
            .main,
            .home,
            .help,
            .commonActions,
            .logs,
            .componentsGallery,
            .alertsTest
        ]

        for route in pushRoutes {
            #expect(
                route.defaultPresentation == .push,
                "expected \(route) to default to .push"
            )
        }
    }
}
