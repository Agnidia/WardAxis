//
//  LogReaderServiceTests.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
@testable import WardAxis

@Suite("LogReaderService")
struct LogReaderServiceTests {
    // MARK: - Helpers
    
    private func makeTempFile(content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "LogReaderServiceTests-\(UUID().uuidString).log")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    private func makeService(fileURL: URL, maxStreamedEntries: Int = 5000) -> LogReaderService {
        LogReaderService(
            fileURL: fileURL,
            parser: LogEntryParser(),
            maximumReadBytes: 2 * 1024 * 1024,
            maxStreamedEntries: maxStreamedEntries
        )
    }
    
    // MARK: - loadEntries
    
    @Test
    func `empty file returns empty array`() async throws {
        let url = try makeTempFile(content: "")
        defer { try? FileManager.default.removeItem(at: url) }
        
        let service = makeService(fileURL: url)
        let entries = try await service.loadEntries()
        #expect(entries.isEmpty)
    }
    
    @Test
    func `missing file returns empty array without throwing`() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "does-not-exist-\(UUID().uuidString).log")
        
        let service = makeService(fileURL: url)
        let entries = try await service.loadEntries()
        #expect(entries.isEmpty)
    }
    
    @Test
    func `small file returns all parsed entries in file order`() async throws {
        let lines = (1...10).map { "[application] [info] Message \($0)" }
        let content = lines.joined(separator: "\n")
        let url = try makeTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }
        
        let service = makeService(fileURL: url)
        let entries = try await service.loadEntries()
        #expect(entries.count == 10)
    }
    
    @Test
    func `large file above streaming threshold is capped at maxStreamedEntries`() async throws {
        let singleLine = "[application] [info] " + String(repeating: "x", count: 200)
        let lineCount = 25_000
        let content = (1...lineCount).map { _ in singleLine }.joined(separator: "\n")
        let url = try makeTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }
        
        let cap = 5000
        let service = makeService(fileURL: url, maxStreamedEntries: cap)
        let entries = try await service.loadEntries()
        
        #expect(entries.count <= cap)
        #expect(!entries.isEmpty)
    }
    
    @Test
    func `large file result contains the LAST entries (suffix), not the first`() async throws {
        let singleLine = "[application] [info] " + String(repeating: "y", count: 200)
        let lineCount = 25_000
        let lines = (1...lineCount - 1).map { _ in singleLine } + ["[ui] [error] Last line marker"]
        let content = lines.joined(separator: "\n")
        let url = try makeTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }
        
        let cap = 5000
        let service = makeService(fileURL: url, maxStreamedEntries: cap)
        let entries = try await service.loadEntries()
        
        #expect(entries.last?.rawLine == "[ui] [error] Last line marker")
    }
    
    // MARK: - exportEntries
    
    @Test
    func `exportEntries writes a file at the returned URL containing the rawLines of provided entries`() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "empty-\(UUID().uuidString).log")
        let service = makeService(fileURL: url)
        
        let entries: [LogEntry] = [
            LogEntry(id: UUID(), kind: .raw("line one"), rawLine: "line one"),
            LogEntry(id: UUID(), kind: .raw("line two"), rawLine: "line two")
        ]
        
        let exportURL = try await service.exportEntries(entries)
        defer { try? FileManager.default.removeItem(at: exportURL) }
        
        let written = try String(contentsOf: exportURL, encoding: .utf8)
        #expect(written.contains("line one"))
        #expect(written.contains("line two"))
    }
    
    @Test
    func `exportEntries filename matches wardaxis-logs-YYYYMMDD-HHmmss.txt pattern`() async throws {
        let fixedDate = Date(timeIntervalSince1970: 1_730_217_600)
        
        let url = FileManager.default.temporaryDirectory
            .appending(path: "empty-\(UUID().uuidString).log")
        
        let service = LogReaderService(
            fileURL: url,
            parser: LogEntryParser(),
            maximumReadBytes: 2 * 1024 * 1024,
            maxStreamedEntries: 5000,
            now: { fixedDate }
        )
        
        let entries: [LogEntry] = [
            LogEntry(id: UUID(), kind: .raw("test entry"), rawLine: "test entry")
        ]
        
        let exportURL = try await service.exportEntries(entries)
        defer { try? FileManager.default.removeItem(at: exportURL) }
        
        let filename = exportURL.lastPathComponent
        #expect(filename.hasPrefix("wardaxis-logs-"))
        #expect(filename.hasSuffix(".txt"))
        
        let generatedFilename = LogReaderService.exportFilename(for: fixedDate)
        #expect(generatedFilename.hasPrefix("wardaxis-logs-"))
        #expect(generatedFilename.hasSuffix(".txt"))
        let middle = generatedFilename
            .dropFirst("wardaxis-logs-".count)
            .dropLast(".txt".count)
        #expect(middle.count == 15)
        let prefixIsAllDigits = middle.prefix(8).allSatisfy(\.isNumber)
        let suffixIsAllDigits = middle.suffix(6).allSatisfy(\.isNumber)
        #expect(prefixIsAllDigits)
        #expect(middle.dropFirst(8).first == "-")
        #expect(suffixIsAllDigits)
    }
    
    @Test
    func `exportEntries round-trip: loaded entries written then re-read match original raw lines`() async throws {
        let rawLines = [
            "[application] [info] Line A",
            "[ui] [debug] Line B",
            "raw unstructured line"
        ]
        let content = rawLines.joined(separator: "\n")
        let sourceURL = try makeTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        
        let service = makeService(fileURL: sourceURL)
        let loadedEntries = try await service.loadEntries()
        
        let exportURL = try await service.exportEntries(loadedEntries)
        defer { try? FileManager.default.removeItem(at: exportURL) }
        
        let exported = try String(contentsOf: exportURL, encoding: .utf8)
        for line in rawLines {
            #expect(exported.contains(line))
        }
    }
    
    @Test
    func `A bounded read skips an oversized entry and keeps the latest entry`() async throws {
        let url = try makeTempFile(content: "[ui] [info] " + String(repeating: "x", count: 100_000) + "\n[ui] [error] latest\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let service = LogReaderService(fileURL: url, maximumReadBytes: 128)
        let entries = try await service.loadEntries()
        #expect(entries.map(\.rawLine) == ["[ui] [error] latest"])
    }
    
    @Test
    func `The parser drops oversized multiline entries without dropping the next header`() async throws {
        let url = try makeTempFile(content: "[ui] [info] " + String(repeating: "x\n", count: 10_000) + "[ui] [error] latest\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let entries = try await makeService(fileURL: url).loadEntries()
        #expect(entries.map(\.rawLine) == ["[ui] [error] latest"])
    }
    
    @Test
    func `An oversized new entry does not discard valid adjacent entries`() async throws {
        let url = try makeTempFile(content: "[ui] [info] before\n[ui] [info] " + String(repeating: "x", count: 20_000) + "\n[ui] [info] after\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let entries = try await makeService(fileURL: url).loadEntries()
        #expect(entries.map(\.rawLine) == ["[ui] [info] before", "[ui] [info] after"])
    }
}
