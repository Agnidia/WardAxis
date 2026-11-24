//
//  Route.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Type-safe navigation routes for the application.
///
/// `Route` is a pure value: cases and payloads only. UI policy
/// (push / sheet / fullScreenCover) lives in `RoutePresentation`;
/// view construction lives in `RouteResolver`.
///
/// Example:
/// ```swift
/// coordinator.navigate(to: .settings)
/// coordinator.push(.help)
/// coordinator.present(.permissions)
/// ```
enum Route: Hashable, Sendable {
    // MARK: - Root Routes

    /// Initial splash screen shown on app launch.
    case splash

    /// Main content after splash (tab container).
    case main

    // MARK: - Tab Routes

    /// Home tab content.
    case home

    // MARK: - Push Routes

    /// Application settings screen.
    case settings

    /// Help and FAQ screen.
    case help

    /// Permissions management screen.
    case permissions

    /// Common actions showcase.
    case commonActions

    /// In-app log viewer.
    case logs

    /// Runtime gallery of every shared design-system control.
    case componentsGallery

    /// Manual trigger surface for alert and toast variants.
    case alertsTest
}

// MARK: - Identifiable

/// `Identifiable` is required by SwiftUI's `.sheet(item:)` and
/// `.fullScreenCover(item:)` overloads. The id uses `String(reflecting:)`
/// which encodes the case name and all associated values, guaranteeing
/// uniqueness without relying on hash collision-avoidance.
extension Route: Identifiable {
    var id: String {
        String(reflecting: self)
    }
}
