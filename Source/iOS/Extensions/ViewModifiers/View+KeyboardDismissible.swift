//
//  View+KeyboardDismissible.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if os(iOS)
import SwiftUI
import UIKit

/// A view modifier that enables dismissal of the keyboard when the view is tapped.
private struct KeyboardDismissible: ViewModifier {
    /// Modifies the content view by adding a tap gesture to dismiss the keyboard.
    /// - Parameter content: The content view to modify.
    /// - Returns: A modified view that dismisses the keyboard when tapped.
    func body(content: Content) -> some View {
        content
            .onTapGesture(perform: Self.dismissKeyboard)
    }
    
    /// Dismisses the keyboard by ending editing in the key window.
    static func dismissKeyboard() {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        keyWindow?.endEditing(true)
    }
}

public extension View {
    /// Applies a modifier that enables dismissal of the keyboard when the view is tapped.
    /// - Returns: A view with the keyboard dismissible functionality.
    func keyboardDismissible() -> some View {
        ModifiedContent(content: self, modifier: KeyboardDismissible())
    }
}
#endif
