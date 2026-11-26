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
