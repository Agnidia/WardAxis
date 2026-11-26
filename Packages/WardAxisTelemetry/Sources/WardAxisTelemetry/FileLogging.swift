//
//  FileLogging.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import os

private let internalLog = os.Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.agnidia.wardaxis",
    category: "FileLogHandler"
)

/// `TextOutputStream` that appends to a log file and triggers async rotation.
public struct FileHandlerOutputStream: TextOutputStream {
    private let fileHandle: FileHandle
    public let encoding: String.Encoding
    
    /// Opens (or creates) the log file at `url` and seeks to its end. Rotation
    /// to the last 100,000 lines runs asynchronously so init never blocks.
    ///
    /// - Throws: `LoggingError.fileCreationFailed` if file creation fails.
    public init(localFile url: URL, encoding: String.Encoding = .utf8) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil) else {
                throw LoggingError.fileCreationFailed(url)
            }
        }
        
        let fileHandle = try FileHandle(forWritingTo: url)
        fileHandle.seekToEndOfFile()
        self.fileHandle = fileHandle
        self.encoding = encoding
        
        Task.detached(priority: .utility) {
            Self.keepLastLinesOfFile(from: url, writingTo: fileHandle)
        }
    }
    
    /// Appends `string` to the file; write failures are logged, never thrown,
    /// so logging cannot crash the app.
    ///
    /// - Note: `mutating` is required by `TextOutputStream`, though the
    ///         underlying `FileHandle` is a reference type.
    public mutating func write(_ string: String) {
        guard let data = string.data(using: encoding) else { return }
        
        do {
            try fileHandle.write(contentsOf: data)
        } catch {
            internalLog.error("Failed to write data: \(error.localizedDescription)")
        }
    }
    
    public func close() {
        try? fileHandle.close()
    }
    
    /// Truncates the underlying file to zero bytes and rewinds the handle.
    /// Done in-place via the live `FileHandle` so the open writer keeps
    /// targeting the same inode — atomic replace would orphan the handle
    /// and silently drop subsequent log writes.
    public func truncate() {
        do {
            try fileHandle.truncate(atOffset: 0)
            try fileHandle.seek(toOffset: 0)
        } catch {
            internalLog.error("Failed to truncate: \(error.localizedDescription)")
        }
    }
    
    /// Rotates the log by keeping only the last `lineCount` lines.
    ///
    /// Called from a background `.utility` task during init. Reads the file in
    /// full, so size stays reasonable; rewrites in-place only if needed.
    /// Uses the live `handle` (same inode) so the open writer is never orphaned.
    private static func keepLastLinesOfFile(from url: URL, writingTo handle: FileHandle, lineCount: Int = 100_000) {
        do {
            let fileContent = try String(contentsOf: url, encoding: .utf8)
            var lines = fileContent.split(separator: "\n").map(String.init)
            
            guard lines.count > lineCount else { return }
            
            lines = Array(lines.suffix(lineCount))
            let updatedContent = lines.joined(separator: "\n") + "\n"
            guard let data = updatedContent.data(using: .utf8) else { return }
            
            try handle.seek(toOffset: 0)
            try handle.write(contentsOf: data)
            try handle.truncate(atOffset: UInt64(data.count))
            handle.seekToEndOfFile()
            
            internalLog.info("Log file rotated successfully")
        } catch {
            internalLog.error("Log rotation failed: \(error.localizedDescription)")
        }
    }
}

/// Actor-isolated file log handler that serializes writes automatically.
///
/// ## Singleton Justification (ADR-FileLogHandler-001)
///
/// `FileLogHandler.shared` is the **only** justified singleton in this codebase.
/// The "no Singleton" rule from `AGENTS.md` stands for everything else.
///
/// Why process-wide is required:
/// - **File-descriptor safety**: a `FileHandle` is a kernel descriptor; multiple
///   per-instance writers would leak fds and race on the same inode.
/// - **Write ordering**: a single `actor` (one serialized executor) gives total
///   ordering for free; multiple writers do not.
/// - **In-place truncate**: `clear()` truncates the live handle. Two writers
///   cannot share that operation; one would orphan the other's seek position.
/// - **Rotation correctness**: 100,000-line rotation rewrites the same handle.
///   Per-instance writers would corrupt the file.
///
/// `Log` itself is not a singleton — each call site builds its own `Log(category:)`
/// value type. Only the file writer is shared.
public actor FileLogHandler {
    /// Shared instance created lazily; thread-safe via `static let` semantics.
    private static let _shared: FileLogHandler? = {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(bundleID, isDirectory: true)
            .appending(path: "log.log")
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return try? FileLogHandler(label: "FileLogHandler", localFile: url)
    }()
    
    public static var shared: FileLogHandler? {
        _shared
    }
    
    private var stream: TextOutputStream
    private let label: String
    
    /// - Throws: `LoggingError.fileCreationFailed` if file setup fails.
    public init(label: String, localFile url: URL) throws {
        self.label = label
        stream = try FileHandlerOutputStream(localFile: url)
    }
    
    /// Fire-and-forget entry point for callers that cannot `await`.
    /// The actor serializes writes automatically.
    public nonisolated func log(entry: String) {
        Task { await _log(entry: entry) }
    }
    
    private func _log(entry: String) {
        var output = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        if !output.hasSuffix("\n") {
            output.append("\n")
        }
        stream.write(output)
    }
    
    /// Truncates the live log file to zero bytes via the open writer.
    /// Pending writes complete before this runs (actor serialization).
    public func clear() async {
        if let outputStream = stream as? FileHandlerOutputStream {
            outputStream.truncate()
        }
    }
}
