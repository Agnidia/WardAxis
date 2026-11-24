//
//  View+FirstAppear.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// An extension on `View` that adds a modifier for executing an action only once when the view first appears.
///
public extension View {    
    /// Adds a modifier to execute the specified action when the view appears for the first time.
    /// Use this method to perform actions only when the view first appears, and avoid repeated calls on subsequent appearances.
    ///
    /// - Parameter action: The action to perform when the view appears for the first time.
    ///
    /// - Returns: A view that triggers the specified action the first time it appears.
    func onFirstAppear(_ action: @escaping () -> Void) -> some View {
        modifier(FirstAppear(action: action))
    }
}

/// A private view modifier that executes a given action only when the view to which it is applied appears for the first time.
private struct FirstAppear: ViewModifier {    
    /// The action to be performed when the view appears for the first time.
    let action: () -> Void
    
    /// A state variable used to track whether the view has appeared before to ensure the action is executed only once.
    @State private var hasAppeared = false
    
    /// Modifies the provided content by adding behavior that triggers the action upon the first appearance of the view.
    ///
    /// - Parameter content: The content to be modified.
    ///
    /// - Returns: The modified content with the added behavior of executing the action upon its first appearance.
    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            action()
        }
    }
}
