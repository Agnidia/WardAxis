//
//  MockLogReaderService.swift
//
//  Created on 07.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisTelemetry

/// Actor-isolated mock implementation of ``LogReaderServiceProtocol`` shared by
/// previews and unit tests.
///
/// Lives in the app target (not the test target) so SwiftUI previews —
/// which build against the app target — can inject deterministic log entries
/// without depending on the on-device log file.
actor MockLogReaderService: LogReaderServiceProtocol {
    enum Scenario: Sendable {
        case empty
        case sampleEntries
        case failure(LogReaderError)
    }
    
    private var scenario: Scenario
    private(set) var lastExportedEntries: [LogEntry]?
    private(set) var exportCallCount: Int = 0
    private(set) var clearCallCount: Int = 0
    private var wasCleared: Bool = false
    
    init(scenario: Scenario = .sampleEntries) {
        self.scenario = scenario
    }
    
    func loadEntries() async throws -> [LogEntry] {
        if wasCleared {
            return []
        }
        switch scenario {
        case .empty:
            return []
        case .sampleEntries:
            return Self.makeSampleEntries()
        case .failure(let error):
            throw error
        }
    }
    
    func clearEntries() async throws {
        clearCallCount += 1
        wasCleared = true
    }
    
    func exportEntries(_ entries: [LogEntry]) async throws -> URL {
        lastExportedEntries = entries
        exportCallCount += 1
        let filename = "mock-export-\(UUID().uuidString).txt"
        let url = FileManager.default.temporaryDirectory.appending(path: filename)
        let body = entries.map(\.rawLine).joined(separator: "\n").appending("\n")
        do {
            try body.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw LogReaderError.writeFailed(underlying: String(describing: error))
        }
        return url
    }
    
    private static func makeSampleEntries() -> [LogEntry] {
        let baseDate = Date()
        return [
            makeEntry(category: .application, level: .info, message: "App started", offset: 0, base: baseDate),
            makeEntry(category: .ui, level: .debug, message: "Tab switched", offset: 1, base: baseDate),
            makeEntry(category: .management, level: .warning, message: "Slow response", offset: 2, base: baseDate),
            makeEntry(category: .storage, level: .error, message: "Query failed", offset: 3, base: baseDate),
            LogEntry(
                id: UUID(),
                kind: .raw("This line did not match the canonical grammar"),
                rawLine: "This line did not match the canonical grammar"
            )
        ]
    }
    
    private static func makeEntry(
        category: Log.Category,
        level: Log.Level,
        message: String,
        offset: TimeInterval,
        base: Date
    ) -> LogEntry {
        let timestamp = base.addingTimeInterval(offset)
        let parsed = LogEntry.Parsed(
            timestamp: timestamp,
            level: level,
            category: category,
            message: message,
            info: nil
        )
        return LogEntry(
            id: UUID(),
            kind: .parsed(parsed),
            rawLine: "[\(category.rawValue)] [\(Log.Level.name(level))] \(message)"
        )
    }
}
