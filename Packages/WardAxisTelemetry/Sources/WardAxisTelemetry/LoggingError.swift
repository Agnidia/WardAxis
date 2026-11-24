//
//  LoggingError.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Error types for logging operations. Non-fatal; system degrades to console-only.
public enum LoggingError: Error {
    /// Log file could not be created (permissions or invalid path).
    case fileCreationFailed(URL)
    /// File write operation failed.
    case fileWriteFailed(Error)
    /// Invalid configuration (e.g., file logging without valid URL).
    case invalidConfiguration
}
