//
//  LogsViewerViewModelTests.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisTelemetry
@testable import WardAxis

@Suite("LogsViewerViewModel")
@MainActor
struct LogsViewerViewModelTests {
    // MARK: - Helpers
    
    private func makeVM(scenario: MockLogReaderService.Scenario = .sampleEntries) -> LogsViewerViewModel {
        LogsViewerViewModel(service: MockLogReaderService(scenario: scenario))
    }
    
    private func makeParsedEntry(timestamp: Date?, level: Log.Level = .info) -> LogEntry {
        let parsed = LogEntry.Parsed(
            timestamp: timestamp,
            level: level,
            category: .application,
            message: "ts",
            info: nil
        )
        return LogEntry(
            id: UUID(),
            kind: .parsed(parsed),
            rawLine: "[application] [\(Log.Level.name(level))] ts"
        )
    }
    
    // MARK: - Initial state
    
    @Test("initial state is .loading before load() is called")
    func initialStateIsLoading() {
        let vm = makeVM()
        guard case .loading = vm.state else {
            Issue.record("Expected .loading but got \(vm.state)")
            return
        }
    }
    
    @Test("selectedLevels is never empty at initialization")
    func selectedLevelsNonEmptyAtInit() {
        let vm = makeVM()
        #expect(!vm.selectedLevels.isEmpty)
    }
    
    // MARK: - load() state transitions
    
    @Test("load() transitions state from .loading to .loaded")
    func loadTransitionsToLoaded() async {
        let vm = makeVM(scenario: .sampleEntries)
        await vm.load()
        
        guard case .loaded = vm.state else {
            Issue.record("Expected .loaded after successful load(), got \(vm.state)")
            return
        }
    }
    
    @Test("load() with empty service transitions to .loaded with empty entries")
    func loadWithEmptyServiceGivesEmptyLoaded() async {
        let vm = makeVM(scenario: .empty)
        await vm.load()
        
        guard case let .loaded(entries) = vm.state else {
            Issue.record("Expected .loaded but got \(vm.state)")
            return
        }
        #expect(entries.isEmpty)
    }
    
    @Test("load() with failing service transitions to .failed")
    func loadWithFailingServiceGivesFailed() async {
        let vm = makeVM(scenario: .failure(.readFailed(underlying: "simulated error")))
        await vm.load()
        
        guard case let .failed(error) = vm.state else {
            Issue.record("Expected .failed but got \(vm.state)")
            return
        }
        #expect(error == .readFailed(underlying: "simulated error"))
    }
    
    // MARK: - Filter toggle invariants
    
    @Test("toggle removes a selected level when multiple levels are selected")
    func toggleRemovesLevelWhenMultipleSelected() {
        let vm = makeVM()
        for level in LogsViewerViewModel.filterableLevels where !vm.selectedLevels.contains(level) {
            vm.toggle(level)
        }
        #expect(vm.selectedLevels.count == 4)
        
        vm.toggle(.debug)
        #expect(!vm.selectedLevels.contains(.debug))
        #expect(vm.selectedLevels.count == 3)
    }
    
    @Test("toggle is a no-op when only one level is selected and it would be deselected")
    func toggleIsNoOpOnLastSelectedLevel() throws {
        let vm = makeVM()
        let levelsToRemove: [Log.Level] = [.warning, .info, .debug]
        for level in levelsToRemove where vm.selectedLevels.contains(level) && vm.selectedLevels.count > 1 {
            vm.toggle(level)
        }
        let remaining = vm.selectedLevels
        #expect(remaining.count == 1)
        let lastLevel = try #require(remaining.first)
        
        vm.toggle(lastLevel)
        #expect(vm.selectedLevels.contains(lastLevel), "Last selected level must not be removed")
        #expect(vm.selectedLevels.count == 1)
    }
    
    @Test("canDeselect returns false when only one level is selected")
    func canDeselectReturnsFalseForLastLevel() throws {
        let vm = makeVM()
        let levelsToRemove: [Log.Level] = [.warning, .info, .debug]
        for level in levelsToRemove where vm.selectedLevels.contains(level) && vm.selectedLevels.count > 1 {
            vm.toggle(level)
        }
        let lastLevel = try #require(vm.selectedLevels.first)
        #expect(!vm.canDeselect(lastLevel))
    }
    
    @Test("canDeselect returns true for a level when multiple levels are selected")
    func canDeselectReturnsTrueWhenMultipleSelected() {
        let vm = makeVM()
        for level in LogsViewerViewModel.filterableLevels where !vm.selectedLevels.contains(level) {
            vm.toggle(level)
        }
        #expect(vm.selectedLevels.count > 1)
        #expect(vm.canDeselect(.error))
    }
    
    // MARK: - filteredEntries
    
    @Test("filteredEntries is empty when state is not .loaded")
    func filteredEntriesEmptyWhenNotLoaded() {
        let vm = makeVM()
        #expect(vm.filteredEntries.isEmpty)
    }
    
    @Test("filteredEntries always includes .raw entries regardless of level filter")
    func rawEntriesAlwaysShown() async {
        let vm = makeVM(scenario: .sampleEntries)
        await vm.load()
        
        let levelsToRemove: [Log.Level] = [.warning, .info, .debug]
        for level in levelsToRemove where vm.selectedLevels.contains(level) && vm.selectedLevels.count > 1 {
            vm.toggle(level)
        }
        
        let rawCount = vm.filteredEntries.count(where: { if case .raw = $0.kind { true } else { false } })
        #expect(rawCount >= 1, "At least one .raw entry must always be visible")
    }
    
    // MARK: - isShareEnabled
    
    @Test("isShareEnabled is false when no entries are loaded")
    func isShareEnabledFalseWhenEmpty() async {
        let vm = makeVM(scenario: .empty)
        await vm.load()
        #expect(!vm.isShareEnabled)
    }
    
    @Test("isShareEnabled is true when entries are loaded and filter is non-empty")
    func isShareEnabledTrueWhenEntriesPresent() async {
        let vm = makeVM(scenario: .sampleEntries)
        await vm.load()
        #expect(vm.isShareEnabled)
    }
    
    // MARK: - share()
    
    @Test("share() returns a URL from the service export")
    func shareReturnsURL() async throws {
        let vm = makeVM(scenario: .sampleEntries)
        await vm.load()
        
        let url = try await vm.share()
        #expect(url.pathExtension == "txt")
    }
    
    // MARK: - defaultLevels()
    
    @Test("defaultLevels returns all four canonical levels")
    func defaultLevelsContainsAllFour() {
        let levels = LogsViewerViewModel.defaultLevels()
        #expect(levels.count == 4)
        #expect(levels.contains(.error))
        #expect(levels.contains(.warning))
        #expect(levels.contains(.info))
        #expect(levels.contains(.debug))
    }
    
    // MARK: - Date range filter
    
    @Test("default selectedDateRange is .all at initialization")
    func defaultDateRangeIsAll() {
        let vm = makeVM()
        #expect(vm.selectedDateRange == .all)
    }
    
    @Test("filterableDateRanges contains the five canonical ranges in order")
    func filterableDateRangesAreCanonical() {
        #expect(LogsViewerViewModel.filterableDateRanges == [
            .tenMinutes, .thirtyMinutes, .oneHour, .oneDay, .all
        ])
    }
    
    @Test("select(_:) updates selectedDateRange")
    func selectUpdatesDateRange() async {
        let vm = makeVM(scenario: .empty)
        await vm.load()
        vm.select(.tenMinutes)
        #expect(vm.selectedDateRange == .tenMinutes)
    }
    
    @Test("isSelected(_:) reflects the active date range")
    func isSelectedReflectsActiveRange() {
        let vm = makeVM()
        vm.select(.oneHour)
        #expect(vm.isSelected(LogDateRange.oneHour))
        #expect(!vm.isSelected(LogDateRange.all))
    }
    
    @Test("date filter excludes parsed entries older than the lookback window")
    func dateFilterExcludesOldEntries() async {
        let now = Date()
        let inWindow = makeParsedEntry(timestamp: now.addingTimeInterval(-60))
        let outOfWindow = makeParsedEntry(timestamp: now.addingTimeInterval(-1800))
        let vm = LogsViewerViewModel(service: FixedEntriesMock(entries: [inWindow, outOfWindow]))
        await vm.load()
        
        vm.select(.tenMinutes)
        
        let parsedKinds = vm.filteredEntries.compactMap { entry -> LogEntry.Parsed? in
            if case let .parsed(p) = entry.kind { return p } else { return nil }
        }
        #expect(parsedKinds.count == 1, "Only the recent entry should remain")
    }
    
    @Test("date filter passes parsed entries with nil timestamps")
    func dateFilterPassesNilTimestamps() async {
        let now = Date()
        let untimestamped = makeParsedEntry(timestamp: nil)
        let outOfWindow = makeParsedEntry(timestamp: now.addingTimeInterval(-7200))
        let vm = LogsViewerViewModel(service: FixedEntriesMock(entries: [untimestamped, outOfWindow]))
        await vm.load()
        
        vm.select(.oneHour)
        
        let parsedCount = vm.filteredEntries.count(where: {
            if case .parsed = $0.kind { true } else { false }
        })
        #expect(parsedCount == 1, "Nil-timestamp entry must always pass; out-of-window entry must be excluded")
    }
    
    @Test(".raw entries always pass even with a non-.all date range")
    func rawEntriesPassDateFilter() async {
        let raw = LogEntry(id: UUID(), kind: .raw("raw line"), rawLine: "raw line")
        let outOfWindow = makeParsedEntry(timestamp: Date().addingTimeInterval(-86_400))
        let vm = LogsViewerViewModel(service: FixedEntriesMock(entries: [raw, outOfWindow]))
        await vm.load()
        
        vm.select(.tenMinutes)
        
        let rawCount = vm.filteredEntries.count(where: {
            if case .raw = $0.kind { true } else { false }
        })
        #expect(rawCount == 1)
    }
    
    // MARK: - clear()
    
    @Test("clear() invokes the service and reloads to an empty state")
    func clearReloadsEmpty() async {
        let mock = MockLogReaderService(scenario: .sampleEntries)
        let vm = LogsViewerViewModel(service: mock)
        await vm.load()
        #expect(vm.hasAnyEntries)
        
        await vm.clear()
        
        let count = await mock.clearCallCount
        #expect(count == 1)
        #expect(!vm.hasAnyEntries)
        #expect(vm.filteredEntries.isEmpty)
        if case let .loaded(entries) = vm.state {
            #expect(entries.isEmpty)
        } else {
            Issue.record("Expected .loaded after clear(), got \(vm.state)")
        }
    }
    
    @Test("isClearEnabled is false when no entries are loaded")
    func clearDisabledWhenEmpty() async {
        let vm = makeVM(scenario: .empty)
        await vm.load()
        #expect(!vm.isClearEnabled)
    }
    
    @Test("isClearEnabled is true when entries exist and not loading")
    func clearEnabledWhenEntriesPresent() async {
        let vm = makeVM(scenario: .sampleEntries)
        await vm.load()
        #expect(vm.isClearEnabled)
    }
}

// MARK: - Test Doubles

/// Actor-isolated mock returning a fixed entry list for deterministic
/// timestamp-based tests.
actor FixedEntriesMock: LogReaderServiceProtocol {
    private let entries: [LogEntry]
    private(set) var lastExportedEntries: [LogEntry]?
    private var wasCleared: Bool = false
    private(set) var clearCallCount: Int = 0
    
    init(entries: [LogEntry]) {
        self.entries = entries
    }
    
    func loadEntries() async throws -> [LogEntry] {
        wasCleared ? [] : entries
    }
    
    func exportEntries(_ entries: [LogEntry]) async throws -> URL {
        lastExportedEntries = entries
        let url = FileManager.default.temporaryDirectory.appending(
            path: "fixed-\(UUID().uuidString).txt"
        )
        try "".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    func clearEntries() async throws {
        clearCallCount += 1
        wasCleared = true
    }
}
