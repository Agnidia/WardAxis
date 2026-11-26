//
//  FileLogging.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import os
import Synchronization

public enum LogFileLimits {
    public static let maximumFileBytes = 4 * 1024 * 1024
    public static let retainedBytes = 2 * 1024 * 1024
    public static let maximumEntryBytes = 16 * 1024
    static let maximumPendingEntries = 64
}

/// Reads at most `maximumBytes`, discarding a partial first line after seeking.
public enum LogFileTail {
    public static func read(from url: URL, maximumBytes: Int) throws -> Data {
        precondition(maximumBytes > 0)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let end = try handle.seekToEnd()
        let offset = end > UInt64(maximumBytes) ? end - UInt64(maximumBytes) : 0
        try handle.seek(toOffset: offset)
        let data = try handle.read(upToCount: maximumBytes) ?? Data()
        guard offset > 0 else { return data }
        guard let newline = data.firstIndex(of: 10) else { return Data() }
        return Data(data[data.index(after: newline)...])
    }
}

struct BoundedLogFile {
    private let url: URL
    private let handle: FileHandle
    private var byteCount: UInt64
    private let maximumBytes: Int
    private let retainedBytes: Int
    
    init(url: URL, maximumBytes: Int, retainedBytes: Int) throws {
        precondition(retainedBytes > 0 && maximumBytes > retainedBytes)
        self.url = url
        self.maximumBytes = maximumBytes
        self.retainedBytes = retainedBytes
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                throw LoggingError.fileCreationFailed(url)
            }
        }
        handle = try FileHandle(forWritingTo: url)
        byteCount = try handle.seekToEnd()
        if byteCount > UInt64(maximumBytes) {
            try rotate()
        }
    }
    
    mutating func append(_ data: Data) throws {
        guard data.count <= maximumBytes else { throw LoggingError.invalidConfiguration }
        byteCount = try handle.seekToEnd()
        if byteCount + UInt64(data.count) > UInt64(maximumBytes) {
            try rotate(retainingAtMost: maximumBytes - data.count)
        }
        try handle.write(contentsOf: data)
        byteCount += UInt64(data.count)
    }
    
    mutating func clear() throws {
        try handle.truncate(atOffset: 0)
        try handle.seek(toOffset: 0)
        byteCount = 0
    }
    
    func close() throws {
        try handle.close()
    }
    
    private mutating func rotate(retainingAtMost limit: Int? = nil) throws {
        let keep = min(retainedBytes, limit ?? retainedBytes)
        let tail = keep > 0 ? try LogFileTail.read(from: url, maximumBytes: keep) : Data()
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: tail)
        try handle.truncate(atOffset: UInt64(tail.count))
        byteCount = try handle.seekToEnd()
    }
}

/// Owns rotation, writes and deletion on one executor (ADR-FileLogHandler-001).
public actor FileLogHandler {
    public static let shared: FileLogHandler? = {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let directory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(bundleID, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try? FileLogHandler(label: "FileLogHandler", localFile: directory.appending(path: "log.log"))
    }()
    
    private struct Pending {
        var entries: [Data] = []
        var scheduled = false
    }
    
    private let pending = Mutex(Pending())
    private var file: BoundedLogFile
    private let logger: os.Logger
    
    public init(label: String, localFile url: URL) throws {
        logger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "WardAxis", category: label)
        file = try BoundedLogFile(url: url, maximumBytes: LogFileLimits.maximumFileBytes, retainedBytes: LogFileLimits.retainedBytes)
    }
    
    public nonisolated func log(entry: String) {
        let data = Self.boundedEntry(entry)
        let schedule = pending.withLock { state in
            guard state.entries.count < LogFileLimits.maximumPendingEntries else { return false }
            state.entries.append(data)
            guard !state.scheduled else { return false }
            state.scheduled = true
            return true
        }
        if schedule {
            Task { await drain() }
        }
    }
    
    /// Pending entries are discarded so an earlier log cannot reappear after deletion.
    public func clear() throws {
        pending.withLock { $0.entries.removeAll(keepingCapacity: true) }
        try file.clear()
    }
    
    func drain() {
        let entries = pending.withLock { state in
            defer { state.entries.removeAll(keepingCapacity: true) }
            return state.entries
        }
        for entry in entries {
            do {
                try file.append(entry)
            } catch {
                logger.error("Log file write failed")
            }
        }
        let more = pending.withLock { state in
            if state.entries.isEmpty {
                state.scheduled = false
                return false
            }
            return true
        }
        if more {
            Task { drain() }
        }
    }
    
    static func boundedEntry(_ entry: String) -> Data {
        let suffix = Data(" [truncated]\n".utf8)
        let limit = LogFileLimits.maximumEntryBytes
        if entry.utf8.count >= limit {
            var bytes = Data(entry.utf8.prefix(limit - suffix.count))
            // A cut UTF-8 scalar must not make the whole log unreadable.
            while String(data: bytes, encoding: .utf8) == nil {
                bytes.removeLast()
            }
            bytes.append(suffix)
            return bytes
        }
        var bytes = Data(entry.utf8)
        if bytes.last != 10 {
            bytes.append(10)
        }
        return bytes
    }
}
