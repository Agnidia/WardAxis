//
//  LogsViewerViewModel.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisTelemetry

/// View model for the in-app Logs viewer.
///
/// State machine:
/// - `.loading` — read in flight (initial state and during `refresh()`).
/// - `.loaded(entries)` — file read completed (entries kept in file order).
/// - `.failed(error)` — read threw.
///
/// Filter state lives on a separate property and never transitions
/// `state`; toggling chips never re-reads the file.
///
/// Derived state (`filteredEntries`, `totalEntryCount`, `filteredOutCount`,
/// `hasAnyEntries`) is **stored**, recomputed only when `state` or
/// `selectedLevels` mutates. This avoids re-running the O(N) reverse + filter
/// on every SwiftUI read at the `LogFileLimits.maximumStreamedEntries` streaming cap.
@Observable @MainActor
final class LogsViewerViewModel {
    // MARK: - Types
    
    /// Mutually exclusive load states.
    enum LoadState: Sendable {
        case loading
        case loaded(entries: [LogEntry])
        case failed(LogReaderError)
        
        /// `true` while a read is in flight.
        var isLoading: Bool {
            if case .loading = self {
                return true
            }
            return false
        }
        
        /// File-order entries when loaded, else `[]`.
        var entries: [LogEntry] {
            if case .loaded(let entries) = self {
                return entries
            }
            return []
        }
    }
    
    // MARK: - Stored state
    
    /// The four single-bit `Log.Level` values displayable in the filter bar,
    /// in canonical UI order.
    static let filterableLevels: [Log.Level] = [.error, .warning, .info, .debug]
    
    /// Date-range options displayable in the date filter bar, in canonical
    /// UI order (narrowest → widest, with `.all` as escape hatch).
    static let filterableDateRanges: [LogDateRange] = [
        .tenMinutes, .thirtyMinutes, .oneHour, .oneDay, .all
    ]
    
    /// Single source of truth for the load lifecycle.
    private(set) var state: LoadState = .loading
    
    /// Multi-select filter. Invariant: never empty.
    private(set) var selectedLevels: Set<Log.Level>
    
    /// Single-select time-window filter. `.all` = no date bound (default).
    /// Composes with `selectedLevels` by AND for `.parsed` entries.
    private(set) var selectedDateRange: LogDateRange = .all
    
    /// Newest-first entries that pass the active filters (level AND date).
    /// `.raw` entries and `.parsed` entries with `nil` timestamps are
    /// always shown (lossless UX). Recomputed only on `state`,
    /// `selectedLevels`, or `selectedDateRange` mutation.
    private(set) var filteredEntries: [LogEntry] = []
    
    /// Total entries currently loaded. Cached for the same reason as
    /// `filteredEntries`.
    private(set) var totalEntryCount: Int = .zero
    
    /// Number of entries hidden by the active filter.
    private(set) var filteredOutCount: Int = .zero
    
    /// `true` when at least one entry exists in the loaded set, regardless
    /// of filter. Drives empty-state UX (file empty vs filter excludes all).
    private(set) var hasAnyEntries: Bool = false
    
    private let service: any LogReaderServiceProtocol
    
    // MARK: - Init
    
    /// - Parameter service: Reader service injected via initializer (no DI container required).
    init(service: any LogReaderServiceProtocol) {
        self.service = service
        selectedLevels = Self.defaultLevels()
    }
    
    // MARK: - Derived state
    
    /// `true` when the share button should be enabled — entries to share and
    /// no concurrent read.
    var isShareEnabled: Bool {
        !filteredEntries.isEmpty && !state.isLoading
    }
    
    /// `true` when the clear button should be enabled — at least one entry
    /// in the loaded set (filter-independent, since clear wipes the file)
    /// and no concurrent read.
    var isClearEnabled: Bool {
        hasAnyEntries && !state.isLoading
    }
    
    // MARK: - Filter actions
    
    /// `true` when toggling `level` would not violate the "at least one
    /// selected" invariant. Used to disable the chip in the UI as a
    /// belt-and-suspenders check beyond the no-op guard in `toggle`.
    func canDeselect(_ level: Log.Level) -> Bool {
        guard selectedLevels.contains(level) else { return true }
        return selectedLevels.count > 1
    }
    
    /// Toggles `level` membership. Deselect is a no-op when it would empty
    /// the set. Insert is always allowed.
    func toggle(_ level: Log.Level) {
        if selectedLevels.contains(level) {
            guard selectedLevels.count > 1 else { return }
            selectedLevels.remove(level)
        } else {
            selectedLevels.insert(level)
        }
        recomputeDerivedState()
    }
    
    /// `true` when the filter is currently active on `level`.
    func isSelected(_ level: Log.Level) -> Bool {
        selectedLevels.contains(level)
    }
    
    /// `true` when `range` is the currently selected time window.
    func isSelected(_ range: LogDateRange) -> Bool {
        selectedDateRange == range
    }
    
    /// Selects a date range. Re-selecting the active range is a no-op so
    /// callers don't pay the recompute cost on idle taps.
    func select(_ range: LogDateRange) {
        guard selectedDateRange != range else { return }
        selectedDateRange = range
        recomputeDerivedState()
    }
    
    // MARK: - Load actions
    
    /// Reads the log file. Transitions through `.loading → .loaded | .failed`.
    func load() async {
        state = .loading
        recomputeDerivedState()
        do {
            let entries = try await service.loadEntries()
            state = .loaded(entries: entries)
        } catch let error as LogReaderError {
            state = .failed(error)
        } catch {
            state = .failed(.read(error))
        }
        recomputeDerivedState()
    }
    
    /// Alias for `load()`. Distinct symbol so callers / accessibility tooling
    /// can differentiate "initial load" vs "user-initiated refresh".
    func refresh() async {
        await load()
    }
    
    /// Background-polling refresh that never flashes a spinner. Skips when
    /// a manual load is in flight (so explicit retries win), and swallows
    /// transient I/O failures so the auto-refresh loop does not erase a
    /// good loaded state on a one-off read error.
    func refreshSilently() async {
        guard !state.isLoading, let entries = try? await service.loadEntries() else { return }
        state = .loaded(entries: entries)
        recomputeDerivedState()
    }
    
    /// Polling interval for the viewer's auto-refresh loop. Centralised so
    /// the VM owns the cadence and tests can reason about it without
    /// reaching into the view layer.
    static let autoRefreshInterval: Duration = .seconds(10)
    
    /// Exports the currently filtered entries. The export reflects both
    /// the active level filter and the active date-range filter — i.e.
    /// the user shares exactly what they see.
    /// - Returns: URL of the temporary file written by the service.
    /// - Throws: `LogReaderError.writeFailed` on I/O failure.
    func share() async throws -> URL {
        try await service.exportEntries(filteredEntries)
    }

#if DEBUG
    /// DEBUG-only diagnostic helper. Emits one log entry for every
    /// `Log.Category` × `Log.Level` combination plus a `Log.Level`
    /// showcase (atomic bits, `.base`, `.all`, and composite OptionSets)
    /// so QA can verify the console / file / parser / UI pipeline in a
    /// single tap.
    ///
    /// Temporarily enables every category **and** widens `fileLogLevel`
    /// to `.all` so neither the category gate nor the file-level gate in
    /// `Log.performLog` can silently swallow entries. The previous
    /// configuration is restored before the post-write reload.
    func generateTestLogs() async {
        let savedConfiguration = Log.configuration
        var openedConfiguration = savedConfiguration
        openedConfiguration.categoryStates = Dictionary(
            uniqueKeysWithValues: Log.Category.allCases.map { ($0, true) }
        )
        openedConfiguration.fileLogLevel = .all
        Log.configuration = openedConfiguration
        
        for category in Log.Category.allCases {
            let logger = Log(category: category)
            logger.error("Test log entry — category=\(category.rawValue) level=error")
            logger.warning("Test log entry — category=\(category.rawValue) level=warning")
            logger.info("Test log entry — category=\(category.rawValue) level=info")
            logger.debug("Test log entry — category=\(category.rawValue) level=debug")
        }
        
        emitLogLevelExamples()
        
        Log.configuration = savedConfiguration
        await load()
    }
    
    /// Emits one entry per `Log.Level` value of interest (atomic bits,
    /// the `.base` / `.all` static helpers, and two composite OptionSet
    /// combinations) so the test burst documents the Level type alongside
    /// the Category × Level matrix.
    private func emitLogLevelExamples() {
        let logger = Log(category: .application)
        let examples: [(label: String, level: Log.Level)] = [
            (".error", .error),
            (".warning", .warning),
            (".info", .info),
            (".debug", .debug),
            (".base", .base),
            (".all", .all),
            ("[.error, .warning]", [.error, .warning]),
            ("[.info, .debug]", [.info, .debug])
        ]
        for (label, level) in examples {
            let message = "Log.Level example — \(label) rawValue=\(level.rawValue) name=\"\(Log.Level.name(level))\""
            emit(message, at: level, on: logger)
        }
    }
    
    /// Routes `message` to the matching single-bit method on `logger`.
    /// For composite levels, picks the highest-priority bit set
    /// (`.error` > `.warning` > `.info` > `.debug`).
    private func emit(_ message: String, at level: Log.Level, on logger: Log) {
        switch level.primary {
        case .error: logger.error(message)
        case .warning: logger.warning(message)
        case .info: logger.info(message)
        case .debug: logger.debug(message)
        case nil: break
        }
    }
#endif

    /// Truncates the persisted log file and reloads. After success the
    /// state transitions back through `.loading → .loaded([])`. Failures
    /// surface as `.failed(error)` so the existing error UI is reused.
    func clear() async {
        do {
            try await service.clearEntries()
        } catch let error as LogReaderError {
            state = .failed(error)
            recomputeDerivedState()
            return
        } catch {
            state = .failed(.write(error))
            recomputeDerivedState()
            return
        }
        await load()
    }
    
    // MARK: - Defaults
    
    /// Default filter selection — all four displayable levels selected.
    static func defaultLevels() -> Set<Log.Level> {
        Set(filterableLevels)
    }
    
    // MARK: - Memoization
    
    private func recomputeDerivedState() {
        let entries = state.entries
        totalEntryCount = entries.count
        hasAnyEntries = !entries.isEmpty
        
        if entries.isEmpty {
            filteredEntries = []
            filteredOutCount = .zero
            return
        }
        
        let now = Date()
        filteredEntries = entries.reversed().filter { entry in
            switch entry.kind {
            case .raw:
                true
            case .parsed(let parsed):
                selectedLevels.contains(parsed.level)
                    && selectedDateRange.contains(parsed.timestamp, now: now)
            }
        }
        filteredOutCount = max(totalEntryCount - filteredEntries.count, .zero)
    }
}
