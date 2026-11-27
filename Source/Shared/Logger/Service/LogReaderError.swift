//
//  LogReaderError.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Failure modes for `LogReaderService`. `Equatable` for tests; the underlying
/// `Error` (if any) is collapsed to `String` to preserve `Equatable`.
enum LogReaderError: Error, Equatable, Sendable {
    /// The log file does not exist at the expected URL (fresh install).
    case fileMissing(URL)
    
    /// Sandbox / file-protection denied access.
    case permissionDenied(URL)
    
    /// Disk read failed for reasons other than missing/denied.
    case readFailed(underlying: String)
    
    /// Export write to the temporary directory failed.
    case writeFailed(underlying: String)
    
    static func read(_ error: any Error) -> LogReaderError {
        .read(error)
    }
    
    static func write(_ error: any Error) -> LogReaderError {
        .write(error)
    }
}

extension [LogEntry] {
    /// The export file body: one raw line per entry, newline-terminated, so a
    /// shared file reads the same as the log it came from.
    var exportText: String {
        map(\.rawLine).joined(separator: "\n").appending("\n")
    }
}
