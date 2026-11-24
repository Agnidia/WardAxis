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
    
    @Test
    func `.settings defaults to .sheet`() {
        #expect(Route.settings.defaultPresentation == .sheet)
    }
    
    @Test
    func `push routes default to .push`() {
        let pushRoutes: [Route] = [
            .home,
            .help,
            .logs
        ]
        
        for route in pushRoutes {
            #expect(
                route.defaultPresentation == .push,
                "expected \(route) to default to .push"
            )
        }
    }
}
