//
//  RowView.swift
//
//  Created on 05.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Row View

/// A menu/list row with optional leading and trailing content.
///
/// Features:
/// - Localized text label in the center
/// - Optional leading and trailing `@ViewBuilder` slots
/// - Configurable background color and tap action
struct RowView<LeadingContent: View, TrailingContent: View>: View {
    let label: LocalizedStringKey
    let backgroundColor: Color
    
    @ViewBuilder let leadingContent: () -> LeadingContent
    @ViewBuilder let trailingContent: () -> TrailingContent
    
    let accessibilityConfig: any AccessibilityProtocol
    let action: Closure.EmptyBlock
    
    init(
        label: LocalizedStringKey,
        backgroundColor: Color = .clear,
        accessibility: any AccessibilityProtocol,
        action: @escaping Closure.EmptyBlock,
        @ViewBuilder leading: @escaping () -> LeadingContent,
        @ViewBuilder trailing: @escaping () -> TrailingContent
    ) {
        self.label = label
        self.backgroundColor = backgroundColor
        accessibilityConfig = accessibility
        self.action = action
        leadingContent = leading
        trailingContent = trailing
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: .spacing.m) {
                let content = leadingContent()
                if (content is EmptyView) == false {
                    content
                }
                
                Text(label)
                    .bodyMono()
                    .foregroundStyle(Color.Label.primary)
                
                Spacer()
                
                trailingContent()
            }
            .padding(.leading, .padding.m)
            .padding([.vertical, .trailing], .spacing.xl)
            .background(backgroundColor)
        }
        .buttonStyle(.plain)
        .accessible(accessibilityConfig)
    }
}

// MARK: - Convenience Initializers

extension RowView where LeadingContent == EmptyView, TrailingContent == EmptyView {
    /// Creates a row without leading or trailing content.
    init(
        label: LocalizedStringKey,
        backgroundColor: Color = .clear,
        accessibility: any AccessibilityProtocol,
        action: @escaping Closure.EmptyBlock
    ) {
        self.init(
            label: label,
            backgroundColor: backgroundColor,
            accessibility: accessibility,
            action: action,
            leading: { EmptyView() },
            trailing: { EmptyView() }
        )
    }
}

extension RowView where LeadingContent == EmptyView, TrailingContent == ColorSwatchView {
    /// Creates a row with a trailing color swatch.
    init(
        label: LocalizedStringKey,
        color: Color,
        backgroundColor: Color = .clear,
        accessibility: any AccessibilityProtocol,
        action: @escaping Closure.EmptyBlock
    ) {
        self.init(
            label: label,
            backgroundColor: backgroundColor,
            accessibility: accessibility,
            action: action,
            leading: { EmptyView() },
            trailing: { ColorSwatchView(color: color) }
        )
    }
}

// MARK: - Color Swatch View

/// A circular color swatch for color palette displays.
struct ColorSwatchView: View {
    let color: Color
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: FormSize.colorSwatchSize, height: FormSize.colorSwatchSize)
            .overlay(
                Circle()
                    .stroke(Color.Background.secondary, lineWidth: .lineWidth.thin)
            )
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Row View") {
    VStack(spacing: .spacing.l) {
        RowView(
            label: "Soft Pink",
            accessibility: PreviewRowAccessibility()
        ) {
            // Tapped
        }
        
        RowView(
            label: "Coral",
            color: .orange,
            accessibility: PreviewRowAccessibility()
        ) {
            // Tapped
        }
        
        RowView(
            label: "Privacy",
            backgroundColor: Color.Background.secondary,
            accessibility: PreviewRowAccessibility(),
            action: {}
        ) {
            Image(systemName: "lock")
                .frame(width: IconSize.s, height: IconSize.s)
                .padding(.trailing, .padding.s)
                .foregroundStyle(Color.Label.secondary)
        } trailing: {
            Image(systemName: "chevron.right")
                .frame(width: IconSize.s, height: IconSize.s)
                .foregroundStyle(Color.Label.primary)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.Background.primary)
}

private struct PreviewRowAccessibility: AccessibilityProtocol {
    var label: String {
        "Menu option"
    }
    
    var hint: String {
        "Double tap to select"
    }
    
    var id: String {
        "menu-row"
    }
}

#endif
