//
//  LogLevelFilterBar.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

/// Multi-select chip bar for the four single-bit `Log.Level` values.
///
/// Enforces the "at least one selected" invariant at the UI layer by disabling
/// the chip when its tap would empty the set (delegating the actual no-op to
/// the view model — see `LogsViewerViewModel.toggle(_:)` and `canDeselect(_:)`).
///
/// Per-level title and accessibility metadata is sourced from `Log.Level`
/// (see `Log.Level+UI.swift`).
struct LogLevelFilterBar: View {
    let levels: [Log.Level]
    let isSelected: (Log.Level) -> Bool
    let canDeselect: (Log.Level) -> Bool
    let onToggle: (Log.Level) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacing.m) {
                ForEach(levels, id: \.rawValue) { level in
                    chip(for: level)
                }
            }
            .padding(.horizontal, .padding.m)
        }
    }
    
    @ViewBuilder
    private func chip(for level: Log.Level) -> some View {
        let isOn = isSelected(level)
        let canRemove = canDeselect(level)
        
        LogFilterChip(
            title: level.filterTitleKey,
            isSelected: isOn,
            accessibility: level.filterAccessibility
        ) {
            // VM also no-ops when the invariant would be broken, so this
            // disabled gate is purely a UX hint (no destructive double-tap).
            if isOn, !canRemove { return }
            onToggle(level)
        }
        .disabled(isOn && !canRemove)
        .opacity(isOn && !canRemove ? .opacity.strong : .opacity.opaque)
    }
}
