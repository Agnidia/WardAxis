//
//  ToggleRow.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Toggle Row

/// A settings toggle row matching the design system.
///
/// Features:
/// - Label on left (Menlo uppercase)
/// - Native Toggle control on right
/// - Optional divider below
/// - Soft gray background with rounded top corners
///
/// Usage:
/// ```swift
/// ToggleRow(
///     label: "Enable notifications",
///     isOn: $notificationsEnabled,
///     showDivider: true,
///     accessibility: AccessibilityID.Settings.notifications
/// )
/// ```
struct ToggleRow: View {
    let label: LocalizedStringKey
    @Binding var isOn: Bool
    let showDivider: Bool
    let accessibilityConfig: any AccessibilityProtocol
    
    /// Creates a toggle row.
    /// - Parameters:
    ///   - label: The label text
    ///   - isOn: Binding to the toggle state
    ///   - showDivider: Whether to show a divider below (defaults to true)
    ///   - accessibility: Accessibility configuration
    init(
        label: LocalizedStringKey,
        isOn: Binding<Bool>,
        showDivider: Bool = true,
        accessibility: any AccessibilityProtocol
    ) {
        self.label = label
        _isOn = isOn
        self.showDivider = showDivider
        accessibilityConfig = accessibility
    }
    
    var body: some View {
        VStack(spacing: .zero) {
            // Toggle container
            HStack {
                Text(label)
                    .bodyMono()
                    .foregroundStyle(Color.Label.primary)
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(Color.Label.secondary)
            }
            .padding(.horizontal, .spacing.xxl)
            .padding(.vertical, .spacing.xl)
            .frame(height: FormSize.toggleHeight)
            .background(Color.Background.primary)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: .radius.m,
                    bottomLeadingRadius: showDivider ? .zero : .radius.m,
                    bottomTrailingRadius: showDivider ? .zero : .radius.m,
                    topTrailingRadius: .radius.m
                )
            )
            
            // Divider
            if showDivider {
                Divider()
                    .background(Color.Label.secondary)
            }
        }
        .accessibleGroup(accessibilityConfig)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Toggle Row") {
    VStack(spacing: .zero) {
        ToggleRow(
            label: "Notifications",
            isOn: .constant(true),
            showDivider: true,
            accessibility: PreviewToggleAccessibility()
        )
        
        ToggleRow(
            label: "Dark Mode",
            isOn: .constant(false),
            showDivider: false,
            accessibility: PreviewToggleAccessibility()
        )
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.Background.primary)
}

// MARK: - Preview Accessibility Helper

private struct PreviewToggleAccessibility: AccessibilityProtocol {
    var label: String {
        "Toggle setting"
    }
    
    var hint: String {
        "Double tap to toggle"
    }
    
    var id: String {
        "toggle-row"
    }
}

#endif
