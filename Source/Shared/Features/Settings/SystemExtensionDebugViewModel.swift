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
    
    /// A second request would supersede the first, so the UI allows one at a time.
    var isBusy: Bool {
        status == .inProgress || status == .needsApproval
    }
    
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
        status = .inProgress
        do {
            for try await event in submit(service) {
                switch event {
                case .needsUserApproval: status = .needsApproval
                case .completed: status = completedStatus
                case .willCompleteAfterReboot: status = .pendingReboot
                }
            }
            if isBusy {
                status = .failed(.endedWithoutResult)
            }
        } catch {
            let mapped = error as? SystemExtensionError ?? .unknown(code: (error as NSError).code)
            logger.warning("System extension debug request failed: \(mapped)", privacy: .public)
            status = .failed(mapped)
        }
    }
}
#endif
