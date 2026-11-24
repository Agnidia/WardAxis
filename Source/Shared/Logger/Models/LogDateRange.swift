//
//  LogDateRange.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisTelemetry

/// Time-window options for the Logs Viewer date filter.
///
/// Single-select alongside `Log.Level`. `.all` is the "no time filter"
/// escape hatch and the default selection. The window is anchored to
/// "now-at-filter-time" — entries do not move while the user reads them.
enum LogDateRange: String, CaseIterable, Sendable {
    case tenMinutes
    case thirtyMinutes
    case oneHour
    case oneDay
    case all
    
    /// Seconds back from `now` that pass the filter. `nil` for `.all`
    /// (no bound).
    var lookback: TimeInterval? {
        switch self {
        case .tenMinutes: 600
        case .thirtyMinutes: 1800
        case .oneHour: 3600
        case .oneDay: 86_400
        case .all: nil
        }
    }
    
    /// Lossless predicate. `nil` timestamps and `.all` always pass —
    /// matches the policy applied to `.raw` entries by the view model.
    func contains(_ timestamp: Date?, now: Date = Date()) -> Bool {
        guard let lookback, let timestamp else { return true }
        return now.timeIntervalSince(timestamp) <= lookback
    }
}
