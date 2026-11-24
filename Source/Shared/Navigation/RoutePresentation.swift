//
//  RoutePresentation.swift
//
//  Created on 19.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// UI presentation policy for a route. Used by `AppCoordinator.navigate(to:presentation:)`.
///
/// Stripping presentation policy off `Route` keeps routes as pure data
/// values; callers can override the per-case default at the navigate site.
enum RoutePresentation: Sendable, Equatable {
    case push
    case sheet
    case fullScreenCover
}

extension Route {
    /// Default UI policy for this route. Callers may override at
    /// `AppCoordinator.navigate(to:presentation:)`.
    var defaultPresentation: RoutePresentation {
        switch self {
        case .settings:
            .sheet
        case .home, .help, .logs:
            .push
        }
    }
}
