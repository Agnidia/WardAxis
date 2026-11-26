//
//  SettingsView.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

/// Settings form showcasing dismissible sheet pattern.
///
/// Demonstrates:
/// - `L.Settings.*` localized strings
/// - `L.Common.done` for toolbar action
/// - NavigationStack in sheet context
///
/// Diagnostics section exposes a navigation entry into the in-app log
/// viewer. Top-level Share / Clean log affordances and their alert
/// state live in ``SettingsViewModel`` (replaces the deleted
/// ``LogActionsModel`` per analyzing-0.md ad4).
@MainActor
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container
    
    @State private var viewModel: SettingsViewModel?
    @State private var isShowingClearConfirmation: Bool = false
#if DEBUG && os(macOS)
    @State private var systemExtensionViewModel: SystemExtensionDebugViewModel?
#endif

    private let logger = Log(category: .ui)
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    placeholderContent
                }
                
                Section(L.Settings.appearance) {
                    Toggle(L.Settings.darkMode, isOn: .constant(false))
                }
                
                Section(L.Settings.privacy) {
                    // Telemetry is opt-in; the consent flow will bind this. Off until then.
                    Toggle(L.Settings.analyticsEnabled, isOn: .constant(false))
                }
                
                Section(L.Settings.diagnostics) {
                    NavigationLink(value: Route.logs) {
                        Label(L.Settings.Logs.title, systemImage: "doc.text.magnifyingglass")
                    }
                }
#if DEBUG && os(macOS)
                developerSection
#endif
            }
            .padding(.padding.xl)
            .navigationTitle(L.Settings.title)
            .navigationDestination(for: Route.self) { route in
                destinationView(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.Common.done) {
                        logger.debug("Settings dismissed")
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                L.Settings.Logs.clearTitle,
                isPresented: $isShowingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button(L.Settings.Logs.clearConfirm, role: .destructive) {
                    Task { await viewModel?.clearAll() }
                }
                Button(L.Settings.Logs.clearCancel, role: .cancel) {}
            } message: {
                Text(L.Settings.Logs.clearMessage)
            }
            .alert(item: clearedNoticeBinding) { _ in
                Alert(
                    title: Text(L.Settings.Logs.clearedToast),
                    dismissButton: .default(Text(L.Common.ok))
                )
            }
            .alert(item: shareErrorBinding) { error in
                Alert(
                    title: Text(L.Settings.Logs.errorTitle),
                    message: Text(error.message),
                    dismissButton: .default(Text(L.Common.ok))
                )
            }
            .task {
                if viewModel == nil {
                    viewModel = SettingsViewModel(logReader: container.logReaderService)
                }
#if DEBUG && os(macOS)
                if systemExtensionViewModel == nil {
                    systemExtensionViewModel = SystemExtensionDebugViewModel(service: container.systemExtensionService)
                }
#endif
                await viewModel?.refreshHasEntries()
            }
        }
        .accessibilityIdentifier(AccessibilityID.Screen.settings)
        .onAppear {
            logger.debug("SettingsView appeared")
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .logs:
            LogsViewerView()
        default:
            EmptyView()
        }
    }
    
    // MARK: - Alert bindings
    
    /// Binds the ``SettingsViewModel.clearedNotice`` through an
    /// optional-aware binding so the existing `.alert(item:)` overloads
    /// keep working even when the view model has not yet been built.
    private var clearedNoticeBinding: Binding<SettingsViewModel.ClearedNotice?> {
        Binding(
            get: { viewModel?.clearedNotice },
            set: { newValue in viewModel?.clearedNotice = newValue }
        )
    }
    
    private var shareErrorBinding: Binding<SettingsViewModel.ShareError?> {
        Binding(
            get: { viewModel?.shareError },
            set: { newValue in viewModel?.shareError = newValue }
        )
    }
    
    // MARK: - Subviews

#if DEBUG && os(macOS)
    /// Absent from release builds: a shipped control that installs extensions is attack surface (ADR 0006 D1).
    private var developerSection: some View {
        let isBusy = systemExtensionViewModel?.isBusy ?? true
        return Section {
            Button(L.Settings.Developer.activate) {
                Task { await systemExtensionViewModel?.activate() }
            }
            .disabled(isBusy)
            .accessibilityIdentifier(AccessibilityID.Developer.activateButton.id)
            
            Button(L.Settings.Developer.deactivate) {
                Task { await systemExtensionViewModel?.deactivate() }
            }
            .disabled(isBusy)
            .accessibilityIdentifier(AccessibilityID.Developer.deactivateButton.id)
            
            LabeledContent(L.Settings.Developer.stateTitle) {
                Text(systemExtensionViewModel?.installStateText ?? L.Settings.Developer.stateUnknown)
            }
            .accessibilityIdentifier(AccessibilityID.Developer.installState.id)
            
            Text(systemExtensionViewModel?.statusText ?? L.Settings.Developer.statusIdle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(AccessibilityID.Developer.status.id)
        } header: {
            Text(L.Settings.Developer.title)
        } footer: {
            Text(L.Settings.Developer.footer)
        }
        // Restarts once the view model exists; cancelled when Settings closes, which stops the polling.
        .task(id: systemExtensionViewModel == nil) {
            await systemExtensionViewModel?.monitorInstallState()
        }
    }
#endif

    private var placeholderContent: some View {
        VStack(alignment: .leading, spacing: CGFloat.spacing.m) {
            Text(L.Settings.placeholder)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, CGFloat.spacing.s)
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG
#Preview {
    SettingsView()
        .environment(\.appContainer, AppContainer.preview())
}
#endif
