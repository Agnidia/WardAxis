//
//  SecondaryButtonStyle.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Secondary Button Style

/// Outlined secondary action button with border.
/// Supports base, loading, complete, pressed, and disabled states.
///
/// Usage:
/// ```swift
/// Button("Cancel") {}
///     .buttonStyle(.secondary(state: .base))
/// ```
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    private let state: ButtonState
    
    private let isFullWidth: Bool
    
    private let isIconOnly: Bool
    
    private let backgroundType: ButtonBackgroundType
    
    init(state: ButtonState = .base, isFullWidth: Bool = false, isIconOnly: Bool = false, backgroundType: ButtonBackgroundType = .blurred) {
        self.state = state
        self.isFullWidth = isFullWidth
        self.isIconOnly = isIconOnly
        self.backgroundType = backgroundType
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .buttonLarge()
            .dynamicTypeSize(.xSmall ... .xxxLarge)
            .foregroundStyle(labelColor(isPressed: configuration.isPressed))
            .padding(.horizontal, ButtonPadding.horizontal(isIconOnly: isIconOnly))
            .padding(.vertical, ButtonPadding.vertical)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background {
                Color.Button.Background.Secondary.default
                    .blur(radius: backgroundType == .blurred ? .blurRadius.xl : .zero)
                    .clipShape(.pill)
            }
            .clipShape(.pill)
            .padding(.border.thin)
            .overlay {
                RoundedRectangle.pill
                    .inset(by: .border.primary.half)
                    .stroke(borderColor(isPressed: configuration.isPressed), lineWidth: .lineWidth.thin)
                    .shimmerEffect(
                        colors: [.Button.Background.Primary.loading, .Background.secondary, .Button.Background.Primary.loading],
                        isEnabled: state.isLoading,
                        isAnimated: state.isLoading,
                        mask: RoundedRectangle.pill
                            .inset(by: .border.primary.half)
                            .stroke(lineWidth: .lineWidth.thin)
                    )
            }
            .animation(.quick, value: configuration.isPressed)
            .animation(.standard, value: state)
    }
    
    private static let border = ButtonPalette(
        disabled: .Button.Background.Secondary.Border.disabled,
        loading: .Button.Background.Secondary.Border.loading,
        pressed: .Button.Background.Secondary.Border.pressed,
        normal: .Button.Background.Secondary.Border.default
    )
    
    private static let label = ButtonPalette(
        disabled: .Button.Label.Secondary.disabled,
        loading: .Button.Label.Secondary.loading,
        pressed: .Button.Label.Secondary.pressed,
        normal: .Button.Label.Secondary.default
    )
    
    private func borderColor(isPressed: Bool) -> Color {
        state.color(Self.border, isEnabled: isEnabled, isPressed: isPressed)
    }
    
    private func labelColor(isPressed: Bool) -> Color {
        state.color(Self.label, isEnabled: isEnabled, isPressed: isPressed)
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == SecondaryButtonStyle {
    /// Secondary button style with state
    static func secondary(state: ButtonState = .base, isFullWidth: Bool = false, backgroundType: ButtonBackgroundType = .blurred) -> SecondaryButtonStyle {
        SecondaryButtonStyle(state: state, isFullWidth: isFullWidth, backgroundType: backgroundType)
    }
    
    /// Secondary icon-only button style with state
    static func secondaryIconOnly(state: ButtonState = .base, backgroundType: ButtonBackgroundType = .blurred) -> SecondaryButtonStyle {
        SecondaryButtonStyle(state: state, isIconOnly: true, backgroundType: backgroundType)
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Secondary Button States") {
    VStack(spacing: 16) {
        Button("Continue") {}
            .buttonStyle(.secondary())
        
        Button("Loading...") {}
            .buttonStyle(.secondary(state: .loading))
        
        Button("Done") {}
            .buttonStyle(.secondary(state: .complete))
        
        Button("Disabled") {}
            .buttonStyle(.secondary())
            .disabled(true)
        
        Button("Continue") {}
            .buttonStyle(.secondary())
            .debugBackground()
    }
    .padding()
    .background(Color.Background.primary)
}

#endif
