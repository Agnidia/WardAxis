//
//  LogProtocol.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Standard logging contract used for DI and testing.
///
/// Concrete implementation: `Log`. Four levels (`debug`, `info`, `warning`,
/// `error`) plus an `isEnabled` gate for skipping expensive formatting.
public protocol LogProtocol: Sendable {
    /// Logs a debug-level message.
    ///
    /// - Parameters:
    ///   - message: The debug message to log.
    ///   - privacy: Whether the message may appear in persisted logs as is.
    func debug(_ message: String, privacy: Log.Privacy)
    
    /// Logs an informational message.
    ///
    /// - Parameters:
    ///   - message: The informational message to log.
    ///   - privacy: Whether the message may appear in persisted logs as is.
    func info(_ message: String, privacy: Log.Privacy)
    
    /// Logs a warning message.
    ///
    /// - Parameters:
    ///   - message: The warning message to log.
    ///   - privacy: Whether the message may appear in persisted logs as is.
    func warning(_ message: String, privacy: Log.Privacy)
    
    /// Logs an error message.
    ///
    /// - Parameters:
    ///   - message: The error message to log.
    ///   - privacy: Whether the message may appear in persisted logs as is.
    func error(_ message: String, privacy: Log.Privacy)
    
    /// Guard expensive log argument construction:
    /// ```swift
    /// if logger.isEnabled { logger.debug("\(computeExpensiveDebugInfo())") }
    /// ```
    var isEnabled: Bool { get }
}

/// Messages without an explicit label are private: an interpolated value
/// (hostname, path, identifier) must never reach a persisted log by omission.
extension LogProtocol {
    public func debug(_ message: String) {
        debug(message, privacy: .private)
    }

    public func info(_ message: String) {
        info(message, privacy: .private)
    }

    public func warning(_ message: String) {
        warning(message, privacy: .private)
    }

    public func error(_ message: String) {
        error(message, privacy: .private)
    }
}
