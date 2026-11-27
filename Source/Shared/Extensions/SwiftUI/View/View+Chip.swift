//
//  View+Chip.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

extension View {
    /// The inset of a tappable chip or tag pill.
    func chipPadding() -> some View {
        padding(.horizontal, .spacing.xl)
            .padding(.vertical, .spacing.m)
    }
    
    /// The tighter inset of a read-only badge inside a row.
    func badgePadding() -> some View {
        padding(.horizontal, .spacing.m)
            .padding(.vertical, .spacing.xs)
    }
    
    /// A centred, secondary line that stands in for absent content: an empty
    /// list, an error detail, an unsupported platform.
    func placeholderMessage() -> some View {
        foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, .padding.l)
    }
}
