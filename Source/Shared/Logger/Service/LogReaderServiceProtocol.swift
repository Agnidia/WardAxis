//
//  LogReaderServiceProtocol.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Reads the persisted log file produced by `FileLogHandler` and exposes
/// parsed `LogEntry` arrays plus an export helper.
///
/// The protocol is `Sendable` and **not** `@MainActor`; conforming types run
/// disk I/O off the main actor. View models (`@MainActor`) call into this
/// service via `await`.
protocol LogReaderServiceProtocol: Sendable {
    /// Returns recent entries in file order, within the byte, entry-size and count limits.
    /// A cut first line and oversize entries are omitted.
    func loadEntries() async throws -> [LogEntry]
    
    /// Serialises `entries` back to one-line-per-entry text and writes to
    /// `FileManager.default.temporaryDirectory` with filename
    /// `wardaxis-logs-YYYYMMDD-HHmmss.txt` (device-local timezone).
    ///
    /// - Returns: URL of the written temp file, suitable for `ShareLink`.
    /// - Throws: `LogReaderError.writeFailed` on I/O failure.
    func exportEntries(_ entries: [LogEntry]) async throws -> URL
    
    /// Discards pending entries and truncates the live file; deletion failures throw.
    func clearEntries() async throws
}
