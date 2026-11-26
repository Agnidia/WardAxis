//
//  CapturingLogHandler.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Logging
import NIOConcurrencyHelpers

/// One captured log line, with handler and call-site metadata merged.
struct CapturedLogRecord: Sendable {
    let level: Logger.Level
    let message: String
    let metadata: Logger.Metadata
    
    /// The message and every metadata key and value, for "never appears" assertions.
    var renderedText: String {
        let pairs = metadata.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        return ([message] + pairs).joined(separator: " ")
    }
}

/// Thread-safe store shared by every copy of a ``CapturingLogHandler``.
final class LogCapture: Sendable {
    private let storage: NIOLockedValueBox<[CapturedLogRecord]> = NIOLockedValueBox([])
    
    var records: [CapturedLogRecord] {
        storage.withLockedValue { $0 }
    }
    
    func append(_ record: CapturedLogRecord) {
        storage.withLockedValue { $0.append(record) }
    }
    
    /// A logger that writes here. Injected directly, so tests never touch
    /// the process-wide `LoggingSystem.bootstrap`.
    func makeLogger(label: String = "test", level: Logger.Level = .trace) -> Logger {
        var logger = Logger(label: label) { _ in CapturingLogHandler(capture: self) }
        logger.logLevel = level
        return logger
    }
}

/// A `LogHandler` that records log events in memory.
struct CapturingLogHandler: LogHandler {
    let capture: LogCapture
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .trace
    
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
    
    func log(event: LogEvent) {
        let merged = metadata.merging(event.metadata ?? [:]) { _, callSite in callSite }
        capture.append(CapturedLogRecord(level: event.level, message: event.message.description, metadata: merged))
    }
}
