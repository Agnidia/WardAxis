//
//  LogReaderService.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisTelemetry

/// `actor` implementation of `LogReaderServiceProtocol`.
///
/// Concurrency rationale:
/// - Holds long-lived configuration (`fileURL`, `parser`, thresholds).
/// - Serialises concurrent `loadEntries` callers automatically.
/// - File I/O runs on the actor's executor — never the main actor.
actor LogReaderService: LogReaderServiceProtocol {
    private let fileURL: URL
    private let parser: LogEntryParser
    private let maximumReadBytes: Int
    private let writer: FileLogHandler?
    private let usesLiveWriter: Bool
    private let maxStreamedEntries: Int
    private let now: @Sendable () -> Date
    
    /// - Parameters:
    ///   - fileURL: Absolute URL of the log file. Defaults to `Log.logFileUrl`.
    ///   - parser: Pure parser. Defaults to a fresh `LogEntryParser`.
    ///   - maximumReadBytes: Maximum tail bytes read before parsing.
    ///   - maxStreamedEntries: Maximum entries returned for large files.
    ///   - now: Clock injection for filename generation in tests.
    init(
        fileURL: URL? = nil,
        parser: LogEntryParser = LogEntryParser(),
        maximumReadBytes: Int = LogFileLimits.retainedBytes,
        writer: FileLogHandler? = nil,
        maxStreamedEntries: Int = LogFileLimits.maximumStreamedEntries,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileURL = fileURL ?? Log.logFileUrl
        self.writer = writer
        usesLiveWriter = fileURL == nil
        self.parser = parser
        self.maximumReadBytes = max(1, min(maximumReadBytes, LogFileLimits.retainedBytes))
        self.maxStreamedEntries = max(1, min(maxStreamedEntries, LogFileLimits.maximumStreamedEntries))
        self.now = now
    }
    
    func loadEntries() async throws -> [LogEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            throw LogReaderError.permissionDenied(fileURL)
        }
        
        let content: String
        do {
            let data = try LogFileTail.read(from: fileURL, maximumBytes: maximumReadBytes)
            guard let text = String(data: data, encoding: .utf8) else {
                throw LogReaderError.readFailed(underlying: "Invalid log encoding")
            }
            content = text
        } catch {
            throw LogReaderError.read(error)
        }
        
        let entries = parser.parseAll(content)
        return Array(entries.suffix(maxStreamedEntries))
    }
    
    func exportEntries(_ entries: [LogEntry]) async throws -> URL {
        let filename = Self.exportFilename(for: now())
        let url = FileManager.default.temporaryDirectory.appending(path: filename)
        
        let body = entries.exportText
        
        do {
            try body.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw LogReaderError.write(error)
        }
        return url
    }
    
    func clearEntries() async throws {
        if let writer = writer ?? (usesLiveWriter ? FileLogHandler.shared : nil) {
            do {
                try await writer.clear()
            } catch {
                throw LogReaderError.writeFailed(underlying: "Log deletion failed")
            }
            return
        }
        
        // Fallback path — the shared writer is unavailable (no bundle id).
        // Atomic replace is acceptable here precisely because there is no
        // long-lived handle to orphan.
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try Data().write(to: fileURL, options: .atomic)
        } catch {
            throw LogReaderError.write(error)
        }
    }
    
    // MARK: - Filename helper
    
    private static let exportFilenameFormatter = LogDateFormat.posixFormatter("yyyyMMdd-HHmmss")
    
    /// Produces the export filename for a given clock instant.
    /// Format: `wardaxis-logs-YYYYMMDD-HHmmss.txt` (device-local timezone).
    /// Exposed `internal static` so tests can verify pattern compliance.
    static func exportFilename(for date: Date) -> String {
        "wardaxis-logs-\(exportFilenameFormatter.string(from: date)).txt"
    }
}
