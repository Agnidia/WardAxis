//
//  Log.Level+UI.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

/// UI-facing accessors for `Log.Level` consumed by the Logs viewer
/// (`LogLevelBadge`, `LogLevelFilterBar`). Single-bit levels are assumed —
/// composite values fall through to a neutral default.
extension Log.Level {
    /// Semantic colour for the level badge / chip. Falls back to a neutral
    /// secondary tint when no single bit is set.
    var stateColor: Color {
        if contains(.error) {
            return .red
        }
        if contains(.warning) {
            return .orange
        }
        if contains(.info) {
            return .blue
        }
        if contains(.debug) {
            return .secondary
        }
        return .secondary
    }
    
    /// 3-letter ASCII token for compact rendering. Width-stable at narrow
    /// Dynamic Type sizes; paired with `stateColor` so colour-vision-deficient
    /// users still get a textual signal.
    var shortName: String {
        if contains(.error) {
            return "ERR"
        }
        if contains(.warning) {
            return "WRN"
        }
        if contains(.info) {
            return "INF"
        }
        if contains(.debug) {
            return "DBG"
        }
        return "—"
    }
    
    /// Localised title for the filter chip.
    var filterTitleKey: LocalizedStringKey {
        if contains(.error) {
            return L.Settings.Logs.levelError
        }
        if contains(.warning) {
            return L.Settings.Logs.levelWarning
        }
        if contains(.info) {
            return L.Settings.Logs.levelInfo
        }
        return L.Settings.Logs.levelDebug
    }
    
    /// Accessibility identifier for the filter chip.
    var filterAccessibility: any AccessibilityProtocol {
        if contains(.error) {
            return AccessibilityID.Logs.filterError
        }
        if contains(.warning) {
            return AccessibilityID.Logs.filterWarning
        }
        if contains(.info) {
            return AccessibilityID.Logs.filterInfo
        }
        return AccessibilityID.Logs.filterDebug
    }
}
