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
                    SelectableChip(
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
