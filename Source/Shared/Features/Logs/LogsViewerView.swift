//
//  LogsViewerView.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// In-app Logs viewer.
///
/// Read-only view of the persisted log file (`Library/Logs/<bundleID>/log.log`)
/// with multi-select level filtering, date-range filtering, and ShareLink
/// export of the currently filtered entries. Hosted by the Settings flow.
///
/// Phase 1 platform scope: full UI on iOS + macOS; placeholder
/// (`LogsUnavailableView`) on tvOS / watchOS / visionOS.
struct LogsViewerView: View {
    @Environment(\.appContainer) private var container
    
    @State private var viewModel: LogsViewerViewModel?
    @State private var isShowingClearConfirmation: Bool = false
    @State private var shareError: ShareError?
    @State private var preparedShareURL: URL?
    
    /// `Identifiable` wrapper so error alerts can be presented for each new failure.
    private struct ShareError: Identifiable {
        let id = UUID()
        let message: LocalizedStringKey
    }
    
    var body: some View {
#if os(iOS) || os(macOS)
        loadedViewer
#else
        LogsUnavailableView()
#endif
    }

#if os(iOS) || os(macOS)
    private var loadedViewer: some View {
        Group {
            if let vm = viewModel {
                content(viewModel: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(L.Settings.Logs.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                if let vm = viewModel {
                    toolbarItems(viewModel: vm)
                }
            }
            .accessibilityIdentifier(AccessibilityID.Logs.panel.id)
            .task {
                if viewModel == nil {
                    let vm = LogsViewerViewModel(service: container.logReaderService)
                    viewModel = vm
                    await vm.load()
                }
            }
            .task {
                // Auto-refresh while the panel is on screen. The loop exits
                // automatically when SwiftUI cancels this task on disappear.
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: LogsViewerViewModel.autoRefreshInterval)
                    } catch {
                        return
                    }
                    await viewModel?.refreshSilently()
                }
            }
            .alert(item: $shareError) { error in
                Alert(
                    title: Text(L.Settings.Logs.errorTitle),
                    message: Text(error.message),
                    dismissButton: .default(Text(L.Common.ok))
                )
            }
            .confirmationDialog(
                L.Settings.Logs.clearTitle,
                isPresented: $isShowingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button(L.Settings.Logs.clearConfirm, role: .destructive) {
                    if let vm = viewModel {
                        Task { await vm.clear() }
                    }
                }
                Button(L.Settings.Logs.clearCancel, role: .cancel) {}
            } message: {
                Text(L.Settings.Logs.clearMessage)
            }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private func toolbarItems(viewModel: LogsViewerViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            toolbarButtonsItems(viewModel: viewModel)
        }
    }
    
    private func toolbarButtonsItems(viewModel: LogsViewerViewModel) -> some View {
        HStack(spacing: .spacing.s) {
            refreshButton(viewModel: viewModel)
            
            if let url = preparedShareURL {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityIdentifier(AccessibilityID.Logs.shareButton.id)
                .accessibilityLabel(AccessibilityID.Logs.shareButton.label)
            } else {
                prepareShareButton(viewModel: viewModel)
            }
            
            clearButton(viewModel: viewModel)
        }
    }
    
    private func refreshButton(viewModel: LogsViewerViewModel) -> some View {
        Button {
            Task { await viewModel.refresh() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .accessibilityIdentifier(AccessibilityID.Logs.refreshButton.id)
        .accessibilityLabel(AccessibilityID.Logs.refreshButton.label)
        .disabled(viewModel.state.isLoading)
    }
    
    private func prepareShareButton(viewModel: LogsViewerViewModel) -> some View {
        Button {
            Task { await prepareShare(viewModel: viewModel) }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityIdentifier(AccessibilityID.Logs.shareButton.id)
        .accessibilityLabel(AccessibilityID.Logs.shareButton.label)
        .disabled(!viewModel.isShareEnabled)
    }
    
    private func clearButton(viewModel: LogsViewerViewModel) -> some View {
        Button(role: .destructive) {
            isShowingClearConfirmation = true
        } label: {
            Image(systemName: "trash")
        }
        .accessibilityIdentifier(AccessibilityID.Logs.clearButton.id)
        .accessibilityLabel(AccessibilityID.Logs.clearButton.label)
        .disabled(!viewModel.isClearEnabled)
    }
    
    // MARK: - Content
    
    private func content(viewModel: LogsViewerViewModel) -> some View {
        VStack(spacing: .spacing.m) {
            LogLevelFilterBar(
                levels: LogsViewerViewModel.filterableLevels,
                isSelected: viewModel.isSelected,
                canDeselect: viewModel.canDeselect,
                onToggle: viewModel.toggle
            )
            .padding(.top, .padding.s)
            
            LogDateRangeFilterBar(
                ranges: LogsViewerViewModel.filterableDateRanges,
                isSelected: viewModel.isSelected,
                onSelect: viewModel.select
            )
            
            counterRow(viewModel: viewModel)
            
            switch viewModel.state {
            case .loading:
                loadingState
            case .loaded:
                loadedContent(viewModel: viewModel)
            case .failed(let error):
                errorState(error: error, viewModel: viewModel)
            }
            HStack {
#if DEBUG
                testLogsButton(viewModel: viewModel)
#endif
#if os(macOS)
                Spacer()
                toolbarButtonsItems(viewModel: viewModel)
                    .padding(.trailing, .padding.m)
#endif
            }
        }
        .padding(.bottom, .padding.s)
        .onChange(of: viewModel.filteredEntries) { _, _ in
            // Invalidate prepared share URL when the filter set changes.
            preparedShareURL = nil
        }
    }
    
    private func counterRow(viewModel: LogsViewerViewModel) -> some View {
        HStack(spacing: .spacing.s) {
            Text(L.Settings.Logs.entryCount(viewModel.totalEntryCount, viewModel.filteredOutCount))
                .bodySmall()
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, .padding.m)
    }
    
    @ViewBuilder
    private var loadingState: some View {
        Spacer()
        ProgressView()
        Spacer()
    }
    
    @ViewBuilder
    private func loadedContent(viewModel: LogsViewerViewModel) -> some View {
        if !viewModel.hasAnyEntries {
            emptyState(messageKey: L.Settings.Logs.empty)
        } else if viewModel.filteredEntries.isEmpty {
            emptyState(messageKey: L.Settings.Logs.filterEmpty)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: .spacing.s) {
                    ForEach(viewModel.filteredEntries) { entry in
                        LogRowView(entry: entry)
                            .padding(.horizontal, .padding.m)
                    }
                }
                .padding(.vertical, .padding.s)
            }
        }
    }
    
    private func emptyState(messageKey: LocalizedStringKey) -> some View {
        VStack(spacing: .spacing.l) {
            Spacer()
            Text(messageKey)
                .bodyLarge()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, .padding.l)
            Spacer()
        }
    }
    
    private func errorState(error: LogReaderError, viewModel: LogsViewerViewModel) -> some View {
        VStack(spacing: .spacing.l) {
            Spacer()
            
            Text(L.Settings.Logs.errorTitle)
                .bodyLarge()
                .foregroundStyle(.red)
            
            Text(errorKey(for: error))
                .bodySmall()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, .padding.l)
            
            Button(L.Common.tryAgain) {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, .padding.m)
            
            Spacer()
        }
    }
    
    private func errorKey(for error: LogReaderError) -> LocalizedStringKey {
        switch error {
        case .fileMissing: L.Settings.Logs.errorFileMissing
        case .permissionDenied: L.Settings.Logs.errorPermissionDenied
        case .readFailed: L.Settings.Logs.errorReadFailed
        case .writeFailed: L.Settings.Logs.errorWriteFailed
        }
    }
    
    // MARK: - Debug

#if DEBUG
    private func testLogsButton(viewModel: LogsViewerViewModel) -> some View {
        Button(L.Settings.Logs.testButton) {
            Task { await viewModel.generateTestLogs() }
        }
        .padding(.horizontal, .padding.m)
        .accessibilityIdentifier(AccessibilityID.Logs.testButton.id)
        .disabled(viewModel.state.isLoading)
    }
#endif

    // MARK: - Actions
    
    private func prepareShare(viewModel: LogsViewerViewModel) async {
        do {
            let url = try await viewModel.share()
            preparedShareURL = url
        } catch {
            shareError = ShareError(message: L.Settings.Logs.errorShareFailed)
        }
    }
#endif
}

// MARK: - Preview

#if DEBUG

#Preview {
    NavigationStack {
        LogsViewerView()
    }
    .environment(\.appContainer, AppContainer.preview())
}

#endif
