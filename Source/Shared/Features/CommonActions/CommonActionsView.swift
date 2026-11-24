//
//  CommonActionsView.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

/// Button showcase demonstrating all common action strings.
///
/// Demonstrates:
/// - All `L.Common.*` localized strings
/// - Haptic feedback on selection
/// - Accessibility announcements for state changes
@MainActor
struct CommonActionsView: View {
    @Environment(\.appContainer) private var container
    
    @State private var selectedAction: String?
    @State private var lastTappedAction: String?
    
    private let logger = Log(category: .ui)
    
    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.spacing.l) {
            Text(L.Common.commonActions)
                .font(.headline)
                .padding(.horizontal, CGFloat.padding.s)
            
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: CGFloat.spacing.m
            ) {
                ForEach(commonActions, id: \.key) { action in
                    actionButton(for: action)
                }
            }
            
            if let lastTapped = lastTappedAction {
                Text(verbatim: "\(String(localized: "common.lastTapped")): \(lastTapped)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, CGFloat.padding.s)
            }
        }
        .padding(CGFloat.padding.m)
        .onAppear {
            logger.debug("CommonActionsView appeared")
        }
    }
    
    // MARK: - Subviews
    
    private func actionButton(for action: CommonAction) -> some View {
        Button {
            handleTap(action)
        } label: {
            Text(action.label)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CGFloat.spacing.m)
        }
        .buttonStyle(.bordered)
        .tint(selectedAction == action.key ? .accentColor : nil)
        .accessibilityIdentifier("common.action.\(action.key)")
    }
    
    // MARK: - Actions
    
    private func handleTap(_ action: CommonAction) {
        selectedAction = action.key
        lastTappedAction = action.key
        logger.debug("Action tapped: \(action.key)")
        
        container.hapticFeedback.playSelection()
        
        AccessibilityAnnouncer.announce("Selected \(action.key)")
    }
    
    // MARK: - Data
    
    private var commonActions: [CommonAction] {
        [
            CommonAction(key: "ok", label: L.Common.ok),
            CommonAction(key: "cancel", label: L.Common.cancel),
            CommonAction(key: "close", label: L.Common.close),
            CommonAction(key: "done", label: L.Common.done),
            CommonAction(key: "back", label: L.Common.back),
            CommonAction(key: "continue", label: L.Common.continueButton),
            CommonAction(key: "skip", label: L.Common.skip),
            CommonAction(key: "apply", label: L.Common.apply),
            CommonAction(key: "tryAgain", label: L.Common.tryAgain),
            CommonAction(key: "selected", label: L.Common.selected)
        ]
    }
}

// MARK: - Common Action Model

private struct CommonAction: Identifiable {
    let key: String
    let label: LocalizedStringKey
    
    var id: String {
        key
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    CommonActionsView()
        .environment(\.appContainer, AppContainer.preview())
}
#endif
