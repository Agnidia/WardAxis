//
//  SettingsViewModel.swift
//
//  Created on 15.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import SwiftUI
import WardAxisTelemetry

/// View model for `SettingsView`. Subsumes the previous `LogActionsModel`
/// (per analyzing-0.md ad4): owns the diagnostic share / clear log
/// affordances plus the cleared / share-error alert state that used to
/// live as ad-hoc `@State` on the view body.
///
/// `@MainActor` because the alert-state mutations and the
/// `LogReaderServiceProtocol` `await` call sites all run from view
/// callbacks already pinned to the main actor. The underlying log reader
/// service is itself an actor (`LogReaderService`); concurrent share /
/// clear calls serialise naturally — no extra locking required here.
@Observable @MainActor
final class SettingsViewModel {
    // MARK: - Public state

    /// `true` when at least one entry exists in the on-disk log file.
    /// Refreshed by `refreshHasEntries()` on view appear and after a
    /// successful `clearAll()`. Errors from the underlying service are
    /// swallowed and treated as "no entries" so the dependent UI surfaces
    /// stay disabled rather than spuriously enabled.
    private(set) var hasEntries: Bool = false

    /// `true` while `prepareShareURL()` or `clearAll()` is in flight.
    /// UI disables buttons while busy to prevent double-fire.
    private(set) var isBusy: Bool = false

    /// One-shot trigger for the "cleared" success alert. Identifiable so
    /// SwiftUI re-presents the alert on each new clear.
    var clearedNotice: ClearedNotice?

    /// One-shot trigger for the share-failed / clear-failed error alert.
    var shareError: ShareError?

    /// Latest prepared share URL. Reset to nil after a successful clear.
    var preparedShareURL: URL?

    // MARK: - Alert payloads

    /// Identifiable wrapper so the success alert can be re-presented for
    /// each new clear (UUID per show prevents SwiftUI from collapsing
    /// repeated clears into one presentation).
    struct ClearedNotice: Identifiable, Equatable {
        let id = UUID()
    }

    /// Identifiable wrapper so error alerts can be presented for each new
    /// failure independently.
    struct ShareError: Identifiable, Equatable {
        let id = UUID()
        let message: LocalizedStringKey
    }

    // MARK: - Dependencies

    private let logReader: any LogReaderServiceProtocol
    private let logger = Log(category: .ui)

    // MARK: - Init

    init(logReader: any LogReaderServiceProtocol) {
        self.logReader = logReader
    }

    // MARK: - Actions

    /// Probes the log file and updates `hasEntries`. Swallows errors —
    /// callers treat any failure as "no entries available" so the UI
    /// surfaces remain disabled rather than spuriously enabled.
    func refreshHasEntries() async {
        let entries = await (try? logReader.loadEntries()) ?? []
        hasEntries = !entries.isEmpty
    }

    /// Loads ALL entries from disk and exports them to a temp file,
    /// then publishes the URL via `preparedShareURL`. On failure,
    /// populates `shareError` with a localised message.
    ///
    /// Implementation note: the export path is
    /// `FileManager.default.temporaryDirectory` / `wardaxis-logs-*.txt`,
    /// which is writable on iOS and macOS without any extra entitlement.
    func prepareShareURL() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let entries = try await logReader.loadEntries()
            let url = try await logReader.exportEntries(entries)
            preparedShareURL = url
        } catch {
            logger.error("SettingsViewModel share prep failed: \(String(describing: error))")
            shareError = ShareError(message: L.Settings.Logs.errorShareFailed)
        }
    }

    /// Truncates the on-disk log file in-place via the live writer.
    /// Resets `hasEntries`, clears any previously prepared share URL,
    /// and publishes a `ClearedNotice` on success; populates
    /// `shareError` with a write-failed message on failure.
    func clearAll() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await logReader.clearEntries()
            preparedShareURL = nil
            hasEntries = false
            clearedNotice = ClearedNotice()
        } catch {
            logger.error("SettingsViewModel clear failed: \(String(describing: error))")
            shareError = ShareError(message: L.Settings.Logs.errorWriteFailed)
        }
    }
}
