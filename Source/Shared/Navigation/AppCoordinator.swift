//
//  AppCoordinator.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

/// Central navigation coordinator for the application.
///
/// AppCoordinator manages all navigation state using the MVVM-C pattern,
/// providing a single source of truth for navigation across the app.
/// Presentation policy comes from `RoutePresentation` (per case default
/// or per-call override); view construction is delegated to
/// `RouteResolver`.
///
/// Example:
/// ```swift
/// @Environment(\.coordinator) var coordinator
///
/// Button("Open Settings") {
///     coordinator.navigate(to: .settings)
/// }
/// ```
@MainActor
@Observable
final class AppCoordinator {
    // MARK: - Navigation State
    
    /// Push path of the Home tab.
    var navigationPath = NavigationPath()
    
    /// Push path of the Settings tab, so a route pushed from settings lands on
    /// the stack the user sees.
    var settingsNavigationPath = NavigationPath()
    
    /// Tabs whose screen holds unsaved changes. Leaving such a tab is blocked
    /// until the tab confirms; see ``blockedTabSwitch``.
    var tabsWithUnsavedChanges: Set<Tab> = .init()
    
    /// The tab a blocked ``switchTab(to:)`` asked for. The dirty tab observes it,
    /// asks the user, then calls ``completeBlockedTabSwitch()`` or
    /// ``cancelBlockedTabSwitch()``.
    private(set) var blockedTabSwitch: Tab?
    
    /// Currently selected tab.
    var selectedTab: Tab = .home
    
    /// Route presented as a sheet modal.
    var presentedSheet: Route?
    
    /// Route presented as a full screen cover.
    var presentedFullScreenCover: Route?
    
    /// Current app phase (splash vs main content).
    var appPhase: AppPhase = .splash
    
    private let logger = Log(category: .ui)
    
    // MARK: - Tab Enum
    
    /// Available tabs in the main tab view. `Tab.title` / `Tab.systemImage`
    /// drive the tab-bar appearance (TabView Label) and are intentionally
    /// distinct from `Route` — routes are pure values without UI metadata.
    enum Tab: String, CaseIterable, Sendable {
        case home
        case settings
        
        var title: LocalizedStringKey {
            switch self {
            case .home: L.Main.Tab.home
            case .settings: L.Main.Tab.settings
            }
        }
        
        var systemImage: String {
            switch self {
            case .home: "house"
            case .settings: "gearshape"
            }
        }
    }
    
    // MARK: - App Phase
    
    /// Application phase for root view switching.
    enum AppPhase: Sendable {
        case splash
        case main
    }
    
    // MARK: - Initialization
    
    init() {
        logger.debug("AppCoordinator initialized")
    }
    
    // MARK: - Navigation Methods
    
    /// Navigate to a route using its default presentation, or an override.
    ///
    /// - Parameters:
    ///   - route: The destination route.
    ///   - override: Optional `RoutePresentation` that overrides the route's
    ///     `defaultPresentation`. Pass `nil` (default) to use the per-case
    ///     default declared in `RoutePresentation`.
    func navigate(to route: Route, presentation override: RoutePresentation? = nil) {
        let policy = override ?? route.defaultPresentation
        logger.debug("Navigating to: \(route.id) via \(String(describing: policy))")
        
        switch policy {
        case .push: push(route)
        case .sheet: presentedSheet = route
        case .fullScreenCover: presentedFullScreenCover = route
        }
    }
    
    /// Push a route onto a tab's navigation stack.
    ///
    /// - Parameters:
    ///   - route: The route to push.
    ///   - tab: The tab whose stack receives it; the selected tab by default.
    func push(_ route: Route, in tab: Tab? = nil) {
        let tab = tab ?? selectedTab
        logger.debug("Pushing route: \(route.id) on \(tab.rawValue)")
        updatePath(of: tab) { $0.append(route) }
    }
    
    /// Pop the top route from a tab's navigation stack (the selected tab by default).
    func pop(in tab: Tab? = nil) {
        let tab = tab ?? selectedTab
        guard !path(of: tab).isEmpty else { return }
        logger.debug("Popping route on \(tab.rawValue)")
        updatePath(of: tab) { $0.removeLast() }
    }
    
    /// Pop to the root of a tab's navigation stack (the selected tab by default).
    func popToRoot(in tab: Tab? = nil) {
        let tab = tab ?? selectedTab
        guard !path(of: tab).isEmpty else { return }
        logger.debug("Popping to root on \(tab.rawValue)")
        updatePath(of: tab) { $0 = NavigationPath() }
    }
    
    /// The push path of `tab`.
    func path(of tab: Tab) -> NavigationPath {
        switch tab {
        case .home: navigationPath
        case .settings: settingsNavigationPath
        }
    }
    
    private func updatePath(of tab: Tab, _ change: (inout NavigationPath) -> Void) {
        switch tab {
        case .home: change(&navigationPath)
        case .settings: change(&settingsNavigationPath)
        }
    }
    
    /// Present a route as a sheet modal.
    ///
    /// - Parameter route: The route to present.
    func present(_ route: Route) {
        logger.debug("Presenting sheet: \(route.id)")
        presentedSheet = route
    }
    
    /// Present a route as a full screen cover.
    ///
    /// - Parameter route: The route to present.
    func presentFullScreen(_ route: Route) {
        logger.debug("Presenting full screen: \(route.id)")
        presentedFullScreenCover = route
    }
    
    /// Dismiss the currently presented modal.
    func dismiss() {
        logger.debug("Dismissing modal")
        if presentedSheet != nil {
            presentedSheet = nil
        } else if presentedFullScreenCover != nil {
            presentedFullScreenCover = nil
        }
    }
    
    /// Switch to a specific tab.
    ///
    /// While the selected tab has unsaved changes the switch does not happen: it is
    /// recorded in ``blockedTabSwitch`` for that tab to confirm or cancel.
    ///
    /// - Parameter tab: The tab to switch to.
    func switchTab(to tab: Tab) {
        guard selectedTab != tab else { return }
        if tabsWithUnsavedChanges.contains(selectedTab) {
            logger.debug("Tab switch to \(tab.rawValue) waits for \(selectedTab.rawValue) to confirm")
            blockedTabSwitch = tab
            return
        }
        logger.debug("Switching to tab: \(tab.rawValue)")
        selectedTab = tab
    }
    
    /// Marks whether `tab` holds unsaved changes.
    func setUnsavedChanges(_ hasChanges: Bool, in tab: Tab) {
        if hasChanges {
            tabsWithUnsavedChanges.insert(tab)
        } else {
            tabsWithUnsavedChanges.remove(tab)
        }
    }
    
    /// Performs the blocked switch after the dirty tab discarded its changes.
    func completeBlockedTabSwitch() {
        guard let tab = blockedTabSwitch else { return }
        blockedTabSwitch = nil
        tabsWithUnsavedChanges.remove(selectedTab)
        logger.debug("Switching to tab: \(tab.rawValue)")
        selectedTab = tab
    }
    
    /// Drops the blocked switch; the user keeps editing.
    func cancelBlockedTabSwitch() {
        blockedTabSwitch = nil
    }
    
    /// Transition app phase from splash to main.
    func completeSplash() {
        logger.debug("Completing splash, transitioning to main")
        appPhase = .main
    }
    
    /// Reset coordinator to initial state (e.g., on logout).
    func reset() {
        logger.info("Resetting coordinator state")
        navigationPath = NavigationPath()
        settingsNavigationPath = NavigationPath()
        tabsWithUnsavedChanges = []
        blockedTabSwitch = nil
        selectedTab = .home
        presentedSheet = nil
        presentedFullScreenCover = nil
        appPhase = .splash
    }
    
    // MARK: - Deep Linking
    
    /// Handle a deep link URL.
    ///
    /// - Parameter url: The URL to handle.
    /// - Returns: Whether the URL was handled.
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        logger.info("Handling deep link: \(url.absoluteString)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let host = components.host
        else {
            return false
        }
        
        switch host {
        case "settings":
            // Settings has no tab; it opens as a sheet, as from the Home settings button.
            navigate(to: .settings)
            return true
        case "help":
            navigate(to: .help)
            return true
        case "home":
            switchTab(to: .home)
            return true
        default:
            logger.warning("Unknown deep link host: \(host)")
            return false
        }
    }
}

extension AppCoordinator {
    /// Non-bootstrap default for `@Environment(\.coordinator)`.
    ///
    /// Asserts in DEBUG when read off the bootstrap path so the
    /// `Application.init` → `RootView` chain is the only legitimate
    /// construction site.
    ///
    /// `nonisolated` because the `@Entry` macro synthesizes a nonisolated
    /// `static var defaultValue`; the implementation hops to MainActor via
    /// `MainActor.assumeIsolated` (safe — SwiftUI invokes environment
    /// default resolution from the main thread during view evaluation).
    nonisolated static func placeholder() -> AppCoordinator {
        MainActor.assumeIsolated {
            // assertionFailure intentionally omitted — see AppContainer.placeholder()
            // for the rationale (test host startup evaluates @Entry defaults).
            AppCoordinator()
        }
    }
}

extension AppCoordinator {
    /// Built once: an `@Entry` default expression runs on every access.
    nonisolated static let environmentDefault: AppCoordinator = placeholder()
}

extension EnvironmentValues {
    @Entry var coordinator: AppCoordinator = .environmentDefault
}
