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
    
    private var paddingHorizontal: CGFloat {
        isIconOnly ? (.padding.m - .padding.xxs) : .padding.xl
    }
    
    private var paddingVertical: CGFloat {
        .padding.m - .padding.xxs
    }
    
    private var isLoading: Bool {
        state == .loading
    }
    
    private var showShimmer: Bool {
        state != .base
    }
    
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
            .padding(.horizontal, paddingHorizontal)
            .padding(.vertical, paddingVertical)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background {
                Color.Button.Background.Secondary.default
                    .blur(radius: backgroundType == .blurred ? .blurRadius.xl : .zero)
                    .clipShape(RoundedRectangle(cornerRadius: .radius.xxxl))
            }
            .clipShape(RoundedRectangle(cornerRadius: .radius.xxxl))
            .padding(Border.thin)
            .overlay {
                RoundedRectangle(cornerRadius: .radius.xxxl)
                    .inset(by: Border.primary.half)
                    .stroke(borderColor(isPressed: configuration.isPressed), lineWidth: Border.thin)
                    .shimmerEffect(
                        colors: [.Button.Background.Primary.loading, .Brand.primary, .Button.Background.Primary.loading],
                        isEnabled: isLoading,
                        isAnimated: isLoading,
                        mask: RoundedRectangle(cornerRadius: .radius.xxxl)
                            .inset(by: Border.primary.half)
                            .stroke(lineWidth: Border.thin)
                    )
            }
            .animation(.easeInOut(duration: AnimationDuration.fast), value: configuration.isPressed)
            .animation(.easeInOut(duration: AnimationDuration.normal), value: state)
    }
    
    private func borderColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return .Button.Background.Secondary.Border.disabled
        }
        if showShimmer {
            return .Button.Background.Secondary.Border.loading
        }
        if isPressed {
            return .Button.Background.Secondary.Border.pressed
        }
        return .Button.Background.Secondary.Border.default
    }
    
    private func labelColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return .Button.Label.Secondary.disabled
        }
        if showShimmer {
            return .Button.Label.Secondary.loading
        }
        if isPressed {
            return .Button.Label.Secondary.pressed
        }
        return .Button.Label.Secondary.default
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
