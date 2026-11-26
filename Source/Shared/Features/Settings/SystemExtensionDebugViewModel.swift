//
//  SystemExtensionDebugViewModel.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if DEBUG
import Foundation
import SwiftUI
import WardAxisTelemetry

/// Drives the DEBUG-only Developer section that activates the NetworkFilter shell
/// on a test Mac (ADR 0006). A release build compiles none of it.
@Observable @MainActor
final class SystemExtensionDebugViewModel {
    enum Status: Equatable {
        case idle
        case inProgress
        case needsApproval
        case activated
        case deactivated
        case pendingReboot
        case failed(SystemExtensionError)
    }
    
    private(set) var status: Status = .idle
    
    /// Busy only until the OS answers. Approval can wait indefinitely, so a request
    /// that needs approval may be replaced; the OS then fails the old one as superseded.
    var isBusy: Bool {
        status == .inProgress
    }
    
    /// The state the OS reports; `nil` before the first answer or after a failed query.
    private(set) var installState: SystemExtensionInstallState?
    
    /// Increments per request; only the latest request may change ``status``.
    private var requestGeneration = 0
    
    /// What the current request ends in; lets a polled state finish an approval the
    /// request's own callback did not report.
    private var pendingCompletion: Status?
    
    private let service: any SystemExtensionServiceProtocol
    private let logger = Log(category: .filter)
    
    init(service: any SystemExtensionServiceProtocol) {
        self.service = service
    }
    
    func activate() async {
        await run(completedStatus: .activated) { $0.activate() }
    }
    
    func deactivate() async {
        await run(completedStatus: .deactivated) { $0.deactivate() }
    }
    
    /// Polls ``installState`` until the calling task is cancelled, which happens when
    /// the Developer section leaves the screen.
    func monitorInstallState(every interval: Duration = .seconds(1)) async {
        while !Task.isCancelled {
            await refreshInstallState()
            try? await Task.sleep(for: interval)
        }
    }
    
    func refreshInstallState() async {
        do {
            let state = try await service.installState()
            installState = state
            reconcile(with: state)
        } catch {
            // Logged once per outage, not once per poll.
            if installState != nil, !Task.isCancelled {
                logger.warning("System extension state query failed: \(error)", privacy: .public)
            }
            installState = nil
        }
    }
    
    var installStateText: LocalizedStringKey {
        switch installState {
        case nil: L.Settings.Developer.stateUnknown
        case .notInstalled: L.Settings.Developer.stateNotInstalled
        case .awaitingApproval: L.Settings.Developer.stateAwaitingApproval
        case .enabled: L.Settings.Developer.stateEnabled
        case .disabled: L.Settings.Developer.stateDisabled
        case .uninstalling: L.Settings.Developer.stateUninstalling
        }
    }
    
    var statusText: LocalizedStringKey {
        switch status {
        case .idle: L.Settings.Developer.statusIdle
        case .inProgress: L.Settings.Developer.statusInProgress
        case .needsApproval: L.Settings.Developer.statusNeedsApproval
        case .activated: L.Settings.Developer.statusActivated
        case .deactivated: L.Settings.Developer.statusDeactivated
        case .pendingReboot: L.Settings.Developer.statusPendingReboot
        case .failed(let error): L.Settings.Developer.statusFailed(String(describing: error))
        }
    }
    
    private func run(
        completedStatus: Status,
        _ submit: (any SystemExtensionServiceProtocol) -> AsyncThrowingStream<SystemExtensionEvent, any Error>
    ) async {
        guard !isBusy else { return }
        requestGeneration += 1
        let generation = requestGeneration
        var isCurrent: Bool {
            generation == requestGeneration
        }
        status = .inProgress
        pendingCompletion = completedStatus
        do {
            for try await event in submit(service) {
                guard isCurrent else { return }
                switch event {
                case .needsUserApproval: status = .needsApproval
                case .completed: status = completedStatus
                case .willCompleteAfterReboot: status = .pendingReboot
                }
            }
            if isCurrent, status == .inProgress || status == .needsApproval {
                status = .failed(.endedWithoutResult)
            }
        } catch {
            guard isCurrent else { return }
            let mapped = error as? SystemExtensionError ?? .unknown(code: (error as NSError).code)
            logger.warning("System extension debug request failed: \(mapped)", privacy: .public)
            status = .failed(mapped)
        }
    }
    
    /// The OS can finish an approved request without a callback to this process, for
    /// example after System Settings approves it; the polled state then ends the wait.
    /// The request's later outcome is ignored, as for a replaced request.
    private func reconcile(with state: SystemExtensionInstallState) {
        guard status == .needsApproval, let pendingCompletion else { return }
        let finished: Status? = switch (pendingCompletion, state) {
        case (.activated, .enabled): .activated
        case (.deactivated, .notInstalled): .deactivated
        case (.deactivated, .uninstalling): .pendingReboot
        default: nil
        }
        guard let finished else { return }
        requestGeneration += 1
        self.pendingCompletion = nil
        status = finished
    }
}
#endif
