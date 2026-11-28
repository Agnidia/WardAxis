//
//  AccessibilityModifiers.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Protocol-Based Accessibility

extension View {
    /// Applies accessibility using an `AccessibilityProtocol` conforming element.
    ///
    /// This is the preferred method for buttons and interactive elements.
    ///
    /// Example:
    /// ```swift
    /// Button("Capture") { }
    ///     .accessible(A11y.ARPreview.capture)
    /// ```
    func accessible(_ element: any AccessibilityProtocol, isButton: Bool = true) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(element.label)
            .accessibilityHint(element.hint)
            .accessibilityIdentifier(element.id)
            .accessibilityAddTraits(isButton ? .isButton : [])
    }
    
    /// Identifier and label for an icon-only control. The glyph gives VoiceOver
    /// nothing to read, and the control keeps its own traits and hint.
    func accessibleIcon(_ element: any AccessibilityProtocol) -> some View {
        accessibilityIdentifier(element.id)
            .accessibilityLabel(element.label)
    }
    
    /// Applies accessibility using an `AccessibilityProtocol` with enabled state.
    func accessible(_ element: any AccessibilityProtocol,
                    isButton: Bool = true,
                    isEnabled: Bool) -> some View
    {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(element.label)
            .accessibilityHint(element.hint)
            .accessibilityIdentifier(element.id)
            .accessibilityAddTraits(isButton ? .isButton : [])
            .accessibilityRemoveTraits(isEnabled ? [] : .isButton)
            .accessibilityValue(isEnabled ? "" : String(localized: "Disabled"))
    }
}

// MARK: - Image Accessibility

extension View {
    /// Applies accessibility for decorative images that should be hidden from VoiceOver.
    ///
    /// Use for images that don't convey meaningful information.
    func accessibleDecorativeImage() -> some View {
        accessibilityHidden(true)
    }
    
    /// Applies accessibility for images that convey information.
    ///
    /// Example:
    /// ```swift
    /// Image(systemName: "checkmark.circle")
    ///     .accessibleImage(label: "Success")
    /// ```
    func accessibleImage(label: LocalizedStringKey) -> some View {
        accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
    }
    
    /// Applies accessibility for images with String label.
    func accessibleImage(label: String) -> some View {
        accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Reduce Motion Animation

extension View {
    /// Applies animation with reduce motion support.
    ///
    /// When the user has enabled "Reduce Motion" in accessibility settings,
    /// the reduced animation (or no animation) is used instead.
    ///
    /// Example:
    /// ```swift
    /// Circle()
    ///     .reduceMotionAnimation(
    ///         .easeInOut(duration: 1.5).repeatForever(),
    ///         value: isAnimating,
    ///         reducedAnimation: nil  // No animation when reduce motion
    ///     )
    /// ```
    func reduceMotionAnimation(_ animation: Animation?,
                               value: some Equatable,
                               reducedAnimation: Animation? = nil) -> some View
    {
        modifier(ReduceMotionAnimationModifier(
            animation: animation,
            reducedAnimation: reducedAnimation,
            value: value
        ))
    }
}

// MARK: - Reduce Motion Animation Modifier

private struct ReduceMotionAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    let animation: Animation?
    let reducedAnimation: Animation?
    let value: V
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? reducedAnimation : animation, value: value)
    }
}

// MARK: - Live Region / Announcement Support

extension View {
    /// Posts a VoiceOver announcement when a condition changes to true.
    ///
    /// Example:
    /// ```swift
    /// Text("Processing...")
    ///     .accessibilityAnnounce(
    ///         "Processing complete",
    ///         when: isComplete
    ///     )
    /// ```
    func accessibilityAnnounce(_ message: String, when trigger: Bool) -> some View {
        onChange(of: trigger) { _, newValue in
            if newValue {
                AccessibilityAnnouncer.announce(message)
            }
        }
    }
    
    /// Posts a VoiceOver announcement when value changes.
    func accessibilityAnnounceChange<V: Equatable>(_ message: @escaping (V) -> String, value: V) -> some View {
        onChange(of: value) { _, newValue in
            AccessibilityAnnouncer.announce(message(newValue))
        }
    }
}

// MARK: - Group Accessibility

extension View {
    /// Applies accessibility for a grouped container (e.g., toggle rows, settings groups).
    ///
    /// Combines child elements into a single accessible group with label, hint, and identifier.
    func accessibleGroup(_ element: any AccessibilityProtocol) -> some View {
        accessibilityElement(children: .combine)
            .accessibilityLabel(element.label)
            .accessibilityHint(element.hint)
            .accessibilityIdentifier(element.id)
    }
}

// MARK: - Selectable Accessibility

extension View {
    /// Applies accessibility for a selectable element (chips, radio rows, segment buttons).
    ///
    /// Adds the `.isSelected` trait when the element is selected so VoiceOver announces state.
    func accessibleSelectable(
        label: String,
        identifier: String,
        isSelected: Bool
    ) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Text Field Accessibility

extension View {
    /// Applies accessibility for text input fields.
    ///
    /// Example:
    /// ```swift
    /// TextField("Phone", text: $phone)
    ///     .accessibleTextField(
    ///         label: "Phone number",
    ///         hint: "Enter your 10-digit phone number",
    ///         identifier: AccessibilityID.Auth.phoneInput
    ///     )
    /// ```
    func accessibleTextField(_ element: any AccessibilityProtocol, label: LocalizedStringKey, value: String? = nil) -> some View {
        accessibilityLabel(label)
            .accessibilityHint(element.hint)
            .accessibilityIdentifier(element.id)
            .accessibilityValue(value ?? "")
    }
}

// MARK: - Progress Accessibility

extension View {
    /// Applies accessibility for progress indicators.
    ///
    /// Example:
    /// ```swift
    /// ProgressView(value: progress)
    ///     .accessibleProgress(
    ///         label: "Scan progress",
    ///         value: progress,
    ///         identifier: AccessibilityID.FaceScan.progressIndicator
    ///     )
    /// ```
    func accessibleProgress(
        label: LocalizedStringKey,
        value: Double,
        identifier: String
    ) -> some View {
        let percentage = Int(value * 100)
        return accessibilityLabel(label)
            .accessibilityValue("\(percentage) percent")
            .accessibilityIdentifier(identifier)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
