//
//  SettingsViewModelTests.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
@testable import WardAxis

@Suite("SettingsViewModel")
@MainActor
struct SettingsViewModelTests {
    // MARK: - Helpers
    
    private func makeViewModel(
        scenario: MockLogReaderService.Scenario = .sampleEntries
    ) -> (SettingsViewModel, MockLogReaderService) {
        let mock = MockLogReaderService(scenario: scenario)
        let viewModel = SettingsViewModel(logReader: mock)
        return (viewModel, mock)
    }
    
    // MARK: - Initial state
    
    @Test("initial state — hasEntries / isBusy / clearedNotice / shareError / preparedShareURL are all empty")
    func initialStateIsEmpty() {
        let (viewModel, _) = makeViewModel()
        #expect(!viewModel.hasEntries)
        #expect(!viewModel.isBusy)
        #expect(viewModel.clearedNotice == nil)
        #expect(viewModel.shareError == nil)
        #expect(viewModel.preparedShareURL == nil)
    }
    
    // MARK: - refreshHasEntries
    
    @Test("refreshHasEntries reflects non-empty service result as hasEntries == true")
    func refreshHasEntriesTrueWhenServiceHasEntries() async {
        let (viewModel, _) = makeViewModel(scenario: .sampleEntries)
        await viewModel.refreshHasEntries()
        #expect(viewModel.hasEntries)
    }
    
    @Test("refreshHasEntries reflects empty service result as hasEntries == false")
    func refreshHasEntriesFalseWhenServiceEmpty() async {
        let (viewModel, _) = makeViewModel(scenario: .empty)
        await viewModel.refreshHasEntries()
        #expect(!viewModel.hasEntries)
    }
    
    @Test("refreshHasEntries swallows service errors and treats failure as no entries")
    func refreshHasEntriesSwallowsErrors() async {
        let (viewModel, _) = makeViewModel(
            scenario: .failure(.readFailed(underlying: "simulated"))
        )
        await viewModel.refreshHasEntries()
        #expect(!viewModel.hasEntries)
    }
    
    // MARK: - prepareShareURL
    
    @Test("prepareShareURL publishes a temp .txt URL when the service has entries")
    func prepareShareURLPublishesTempURL() async throws {
        let (viewModel, mock) = makeViewModel(scenario: .sampleEntries)
        await viewModel.prepareShareURL()
        
        let url = try #require(viewModel.preparedShareURL)
        #expect(url.pathExtension == "txt")
        let exportCount = await mock.exportCallCount
        #expect(exportCount == 1)
        #expect(!viewModel.isBusy, "isBusy must reset after success")
        #expect(viewModel.shareError == nil)
    }
    
    @Test("prepareShareURL exports an empty body when the service returns no entries")
    func prepareShareURLWorksWithEmptyService() async {
        let (viewModel, mock) = makeViewModel(scenario: .empty)
        await viewModel.prepareShareURL()
        
        #expect(viewModel.preparedShareURL?.pathExtension == "txt")
        let exported = await mock.lastExportedEntries
        #expect(exported?.isEmpty == true)
    }
    
    @Test("prepareShareURL populates shareError and resets isBusy when the service throws")
    func prepareShareURLPublishesErrorOnFailure() async {
        let (viewModel, _) = makeViewModel(
            scenario: .failure(.readFailed(underlying: "boom"))
        )
        await viewModel.prepareShareURL()
        
        #expect(viewModel.preparedShareURL == nil)
        #expect(viewModel.shareError != nil, "shareError must be populated on failure")
        #expect(!viewModel.isBusy, "isBusy must reset after a thrown error (defer)")
    }
    
    // MARK: - clearAll
    
    @Test("clearAll calls service.clearEntries exactly once and publishes a ClearedNotice")
    func clearAllPublishesNotice() async {
        let (viewModel, mock) = makeViewModel(scenario: .sampleEntries)
        await viewModel.refreshHasEntries()
        #expect(viewModel.hasEntries)
        
        await viewModel.clearAll()
        
        let count = await mock.clearCallCount
        #expect(count == 1)
        #expect(!viewModel.hasEntries)
        #expect(viewModel.clearedNotice != nil, "clearedNotice must be set on success")
        #expect(!viewModel.isBusy, "isBusy must reset after success")
    }
    
    @Test("clearAll publishes shareError and resets isBusy when the underlying service throws")
    func clearAllPublishesErrorOnFailure() async {
        let mock = ThrowingClearMock()
        let viewModel = SettingsViewModel(logReader: mock)
        
        await viewModel.clearAll()
        
        #expect(viewModel.shareError != nil, "shareError must be populated on failure")
        #expect(viewModel.clearedNotice == nil, "clearedNotice must NOT fire on failure")
        #expect(!viewModel.isBusy, "isBusy must reset after thrown error (defer)")
    }
    
    // MARK: - clearAll resets preparedShareURL
    
    @Test("clearAll discards any previously prepared share URL")
    func clearAllResetsPreparedShareURL() async {
        let (viewModel, _) = makeViewModel(scenario: .sampleEntries)
        await viewModel.prepareShareURL()
        #expect(viewModel.preparedShareURL != nil)
        
        await viewModel.clearAll()
        #expect(viewModel.preparedShareURL == nil)
    }
}

// MARK: - Test Doubles

/// Mock that always throws `LogReaderError.writeFailed` from `clearEntries()`
/// so we can verify `SettingsViewModel.clearAll()` surfaces errors and still
/// resets `isBusy` via its `defer`.
private actor ThrowingClearMock: LogReaderServiceProtocol {
    func loadEntries() async throws -> [LogEntry] {
        []
    }
    
    func exportEntries(_: [LogEntry]) async throws -> URL {
        FileManager.default.temporaryDirectory.appending(path: "ignored.txt")
    }
    
    func clearEntries() async throws {
        throw LogReaderError.writeFailed(underlying: "simulated clear failure")
    }
}
