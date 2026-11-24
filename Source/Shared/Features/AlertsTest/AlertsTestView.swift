//
//  AlertsTestView.swift
//
//  Created on 2026-05-19.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

// Developer showcase only: never compiled into a shipped build.
#if DEBUG

/// Manual trigger surface for every `InAppAlert` variant.
///
/// Used to verify alert presentation, auto-dismiss timing, and banner
/// styling end-to-end via `AlertManager` + `AlertPresenterModifier`.
@MainActor
struct AlertsTestView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    private let logger = Log(category: .ui)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacing.xl) {
                accentSection
                bannerSection
                controlsSection
            }
            .padding(.padding.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.Background.primary)
        .navigationTitle("Alerts & Toasts")
        .onAppear {
            logger.debug("AlertsTestView appeared")
        }
    }

    // MARK: - Sections

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: .spacing.m) {
            sectionHeader("Accent Alert")

            Button("Show Accent (auto-dismiss)") {
                show(.accent(message: "Saved successfully"))
            }
            .buttonStyle(.secondary(isFullWidth: true, backgroundType: .solid))

            Button("Show Accent (loading, manual dismiss)") {
                show(.accent(message: "Loading content…", isLoading: true))
            }
            .buttonStyle(.secondary(isFullWidth: true, backgroundType: .solid))
        }
    }

    private var bannerSection: some View {
        VStack(alignment: .leading, spacing: .spacing.m) {
            sectionHeader("Banner Toast")

            Button("Info Banner") {
                show(.banner(message: "Limited stock — 5 per order", type: .info))
            }
            .buttonStyle(.secondary(isFullWidth: true, backgroundType: .solid))

            Button("Success Banner") {
                show(.banner(message: "Profile updated", type: .success))
            }
            .buttonStyle(.secondary(isFullWidth: true, backgroundType: .solid))

            Button("Error Banner") {
                show(.banner(message: "Verification failed", type: .error))
            }
            .buttonStyle(.secondary(isFullWidth: true, backgroundType: .solid))
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: .spacing.m) {
            sectionHeader("Controls")

            Button("Dismiss Current") {
                container.alertManager.dismiss()
                logger.debug("Alert dismissed manually")
            }
            .buttonStyle(.secondary(isFullWidth: true, backgroundType: .solid))
        }
    }

    // MARK: - Helpers

    private func show(_ alert: InAppAlert) {
        container.alertManager.show(alert)
        container.hapticFeedback.playSelection()
        logger.debug("Presented alert: \(alert.id)")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .labelBold()
            .foregroundStyle(Color.Label.primary)
    }
}

// MARK: - Accessibility

private struct AlertsTestBackAccessibility: AccessibilityProtocol {
    var label: String { "Back" }
    var hint: String { "Double tap to navigate back" }
    var id: String { "alertsTest.back" }
}

// MARK: - Preview

#if DEBUG

#Preview {
    NavigationStack {
        AlertsTestView()
    }
    .environment(\.appContainer, AppContainer.preview())
}

#endif
#endif
