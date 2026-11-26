//
//  HomeView.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

/// Home tab content with coordinator integration.
///
/// Demonstrates:
/// - `L.Main.Home.*` localized strings
/// - `AccessibilityID.Home` identifiers
/// - Coordinator-based navigation
@MainActor
struct HomeView: View {
    @Environment(\.coordinator) private var coordinator
    @Environment(\.appContainer) private var container
    
    private let logger = Log(category: .ui)
    
    var body: some View {
        ScrollView {
            VStack(spacing: CGFloat.spacing.xxl) {
                welcomeSection
                featuresSection
            }
            .padding(CGFloat.padding.m)
        }
        .navigationTitle(L.Main.Tab.home)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    coordinator.navigate(to: .settings)
                    container.hapticFeedback.playSelection()
                } label: {
                    Image(systemName: "gear")
                }
                .accessible(AccessibilityID.Home.settingsButton)
            }
        }
        .onAppear {
            logger.debug("HomeView appeared")
        }
    }
    
    // MARK: - Sections
    
    private var welcomeSection: some View {
        VStack(spacing: CGFloat.spacing.m) {
            Image(systemName: "house.fill")
                .font(.system(size: IconSize.xxl))
                .foregroundStyle(Color.Background.secondary)
                .accessibleDecorativeImage()
            
            Text(L.Main.Home.welcome)
                .title()
            
            Text(L.Main.Home.welcomeSubtitle)
                .bodyText()
                .foregroundStyle(Color.Label.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, CGFloat.spacing.xl)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: CGFloat.spacing.m) {
            Text(L.Main.Home.features)
                .labelBold()
            
            VStack(spacing: CGFloat.spacing.s) {
                featureButton(title: L.Main.Home.helpCenter, route: .help, icon: "questionmark.circle")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Feature Button
    
    private func featureButton(title: LocalizedStringKey, route: Route, icon: String) -> some View {
        Button {
            coordinator.navigate(to: route)
            container.hapticFeedback.playSelection()
        } label: {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.secondary(isFullWidth: true, backgroundType: .solid))
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG
#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(\.coordinator, AppCoordinator())
    .environment(\.appContainer, AppContainer.preview())
}
#endif
