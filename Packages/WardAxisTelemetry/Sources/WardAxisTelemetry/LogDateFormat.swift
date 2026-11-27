//
//  LogDateFormat.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Shared date format constants used across the Logger module.
public enum LogDateFormat {
    /// Millisecond-precision time format: `HH:mm:ss.SSS`.
    public static let timeWithMilliseconds = "HH:mm:ss.SSS"
    
    /// A formatter for a fixed `format` in the device time zone. The POSIX
    /// locale keeps the user's calendar and 12/24-hour setting from changing
    /// what the log writer emits and what the log reader parses.
    public static func posixFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }
}
