//
//  InAppAlert.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

// MARK: - In-App Alert Model

/// Represents an in-app alert that can be displayed as either
/// a full-width accent alert or a compact banner alert.
enum InAppAlert: Identifiable, Sendable, Equatable {
    /// Full-width accent alert with optional loading indicator.
    /// - Parameters:
    ///   - message: The message to display
    ///   - isLoading: Whether to show a loading spinner
    case accent(message: String, isLoading: Bool = false)
    
    /// Compact pill-shaped banner alert.
    /// - Parameters:
    ///   - message: The message to display
    ///   - type: The alert type (info, error, success)
    case banner(message: String, type: BannerAlertType)
    
    var id: String {
        switch self {
        case .accent(let message, let isLoading):
            "accent-\(message)-\(isLoading)"
        case .banner(let message, let type):
            "banner-\(message)-\(type)"
        }
    }
    
    /// The duration before auto-dismissal, or nil for manual dismiss only.
    var autoDismissDuration: Double? {
        switch self {
        case .accent(_, let isLoading):
            isLoading ? nil : 3
        case .banner(_, let type):
            switch type {
            case .info, .success: 3
            case .error: 5
            }
        }
    }
}

// MARK: - Banner Alert Type

/// The type of banner alert, determining its appearance.
enum BannerAlertType: Sendable, Equatable {
    /// Informational alert (orange background)
    case info
    /// Error alert (red background with X icon)
    case error
    /// Success alert (green/teal background with checkmark)
    case success
}
