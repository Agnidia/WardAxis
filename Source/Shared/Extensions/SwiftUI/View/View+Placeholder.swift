//
//  View+Placeholder.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

public extension View {
    /// Adds a placeholder view conditionally when a certain condition is met.
    ///
    /// - Parameters:
    ///   - shouldShow: A boolean value that determines whether to display the placeholder.
    ///   - alignment: The alignment of the placeholder view within the parent view. (default: .leading)
    ///   - placeholder: A `ViewBuilder` closure that defines the content of the placeholder view.
    /// - Returns: A modified view with a conditional placeholder.
    func placeholder(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> some View
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
