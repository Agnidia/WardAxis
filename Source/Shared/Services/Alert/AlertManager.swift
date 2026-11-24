//
//  AlertManager.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

// MARK: - Alert Manager

/// Manages in-app alert presentation with auto-dismiss functionality.
///
/// Alerts are displayed with slide-from-top animation and can be:
/// - Auto-dismissed after a timeout (configurable per alert type)
/// - Manually dismissed by tapping
///
/// Usage:
/// ```swift
/// let manager = AlertManager()
/// manager.show(.banner(message: "Success!", type: .success))
/// ```
@MainActor @Observable
final class AlertManager: AlertManagerProtocol {
    // MARK: - Properties
    
    /// The currently displayed alert.
    private(set) var currentAlert: InAppAlert?
    
    /// Task handling auto-dismiss timing.
    private var dismissTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    func show(_ alert: InAppAlert) {
        dismissTask?.cancel()
        currentAlert = alert
        scheduleAutoDismiss(for: alert)
    }
    
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        currentAlert = nil
    }
    
    // MARK: - Private Methods
    
    private func scheduleAutoDismiss(for alert: InAppAlert) {
        guard let duration = alert.autoDismissDuration else { return }
        
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.currentAlert = nil
        }
    }
}

// MARK: - Mock Alert Manager

/// Mock alert manager for previews and testing.
@MainActor
final class MockAlertManager: AlertManagerProtocol {
    private(set) var currentAlert: InAppAlert?
    
    init(initialAlert: InAppAlert? = nil) {
        currentAlert = initialAlert
    }
    
    func show(_ alert: InAppAlert) {
        currentAlert = alert
    }
    
    func dismiss() {
        currentAlert = nil
    }
}
