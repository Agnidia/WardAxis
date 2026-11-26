//
//  SelectableChip.swift
//
//  Created on 05.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Selectable Chip

/// A capsule-shaped, selectable chip used for filters or tag selection.
///
/// Visually toggles between selected (filled) and unselected (soft background) states.
struct SelectableChip: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let accessibilityConfig: any AccessibilityProtocol
    let action: Closure.EmptyBlock
    
    init(
        title: LocalizedStringKey,
        isSelected: Bool,
        accessibility: any AccessibilityProtocol,
        action: @escaping Closure.EmptyBlock
    ) {
        self.title = title
        self.isSelected = isSelected
        accessibilityConfig = accessibility
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .bodyMono()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, .spacing.xl)
        .padding(.vertical, .spacing.m)
        .foregroundStyle(isSelected ? Color.Brand.base : Color.Brand.primary)
        .background(isSelected ? Color.Brand.primary : Color.Brand.primary.opacity(.opacity.faint))
        .clipShape(Capsule())
        .accessibleSelectable(
            label: accessibilityConfig.label,
            identifier: accessibilityConfig.id,
            isSelected: isSelected
        )
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Selectable Chip") {
    HStack(spacing: 8) {
        SelectableChip(
            title: "All",
            isSelected: true,
            accessibility: PreviewChipAccessibility(),
            action: {}
        )
        
        SelectableChip(
            title: "Featured",
            isSelected: false,
            accessibility: PreviewChipAccessibility(),
            action: {}
        )
    }
    .padding()
    .background(Color.Background.primary)
}

private struct PreviewChipAccessibility: AccessibilityProtocol {
    var label: String {
        "Filter"
    }
    
    var hint: String {
        "Double tap to toggle"
    }
    
    var id: String {
        "chip"
    }
}

#endif
