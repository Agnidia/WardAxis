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
    /// The single level a value stands for: its highest-priority bit
    /// (`.error` > `.warning` > `.info` > `.debug`), or `nil` when none is set.
    enum Primary {
        case error
        case warning
        case info
        case debug
    }
    
    var primary: Primary? {
        if contains(.error) {
            .error
        } else if contains(.warning) {
            .warning
        } else if contains(.info) {
            .info
        } else if contains(.debug) {
            .debug
        } else {
            nil
        }
    }
    
    /// Semantic colour for the level badge / chip. Falls back to a neutral
    /// secondary tint when no single bit is set.
    var stateColor: Color {
        switch primary {
        case .error: .red
        case .warning: .orange
        case .info: .blue
        case .debug, nil: .secondary
        }
    }
    
    /// 3-letter ASCII token for compact rendering. Width-stable at narrow
    /// Dynamic Type sizes; paired with `stateColor` so colour-vision-deficient
    /// users still get a textual signal.
    var shortName: String {
        switch primary {
        case .error: "ERR"
        case .warning: "WRN"
        case .info: "INF"
        case .debug: "DBG"
        case nil: "—"
        }
    }
    
    /// Localised title for the filter chip.
    var filterTitleKey: LocalizedStringKey {
        switch primary {
        case .error: L.Settings.Logs.levelError
        case .warning: L.Settings.Logs.levelWarning
        case .info: L.Settings.Logs.levelInfo
        case .debug, nil: L.Settings.Logs.levelDebug
        }
    }
    
    /// Accessibility identifier for the filter chip.
    var filterAccessibility: any AccessibilityProtocol {
        switch primary {
        case .error: AccessibilityID.Logs.filterError
        case .warning: AccessibilityID.Logs.filterWarning
        case .info: AccessibilityID.Logs.filterInfo
        case .debug, nil: AccessibilityID.Logs.filterDebug
        }
    }
}
