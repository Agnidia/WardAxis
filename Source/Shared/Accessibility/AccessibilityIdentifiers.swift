//
//  AccessibilityIdentifiers.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

// MARK: - Accessibility Protocol

/// Protocol for type-safe, localized accessibility support.
///
/// All UI elements MUST follow this protocol pattern for consistent accessibility.
/// Labels and hints are automatically localized using the key format:
/// - `accessibility.<id>.label` for labels
/// - `accessibility.<id>.hint` for hints
protocol AccessibilityProtocol: Sendable {
    var id: String { get }
    var label: String { get }
    var hint: String { get }
}

extension AccessibilityProtocol {
    /// The key is bound to a `String` first. Passed as an interpolated literal, the
    /// lookup key becomes the format `accessibility.%@.label`, not this element's
    /// `accessibility.<id>.label`, so no translation is found and VoiceOver reads
    /// the key itself.
    var label: String {
        let key = "accessibility.\(id).label"
        return String(localized: String.LocalizationValue(key))
    }
    
    var hint: String {
        let key = "accessibility.\(id).hint"
        return String(localized: String.LocalizationValue(key))
    }
}

// MARK: - Accessibility Identifiers

/// Centralized accessibility identifiers organized by feature.
///
/// Each enum conforms to `AccessibilityProtocol` providing:
/// - `.id` - Unique identifier for UI testing
/// - `.label` - Localized label for elements without visible text
/// - `.hint` - Localized hint describing the action
///
/// Usage:
/// ```swift
/// // Icon-only button (needs label)
/// Button(action: share) {
///     Image(systemName: "square.and.arrow.up")
/// }
/// .accessibilityIdentifier(AccessibilityID.Logs.shareButton.id)
/// .accessibilityLabel(AccessibilityID.Logs.shareButton.label)
/// .accessibilityHint(AccessibilityID.Logs.shareButton.hint)
///
/// // Button with visible text (no label needed)
/// Button(L.Main.Tab.settings) { }
/// .accessibilityIdentifier(AccessibilityID.Home.settingsButton.id)
/// .accessibilityHint(AccessibilityID.Home.settingsButton.hint)
/// ```
enum AccessibilityID: Sendable {
    enum Screen {
        static let home = "screen.home"
        static let settings = "screen.settings"
        static let help = "screen.help"
    }
    
    // MARK: - Home
    
    enum Home: String, AccessibilityProtocol, CaseIterable, Sendable {
        case settingsButton = "home.settings"
        
        var id: String {
            rawValue
        }
    }
    
    // MARK: - Developer (DEBUG, macOS)
    
    enum Developer: String, AccessibilityProtocol, CaseIterable, Sendable {
        case activateButton = "developer.activateButton"
        case deactivateButton = "developer.deactivateButton"
        case status = "developer.status"
        case installState = "developer.installState"
        
        var id: String {
            rawValue
        }
    }
    
    // MARK: - Logs Viewer
    
    enum Logs: String, AccessibilityProtocol, CaseIterable, Sendable {
        case panel = "logs.panel"
        case refreshButton = "logs.refreshButton"
        case shareButton = "logs.shareButton"
        case clearButton = "logs.clearButton"
        case testButton = "logs.testButton"
        
        case settingsShareButton = "logs.settings.shareButton"
        case settingsClearButton = "logs.settings.clearButton"
        case bodyShareButton = "logs.body.shareButton"
        case bodyClearButton = "logs.body.clearButton"
        
        case filterError = "logs.filter.error"
        case filterWarning = "logs.filter.warning"
        case filterInfo = "logs.filter.info"
        case filterDebug = "logs.filter.debug"
        
        case filterDateRange10min = "logs.filter.dateRange.10min"
        case filterDateRange30min = "logs.filter.dateRange.30min"
        case filterDateRange1h = "logs.filter.dateRange.1h"
        case filterDateRange1d = "logs.filter.dateRange.1d"
        case filterDateRangeAll = "logs.filter.dateRange.all"
        
        var id: String {
            rawValue
        }
    }
}
