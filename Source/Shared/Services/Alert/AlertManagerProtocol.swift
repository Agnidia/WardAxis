//
//  AlertManagerProtocol.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

// MARK: - Alert Manager Protocol

/// Protocol for managing in-app alerts with auto-dismiss functionality.
@MainActor
protocol AlertManagerProtocol: AnyObject, Sendable {
    /// The currently displayed alert, or nil if none.
    var currentAlert: InAppAlert? { get }
    
    /// Shows an alert, replacing any currently displayed alert.
    /// - Parameter alert: The alert to display
    func show(_ alert: InAppAlert)
    
    /// Dismisses the current alert immediately.
    func dismiss()
}
