//
//  LogEntryParser.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisTelemetry

/// Pure-function parser that turns persisted log file lines into `LogEntry`
/// values.
///
/// The parser mirrors `Log.formatFileEntry`:
///
/// ```
/// [<timestamp>] [<categoryRaw>] [<levelName>] <message>[ | <key>=<value>, ...]
/// ```
///
/// The timestamp segment is optional. Lines that fail to match the canonical
/// grammar — unknown category, unknown level, regex miss — are mapped to
/// `LogEntry(.raw(line))`. The parser **never throws**.
///
/// `LogEntryParser` is `Sendable`, has no I/O, no global state, and is
/// trivially unit-testable.
struct LogEntryParser: Sendable {
    /// Canonical grammar for a parsed line.
    /// Capture groups:
    ///   1. optional timestamp (without surrounding `[]`)
    ///   2. category raw value
    ///   3. level name token
    ///   4. message body
    ///   5. optional info segment after ` | `
    private static let pattern: String = {
        let timestamp = #"(?:\[([^\]]+)\] )?"#
        let category = #"\[([^\]]+)\]"#
        let level = #"\[([^\]]+)\]"#
        let body = #" (.*?)"#
        let info = #"(?: \| (.*))?"#
        return "^\(timestamp)\(category) \(level)\(body)\(info)$"
    }()
    
    private static let regex: NSRegularExpression? = try? NSRegularExpression(
        pattern: pattern,
        options: [.dotMatchesLineSeparators]
    )
    
    /// Header pattern used to detect the start of a new entry when merging
    /// continuation lines (multi-line log messages such as JSON dumps).
    /// Matches `[ts] [cat] [lvl]` or `[cat] [lvl]` at line start.
    private static let headerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?:\[[^\]]+\] )?\[[^\]]+\] \[[^\]]+\] "#,
        options: []
    )
    
    /// Time-of-day formatter (no date component). Output dates land on
    /// `DateFormatter`'s reference epoch — see `parseTimestamp(_:now:)` for
    /// the reanchor step that pins them to today.
    private static let timeOnlyFormatter = LogDateFormat.posixFormatter(LogDateFormat.timeWithMilliseconds)
    
    /// Date+time formatters used when the file logger emits a date-bearing
    /// timestamp (`.short` or `.full` configuration). Output dates already
    /// carry year/month/day so they need no reanchoring.
    private static let dateBearingFormatters: [DateFormatter] = {
        let shortFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter
        }()
        
        let fullFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .full
            return formatter
        }()
        
        return [shortFormatter, fullFormatter]
    }()
    
    init() {}
    
    /// Parses a single line. Never throws; unrecognised lines become `.raw`.
    func parse(_ line: String) -> LogEntry {
        guard !line.isEmpty, let regex = Self.regex else {
            return LogEntry(id: UUID(), kind: .raw(line), rawLine: line)
        }
        
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else {
            return LogEntry(id: UUID(), kind: .raw(line), rawLine: line)
        }
        
        let timestampText = capture(match, at: 1, in: line)
        let categoryText = capture(match, at: 2, in: line) ?? ""
        let levelText = capture(match, at: 3, in: line) ?? ""
        let messageText = capture(match, at: 4, in: line) ?? ""
        let infoText = capture(match, at: 5, in: line)
        
        guard let category = Log.Category(rawValue: categoryText), let level = Self.level(named: levelText) else {
            return LogEntry(id: UUID(), kind: .raw(line), rawLine: line)
        }
        
        let timestamp = timestampText.flatMap { Self.parseTimestamp($0) }
        
        let parsed = LogEntry.Parsed(
            timestamp: timestamp,
            level: level,
            category: category,
            message: messageText,
            info: infoText
        )
        
        return LogEntry(id: UUID(), kind: .parsed(parsed), rawLine: line)
    }
    
    /// Splits a multi-line source on `\n` and reassembles entries that span
    /// multiple physical lines (e.g. messages containing pretty-printed JSON).
    ///
    /// A line is treated as the start of a new entry when it matches the
    /// canonical `[ts] [cat] [lvl] ` header. Otherwise it is appended to the
    /// previous entry as a continuation, preserving the original `\n`. Order
    /// is preserved (file order — caller may reverse).
    func parseAll(_ source: String) -> [LogEntry] {
        guard !source.isEmpty else { return [] }
        
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: true)
        var merged: [String] = []
        var current = ""
        var currentBytes = 0
        var oversized = false
        for line in rawLines {
            let header = String(decoding: line.utf8.prefix(512), as: UTF8.self)
            if Self.isHeaderLine(header) {
                if !current.isEmpty, !oversized {
                    merged.append(current)
                }
                current = ""
                currentBytes = 0
                oversized = false
            }
            let addedBytes = line.utf8.count + (current.isEmpty ? 0 : 1)
            guard !oversized, currentBytes + addedBytes <= LogFileLimits.maximumEntryBytes else {
                oversized = true
                current = ""
                continue
            }
            if !current.isEmpty {
                current.append("\n")
            }
            current.append(contentsOf: line)
            currentBytes += addedBytes
        }
        if !current.isEmpty, !oversized {
            merged.append(current)
        }
        
        return merged.map(parse)
    }
    
    /// Returns `true` when `line` begins with the canonical entry header
    /// (`[<ts>] [<cat>] [<lvl>] ` or `[<cat>] [<lvl>] `).
    private static func isHeaderLine(_ line: String) -> Bool {
        guard let headerRegex else { return line.hasPrefix("[") }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return headerRegex.firstMatch(in: line, options: [], range: range) != nil
    }
    
    // MARK: - Helpers
    
    private func capture(_ match: NSTextCheckingResult, at index: Int, in line: String) -> String? {
        guard index < match.numberOfRanges else { return nil }
        let nsRange = match.range(at: index)
        guard nsRange.location != NSNotFound, let swiftRange = Range(nsRange, in: line) else {
            return nil
        }
        return String(line[swiftRange])
    }
    
    /// Maps the textual level token (as produced by `Log.Level.name(_:)`) to
    /// the corresponding single-bit `Log.Level`. Composite tokens fall through.
    private static func level(named name: String) -> Log.Level? {
        switch name {
        case "error": .error
        case "warning": .warning
        case "info": .info
        case "debug": .debug
        default: nil
        }
    }
    
    /// Recovers a `Date` from a textual timestamp.
    ///
    /// Date-bearing formats (`.short`, `.full`) are tried first and returned
    /// as-is. The time-of-day format produces a date on `DateFormatter`'s
    /// reference epoch — which would mark every entry as decades old and
    /// silently break the date-range filter — so we reanchor it to today
    /// (or yesterday for cross-midnight entries).
    static func parseTimestamp(_ text: String, now: Date = Date()) -> Date? {
        for formatter in dateBearingFormatters {
            if let date = formatter.date(from: text) {
                return date
            }
        }
        if let timeOfDay = timeOnlyFormatter.date(from: text) {
            return reanchorTimeOfDay(timeOfDay, now: now)
        }
        return nil
    }
    
    /// Combines the time-of-day from `timeOfDay` with today's date in the
    /// current calendar. If the resulting instant is in the future relative
    /// to `now` (entry written before midnight, viewed after), step one
    /// day back so the timestamp remains in the past.
    private static func reanchorTimeOfDay(_ timeOfDay: Date, now: Date) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents(
            [.hour, .minute, .second, .nanosecond],
            from: timeOfDay
        )
        var anchored = calendar.dateComponents([.year, .month, .day], from: now)
        anchored.hour = timeComponents.hour
        anchored.minute = timeComponents.minute
        anchored.second = timeComponents.second
        anchored.nanosecond = timeComponents.nanosecond
        guard let candidate = calendar.date(from: anchored) else { return timeOfDay }
        if candidate > now {
            return calendar.date(byAdding: .day, value: -1, to: candidate) ?? candidate
        }
        return candidate
    }
}
