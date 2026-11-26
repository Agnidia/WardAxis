//
//  LogDateRange+UI.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

/// UI-facing accessors for `LogDateRange` consumed by the Logs viewer
/// (`LogDateRangeFilterBar`). Mirrors the structure of `Log.Level+UI`.
extension LogDateRange {
    /// Localised title for the filter chip.
    var filterTitleKey: LocalizedStringKey {
        switch self {
        case .tenMinutes: L.Settings.Logs.DateRange.tenMinutes
        case .thirtyMinutes: L.Settings.Logs.DateRange.thirtyMinutes
        case .oneHour: L.Settings.Logs.DateRange.oneHour
        case .oneDay: L.Settings.Logs.DateRange.oneDay
        case .all: L.Settings.Logs.DateRange.all
        }
    }
    
    /// Accessibility identifier for the filter chip.
    var filterAccessibility: any AccessibilityProtocol {
        switch self {
        case .tenMinutes: AccessibilityID.Logs.filterDateRange10min
        case .thirtyMinutes: AccessibilityID.Logs.filterDateRange30min
        case .oneHour: AccessibilityID.Logs.filterDateRange1h
        case .oneDay: AccessibilityID.Logs.filterDateRange1d
        case .all: AccessibilityID.Logs.filterDateRangeAll
        }
    }
}
