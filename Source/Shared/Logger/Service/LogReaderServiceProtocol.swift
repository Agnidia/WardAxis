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
    /// Loads all entries from the active log file. Newest entry is **last**
    /// in the returned array — the view layer is responsible for reversing
    /// for display, keeping service semantics file-order and lossless.
    ///
    /// - Throws: `LogReaderError`.
    /// - Returns: All parsed entries (or up to the streaming cap for very
    ///   large files; see `LogReaderService.maxStreamedEntries`).
    func loadEntries() async throws -> [LogEntry]

    /// Serialises `entries` back to one-line-per-entry text and writes to
    /// `FileManager.default.temporaryDirectory` with filename
    /// `wardaxis-logs-YYYYMMDD-HHmmss.txt` (device-local timezone).
    ///
    /// - Returns: URL of the written temp file, suitable for `ShareLink`.
    /// - Throws: `LogReaderError.writeFailed` on I/O failure.
    func exportEntries(_ entries: [LogEntry]) async throws -> URL

    /// Truncates the persisted log file to zero bytes. Done in-place via
    /// the live `FileLogHandler` so the long-lived writer is not orphaned —
    /// callers continue to log normally; entries flushed after this call
    /// land into the empty file.
    ///
    /// - Throws: `LogReaderError.writeFailed` on I/O failure.
    func clearEntries() async throws
}
