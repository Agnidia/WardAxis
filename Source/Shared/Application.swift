//
//  Application.swift
//
//  Created on 08.03.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

@main
struct Application: App {
    /// App coordinator for centralized navigation.
    @State private var coordinator = AppCoordinator()
    
    /// Dependency-injection container holding all long-lived services.
    @State private var container: AppContainer
    
    /// Aggregate over every scene: background only when no scene is in the foreground.
    @Environment(\.scenePhase) private var scenePhase
    
    private let logger = Log(category: .application)
    
    init() {
#if DEBUG
        Log.configure(for: .debug)
#else
        Log.configure(for: .release)
#endif

        _container = State(initialValue: AppContainer.production())
        
        logger.info("Application initialized")
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
                .environment(\.appContainer, container)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            container.configurationService.sceneDidChange(isForeground: phase != .background)
        }
#if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(WindowSize.main)
#endif
    }
}
