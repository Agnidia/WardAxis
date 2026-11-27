//
//  AccessibilityAnnouncer.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#endif

#if os(macOS)
import AppKit
#endif

/// Service for posting VoiceOver announcements.
///
/// Use this service to announce dynamic content changes, status updates,
/// and other information that VoiceOver users need to know about.
///
/// Example:
/// ```swift
/// // Simple announcement
/// AccessibilityAnnouncer.announce("Processing complete")
///
/// // Delayed announcement (useful after view transitions)
/// AccessibilityAnnouncer.announce(
///     "Welcome to the home screen",
///     delay: .milliseconds(500)
/// )
/// ```
@MainActor
enum AccessibilityAnnouncer {
    /// Posts an announcement to VoiceOver.
    ///
    /// The announcement is only posted if VoiceOver is currently running.
    ///
    /// - Parameters:
    ///   - message: The message to announce.
    ///   - delay: Optional delay before announcing. Useful for ensuring
    ///            the announcement is made after view transitions complete.
    static func announce(_ message: String, delay: Duration = .zero) {
        guard isVoiceOverRunning else { return }
        
        Task {
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            postAnnouncement(message)
        }
    }
    
    /// Posts a screen change announcement and optionally focuses an element.
    ///
    /// Use when the screen content changes significantly, such as
    /// navigating to a new screen or showing a modal.
    ///
    /// - Parameter element: Optional element to focus after the announcement.
    static func screenChanged(to element: Any? = nil) {
        guard isVoiceOverRunning else { return }
#if canImport(UIKit)
        UIAccessibility.post(notification: .screenChanged, argument: element)
#elseif os(macOS)
        if let element {
            NSAccessibility.post(element: element as Any, notification: .focusedUIElementChanged)
        }
#endif
    }
    
    /// Posts a layout change announcement and optionally focuses an element.
    ///
    /// Use when the layout changes but the screen content remains similar,
    /// such as showing/hiding a section or updating a list.
    ///
    /// - Parameter element: Optional element to focus after the announcement.
    static func layoutChanged(focusOn element: Any? = nil) {
        guard isVoiceOverRunning else { return }
#if canImport(UIKit)
        UIAccessibility.post(notification: .layoutChanged, argument: element)
#elseif os(macOS)
        if let element {
            NSAccessibility.post(element: element as Any, notification: .layoutChanged)
        }
#endif
    }
    
    /// Announces an error message with appropriate urgency.
    ///
    /// - Parameter message: The error message to announce.
    static func announceError(_ message: String) {
        guard isVoiceOverRunning else { return }
        
        postAnnouncement(String(localized: "Error: \(message)"))
    }
    
    /// High priority on macOS, so the announcement interrupts what VoiceOver is reading.
    private static func postAnnouncement(_ message: String) {
#if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
#elseif os(macOS)
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: message,
            .priority: NSAccessibilityPriorityLevel.high
        ])
#endif
    }
    
    /// Checks if VoiceOver is currently running.
    static var isVoiceOverRunning: Bool {
#if canImport(UIKit)
        UIAccessibility.isVoiceOverRunning
#elseif os(macOS)
        NSWorkspace.shared.isVoiceOverEnabled
#else
        false
#endif
    }
}
