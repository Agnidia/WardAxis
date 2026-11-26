//
//  View+IsHidden.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// A view extension that conditionally hides a view.
///
/// This extension provides a method to conditionally render a `View` based on a boolean flag.
/// When the flag is `true`, the view is replaced with an `EmptyView`.
/// When the flag is `false`, the view is displayed normally.
///
/// Example usage:
/// ```swift
/// Text("Hello, World!")
///     .isHidden(true) // This will hide the Text view.
/// ```
extension View {
    /// Conditionally replace current view to EmptyView the view based on the given boolean value.
    ///
    /// - Parameter shouldHide: A boolean value indicating whether the view should be hidden.
    /// - Returns: Either the original view or an `EmptyView` based on the value of `shouldHide`.
    @ViewBuilder
    func isHidden(_ shouldHide: Bool) -> some View {
        if shouldHide == false {
            self
        }
    }
    
    /// Conditionally hides the view based on the given boolean value.
    ///
    /// Using `@ViewBuilder` here allows the implementation to return different
    /// views (`self.hidden()` or `self`) while preserving the `some View` return type.
    @ViewBuilder
    func isJustHidden(_ shouldHide: Bool) -> some View {
        switch shouldHide {
        case true: hidden()
        case false: self
        }
    }
}
