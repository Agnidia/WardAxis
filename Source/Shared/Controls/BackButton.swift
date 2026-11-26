//
//  BackButton.swift
//
//  Created on 05.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Back Button

/// Reusable back navigation button with a solid secondary icon-only style.
///
/// Dismisses the on-screen keyboard before invoking `action`, so it can be safely
/// used as the leading toolbar item on form screens.
struct BackButton: View {
    let action: Closure.EmptyBlock
    let accessibilityConfig: any AccessibilityProtocol
    
    init(
        accessibility: any AccessibilityProtocol,
        action: @escaping Closure.EmptyBlock
    ) {
        accessibilityConfig = accessibility
        self.action = action
    }
    
    var body: some View {
        Button {
            Keyboard.dismiss()
            action()
        } label: {
            Image(systemName: "chevron.left")
                .frame(width: IconSize.m, height: IconSize.m)
        }
        .buttonStyle(.secondaryIconOnly(backgroundType: .solid))
        .accessible(accessibilityConfig)
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Back Button") {
    VStack(spacing: .spacing.xxl) {
        BackButton(
            accessibility: PreviewBackAccessibility(),
            action: {}
        )
        
        BackButton(
            accessibility: PreviewBackAccessibility(),
            action: {}
        )
        .padding(.padding.s)
        .background(Color.Brand.primary)
        .clipShape(RoundedRectangle(cornerRadius: .radius.m))
    }
    .padding(.padding.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.Background.secondary)
}

private struct PreviewBackAccessibility: AccessibilityProtocol {
    var label: String {
        "Back"
    }
    
    var hint: String {
        "Double tap to navigate back"
    }
    
    var id: String {
        "back-button"
    }
}

#endif
