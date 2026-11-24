//
//  LogDateRangeFilterBar.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// Single-select chip bar for the `LogDateRange` filter.
///
/// Exactly one chip is active at all times — the view model's `select(_:)`
/// no-ops when the active chip is re-tapped, so no `.disabled` modifier is
/// needed (re-tap is non-destructive).
///
/// Per-range title and accessibility metadata is sourced from
/// `LogDateRange` (see `LogDateRange+UI.swift`).
struct LogDateRangeFilterBar: View {
    let ranges: [LogDateRange]
    let isSelected: (LogDateRange) -> Bool
    let onSelect: (LogDateRange) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing.m) {
                ForEach(ranges, id: \.rawValue) { range in
                    LogFilterChip(
                        title: range.filterTitleKey,
                        isSelected: isSelected(range),
                        accessibility: range.filterAccessibility
                    ) {
                        onSelect(range)
                    }
                }
            }
            .padding(.horizontal, .padding.m)
        }
    }
}

/// Lightweight chip used by the Logger filter bars. Local to the Logger UI
/// module (no SelectableChip control exists in the design system yet).
struct LogFilterChip: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let accessibility: any AccessibilityProtocol
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .bodySmall()
                .foregroundStyle(isSelected ? Color.white : .primary)
                .padding(.horizontal, .spacing.xl)
                .padding(.vertical, .spacing.m)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(.opacity.faint))
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibility.id)
        .accessibilityLabel(accessibility.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
