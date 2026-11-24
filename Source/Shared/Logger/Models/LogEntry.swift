//
//  LogEntry.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisTelemetry

/// A single entry parsed from the persisted application log file.
///
/// Two flavours exist:
/// - `.parsed(Parsed)` — structured fields recovered from the canonical
///   `[ts] [category] [level] message [| info]` format produced by
///   `Log.formatFileEntry`.
/// - `.raw(String)` — line that did not match the expected grammar; the
///   original text is preserved verbatim so diagnostics tooling never drops
///   information silently.
///
/// `LogEntry` is `Sendable` and crosses the actor boundary from
/// `LogReaderService` (off-main) to `LogsViewerViewModel` (`@MainActor`).
struct LogEntry: Sendable, Identifiable, Hashable {
    /// Stable identity for `List` / `ForEach`. Generated once per parse —
    /// IDs are not stable across reloads of the same file.
    let id: UUID

    /// Either a parsed structured entry or a verbatim raw line.
    let kind: Kind

    /// Always the original line text, preserved for export fidelity.
    let rawLine: String

    /// Discriminated union over parsed and raw entries.
    enum Kind: Sendable, Hashable {
        /// Successfully parsed entry with structured fields.
        case parsed(Parsed)

        /// Verbatim line that did not match the canonical grammar.
        case raw(String)
    }

    /// Structured fields extracted from a canonical log line.
    struct Parsed: Sendable, Hashable {
        /// Optional — `nil` when the source line had no timestamp segment
        /// (`Configuration.dateDisplayStyle == .none`) or when the timestamp
        /// failed to parse.
        let timestamp: Date?

        /// A single bit of `Log.Level` (`.error` / `.warning` / `.info` / `.debug`).
        /// File writes always pass single-bit levels, so composite values are
        /// not expected here.
        let level: Log.Level

        /// Source category badge enum. Falls back to `.application` only when
        /// the parsed token is a known category — unknown tokens trigger the
        /// `.raw` path, never a placeholder category.
        let category: Log.Category

        /// Message body with the optional info segment stripped.
        let message: String

        /// Raw info segment (`key=value, key=value`) when present, else `nil`.
        let info: String?
    }

    /// Convenience accessor — `nil` for `.raw` kind.
    var parsed: Parsed? {
        if case let .parsed(value) = kind { return value }
        return nil
    }
}
