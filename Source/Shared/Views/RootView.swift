//
//  RootView.swift
//
//  Created on 08.03.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisManagement
import WardAxisTelemetry

/// Root view that hosts the app coordinator and manages navigation.
///
/// RootView is the entry point for the app's view hierarchy. It:
/// - Hosts the AppCoordinator for centralized navigation
/// - Manages app phase transitions (splash → main)
/// - Handles deep links via onOpenURL
/// - Provides NavigationStack with route-based destinations
///
/// Example:
/// ```swift
/// @State private var coordinator = AppCoordinator()
///
/// RootView(coordinator: coordinator)
///     .modelContainer(for: Item.self)
/// ```
@MainActor
struct RootView: View {
    // MARK: - Properties
    
    @Bindable var coordinator: AppCoordinator
    @Environment(\.appContainer) private var container
    
    private let resolver = RouteResolver()
    private let logger = Log(category: .ui)
    
    // MARK: - Body
    
    var body: some View {
        Group {
            switch coordinator.appPhase {
            case .splash: 
                splashOverlay
            case .main:
                mainContent
                    .environment(\.coordinator, coordinator)
                    .modifier(AlertPresenterModifier(alertManager: container.alertManager))
            }
        }
        .onOpenURL { url in coordinator.handleDeepLink(url) }
        .animation(.easeInOut(duration: AnimationDuration.normal), value: coordinator.appPhase)
        // No enrollment flow exists yet: report the device as unenrolled, which
        // also deletes a configuration cached by an earlier enrollment.
        .onAppear {
            container.configurationService.enrollmentDidChange(to: .unenrolled)
        }
        .onAppear {
            logger.debug("RootView appeared")
        }
    }
    
    // MARK: - Splash Overlay
    
    private var splashOverlay: some View {
        // macOS: Full-screen blocking background with centered splash card
        SplashView {
            coordinator.completeSplash()
        }
#if os(macOS)
        .frame(width: 400, height: 300)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat.radius.xl))
        .shadow(radius: Shadow.hoverRadius, y: Shadow.hoverY)
#else
        .frameInfinite()
        .background(Color.Background.primary)
#endif
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        CoordinatedMainTabView(coordinator: coordinator, resolver: resolver)
            .sheet(item: $coordinator.presentedSheet) { route in
                NavigationStack {
                    resolver.view(for: route)
                }
            }
#if canImport(UIKit)
            .fullScreenCover(item: $coordinator.presentedFullScreenCover) { route in
                resolver.view(for: route)
            }
#endif
    }
}

// MARK: - Coordinated Main Tab View

/// Tab view that integrates with the coordinator.
@MainActor
struct CoordinatedMainTabView: View {
    @Bindable var coordinator: AppCoordinator
    let resolver: RouteResolver
    
    @Environment(\.appContainer) private var container
    
    private let logger = Log(category: .ui)
    
    var body: some View {
        // Through switchTab(to:), so a tab with unsaved changes can hold the switch.
        TabView(selection: Binding(get: { coordinator.selectedTab }, set: { coordinator.switchTab(to: $0) })) {
            homeTab
        }
        .onAppear {
            logger.debug("CoordinatedMainTabView appeared")
        }
        .onChange(of: coordinator.selectedTab) { _, newTab in
            container.telemetry.track(.tabSelected(newTab.rawValue))
            AccessibilityAnnouncer.screenChanged()
        }
    }
    
    // MARK: - Tabs
    
    private var homeTab: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    resolver.view(for: route)
                }
        }
        .tabItem {
            Label(AppCoordinator.Tab.home.title, systemImage: AppCoordinator.Tab.home.systemImage)
        }
        .tag(AppCoordinator.Tab.home)
    }
    
    private var settingsTab: some View {
        NavigationStack(path: $coordinator.settingsNavigationPath) {
            SettingsView()
                .navigationDestination(for: Route.self) { route in
                    resolver.view(for: route)
                }
        }
        .tabItem {
            Label(AppCoordinator.Tab.settings.title, systemImage: AppCoordinator.Tab.settings.systemImage)
        }
        .tag(AppCoordinator.Tab.settings)
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG
#Preview {
    @MainActor
    func makeView() -> some View {
        let coordinator = AppCoordinator()
        coordinator.appPhase = .main
        return RootView(coordinator: coordinator)
            .environment(\.appContainer, AppContainer.preview())
    }
    return makeView()
}
#endif
