//
//  ButtonState.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Button State

/// Button interaction state for visual feedback
enum ButtonState: Sendable {
    /// Default state - standard appearance
    case base
    /// Loading state - animated shimmer effect
    case loading
    /// Complete state - static gradient (no animation)
    case complete
}

extension ButtonState {
    /// Only the loading state animates its shimmer.
    var isLoading: Bool {
        self == .loading
    }
    
    /// Loading and complete both show the shimmer colors.
    var showsShimmer: Bool {
        self != .base
    }
    
    /// The color for one part of a button, picked in the order that wins:
    /// disabled, then shimmer, then pressed, then the default.
    func color(_ palette: ButtonPalette, isEnabled: Bool, isPressed: Bool) -> Color {
        if !isEnabled {
            palette.disabled
        } else if showsShimmer {
            palette.loading
        } else if isPressed {
            palette.pressed
        } else {
            palette.normal
        }
    }
}

/// The four colors of one part of a button (label, background or border).
struct ButtonPalette {
    let disabled: Color
    let loading: Color
    let pressed: Color
    let normal: Color
}

/// Padding shared by every button style.
enum ButtonPadding {
    static let vertical: CGFloat = .padding.m - .padding.xxs
    
    static func horizontal(isIconOnly: Bool) -> CGFloat {
        isIconOnly ? vertical : .padding.xl
    }
}
