//
//  RouteResolver.swift
//
//  Created on 19.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// Maps a `Route` to a concrete SwiftUI view.
///
/// The only place in the codebase that knows about both `Route`
/// and feature views. `AppCoordinator` is a pure navigation-state
/// machine; this resolver is its UI-construction counterpart.
@MainActor
struct RouteResolver {
    @ViewBuilder
    func view(for route: Route) -> some View {
        switch route {
        case .home: HomeView()
        case .settings: SettingsView()
        case .help: HelpView()
        case .logs: LogsViewerView()
        }
    }
}
