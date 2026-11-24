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
/// Button(action: close) {
///     Image(systemName: "xmark")
/// }
/// .accessibilityIdentifier(AccessibilityID.ARPreview.closeButton.id)
/// .accessibilityLabel(AccessibilityID.ARPreview.closeButton.label)
/// .accessibilityHint(AccessibilityID.ARPreview.closeButton.hint)
///
/// // Button with visible text (no label needed)
/// Button("Continue") { }
/// .accessibilityIdentifier(AccessibilityID.Auth.continueButton.id)
/// .accessibilityHint(AccessibilityID.Auth.continueButton.hint)
/// ```
enum AccessibilityID: Sendable {
    // MARK: - Common State Strings

    /// Common accessibility state strings.
    enum State {
        static var disabled: String {
            String(localized: "accessibility.state.disabled", defaultValue: "Disabled")
        }

        static var loading: String {
            String(localized: "accessibility.state.loading", defaultValue: "Loading")
        }

        static var selected: String {
            String(localized: "accessibility.state.selected", defaultValue: "Selected")
        }
    }

    /// Common accessibility error formatting.
    static func error(message: String) -> String {
        String(localized: "Error: \(message)")
    }

    // MARK: - Permissions

    enum Permissions: String, AccessibilityProtocol, CaseIterable, Sendable {
        case allowButton = "permissions.allow"
        case icon = "permissions.icon"
        case title = "permissions.title"
        case description = "permissions.description"

        var id: String {
            rawValue
        }

        /// Dynamic allow button label for specific permission.
        static func allowLabel(permission: String) -> String {
            String(localized: "Allow \(permission) access")
        }
    }

    // MARK: - Onboarding

    enum Onboarding: String, AccessibilityProtocol, CaseIterable, Sendable {
        case getStartedButton = "onboarding.getStarted"
        case featureRow = "onboarding.feature"
        case stepIndicator = "onboarding.step"

        var id: String {
            rawValue
        }
    }

    // MARK: - Main Tabs

    enum MainTab: String, AccessibilityProtocol, CaseIterable, Sendable {
        case home = "main.tab.home"
        case settings = "main.tab.settings"

        var id: String {
            rawValue
        }
    }

    // MARK: - Home

    enum Home: String, AccessibilityProtocol, CaseIterable, Sendable {
        case settingsButton = "home.settings"

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
