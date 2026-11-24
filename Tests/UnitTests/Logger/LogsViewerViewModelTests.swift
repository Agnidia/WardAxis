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
    
    @Test
    func `initial state is .loading before load() is called`() {
        let vm = makeVM()
        guard case .loading = vm.state else {
            Issue.record("Expected .loading but got \(vm.state)")
            return
        }
    }
    
    @Test
    func `selectedLevels is never empty at initialization`() {
        let vm = makeVM()
        #expect(!vm.selectedLevels.isEmpty)
    }
    
    // MARK: - load() state transitions
    
    @Test
    func `load() transitions state from .loading to .loaded`() async {
        let vm = makeVM(scenario: .sampleEntries)
        await vm.load()
        
        guard case .loaded = vm.state else {
            Issue.record("Expected .loaded after successful load(), got \(vm.state)")
            return
        }
    }
    
    @Test
    func `load() with empty service transitions to .loaded with empty entries`() async {
        let vm = makeVM(scenario: .empty)
        await vm.load()
        
        guard case let .loaded(entries) = vm.state else {
            Issue.record("Expected .loaded but got \(vm.state)")
            return
        }
        #expect(entries.isEmpty)
    }
    
    @Test
    func `load() with failing service transitions to .failed`() async {
        let vm = makeVM(scenario: .failure(.readFailed(underlying: "simulated error")))
        await vm.load()
        
        guard case let .failed(error) = vm.state else {
            Issue.record("Expected .failed but got \(vm.state)")
            return
        }
        #expect(error == .readFailed(underlying: "simulated error"))
    }
    
    // MARK: - Filter toggle invariants
    
    @Test
    func `toggle removes a selected level when multiple levels are selected`() {
        let vm = makeVM()
        for level in LogsViewerViewModel.filterableLevels where !vm.selectedLevels.contains(level) {
            vm.toggle(level)
        }
        #expect(vm.selectedLevels.count == 4)
        
        vm.toggle(.debug)
        #expect(!vm.selectedLevels.contains(.debug))
        #expect(vm.selectedLevels.count == 3)
    }
    
    @Test
    func `toggle is a no-op when only one level is selected and it would be deselected`() throws {
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
    
    @Test
    func `canDeselect returns false when only one level is selected`() throws {
        let vm = makeVM()
        let levelsToRemove: [Log.Level] = [.warning, .info, .debug]
        for level in levelsToRemove where vm.selectedLevels.contains(level) && vm.selectedLevels.count > 1 {
            vm.toggle(level)
        }
        let lastLevel = try #require(vm.selectedLevels.first)
        #expect(!vm.canDeselect(lastLevel))
    }
    
    @Test
    func `canDeselect returns true for a level when multiple levels are selected`() {
        let vm = makeVM()
        for level in LogsViewerViewModel.filterableLevels where !vm.selectedLevels.contains(level) {
            vm.toggle(level)
        }
        #expect(vm.selectedLevels.count > 1)
        #expect(vm.canDeselect(.error))
    }
    
    // MARK: - filteredEntries
    
    @Test
    func `filteredEntries is empty when state is not .loaded`() {
        let vm = makeVM()
        #expect(vm.filteredEntries.isEmpty)
    }
    
    @Test
    func `filteredEntries always includes .raw entries regardless of level filter`() async {
        let vm = makeVM(scenario: .sampleEntries)
        await vm.load()
        
        let levelsToRemove: [Log.Level] = [.warning, .info, .debug]
        for level in levelsToRemove where vm.selectedLevels.contains(level) && vm.selectedLevels.count > 1 {
            vm.toggle(level)
        }
        
        let rawCount = vm.filteredEntries.count(where: {
            if case .raw = $0.kind {
                true
            } else {
                false
            }
        })
        #expect(rawCount >= 1, "At least one .raw entry must always be visible")
    }
    
    // MARK: - isShareEnabled
    
    @Test
    func `isShareEnabled is false when no entries are loaded`() async {
        let vm = makeVM(scenario: .empty)
        await vm.load()
        #expect(!vm.isShareEnabled)
    }
    
    @Test
    func `isShareEnabled is true when entries are loaded and filter is non-empty`() async {
        let vm = makeVM(scenario: .sampleEntries)
        await vm.load()
        #expect(vm.isShareEnabled)
    }
    
    // MARK: - share()
    
    @Test
    func `share() returns a URL from the service export`() async throws {
        let vm = makeVM(scenario: .sampleEntries)
        await vm.load()
        
        let url = try await vm.share()
        #expect(url.pathExtension == "txt")
    }
    
    // MARK: - defaultLevels()
    
    @Test
    func `defaultLevels returns all four canonical levels`() {
        let levels = LogsViewerViewModel.defaultLevels()
        #expect(levels.count == 4)
        #expect(levels.contains(.error))
        #expect(levels.contains(.warning))
        #expect(levels.contains(.info))
        #expect(levels.contains(.debug))
    }
    
    // MARK: - Date range filter
    
    @Test
    func `default selectedDateRange is .all at initialization`() {
        let vm = makeVM()
        #expect(vm.selectedDateRange == .all)
    }
    
    @Test
    func `filterableDateRanges contains the five canonical ranges in order`() {
        #expect(LogsViewerViewModel.filterableDateRanges == [
            .tenMinutes, .thirtyMinutes, .oneHour, .oneDay, .all
        ])
    }
    
    @Test
    func `select(_:) updates selectedDateRange`() async {
        let vm = makeVM(scenario: .empty)
        await vm.load()
        vm.select(.tenMinutes)
        #expect(vm.selectedDateRange == .tenMinutes)
    }
    
    @Test
    func `isSelected(_:) reflects the active date range`() {
        let vm = makeVM()
        vm.select(.oneHour)
        #expect(vm.isSelected(LogDateRange.oneHour))
        #expect(!vm.isSelected(LogDateRange.all))
    }
    
    @Test
    func `date filter excludes parsed entries older than the lookback window`() async {
        let now = Date()
        let inWindow = makeParsedEntry(timestamp: now.addingTimeInterval(-60))
        let outOfWindow = makeParsedEntry(timestamp: now.addingTimeInterval(-1800))
        let vm = LogsViewerViewModel(service: FixedEntriesMock(entries: [inWindow, outOfWindow]))
        await vm.load()
        
        vm.select(.tenMinutes)
        
        let parsedKinds = vm.filteredEntries.compactMap { entry -> LogEntry.Parsed? in
            if case let .parsed(p) = entry.kind {
                p
            } else {
                nil
            }
        }
        #expect(parsedKinds.count == 1, "Only the recent entry should remain")
    }
    
    @Test
    func `date filter passes parsed entries with nil timestamps`() async {
        let now = Date()
        let untimestamped = makeParsedEntry(timestamp: nil)
        let outOfWindow = makeParsedEntry(timestamp: now.addingTimeInterval(-7200))
        let vm = LogsViewerViewModel(service: FixedEntriesMock(entries: [untimestamped, outOfWindow]))
        await vm.load()
        
        vm.select(.oneHour)
        
        let parsedCount = vm.filteredEntries.count(where: {
            if case .parsed = $0.kind {
                true
            } else {
                false
            }
        })
        #expect(parsedCount == 1, "Nil-timestamp entry must always pass; out-of-window entry must be excluded")
    }
    
    @Test
    func `.raw entries always pass even with a non-.all date range`() async {
        let raw = LogEntry(id: UUID(), kind: .raw("raw line"), rawLine: "raw line")
        let outOfWindow = makeParsedEntry(timestamp: Date().addingTimeInterval(-86_400))
        let vm = LogsViewerViewModel(service: FixedEntriesMock(entries: [raw, outOfWindow]))
        await vm.load()
        
        vm.select(.tenMinutes)
        
        let rawCount = vm.filteredEntries.count(where: {
            if case .raw = $0.kind {
                true
            } else {
                false
            }
        })
        #expect(rawCount == 1)
    }
    
    // MARK: - clear()
    
    @Test
    func `clear() invokes the service and reloads to an empty state`() async {
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
    
    @Test
    func `isClearEnabled is false when no entries are loaded`() async {
        let vm = makeVM(scenario: .empty)
        await vm.load()
        #expect(!vm.isClearEnabled)
    }
    
    @Test
    func `isClearEnabled is true when entries exist and not loading`() async {
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
