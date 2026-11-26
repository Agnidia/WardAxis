//
//  TertiaryButtonStyle.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Tertiary Button Style

/// Text-only button without visible border.
/// Supports base, loading, complete, pressed, and disabled states.
///
/// Usage:
/// ```swift
/// Button("Skip") {}
///     .buttonStyle(.tertiary())
/// ```
struct TertiaryButtonStyle: ButtonStyle {
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
            .buttonLargeTertiary()
            .dynamicTypeSize(.xSmall ... .xxxLarge)
            .foregroundStyle(labelColor(isPressed: configuration.isPressed))
            .padding(.horizontal, paddingHorizontal)
            .padding(.vertical, paddingVertical)
            .background {
                Color.Button.Background.Secondary.default
                    .blur(radius: backgroundType == .blurred ? .blurRadius.xl : .zero)
                    .clipShape(RoundedRectangle(cornerRadius: .radius.xxxl))
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(Border.thin)
            .clipShape(RoundedRectangle(cornerRadius: .radius.xxxl))
            .animation(.easeInOut(duration: AnimationDuration.fast), value: configuration.isPressed)
            .animation(.easeInOut(duration: AnimationDuration.normal), value: state)
    }
    
    private func labelColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return .Button.Label.Tertiary.disabled
        }
        if showShimmer {
            return .Button.Label.Tertiary.loading
        }
        if isPressed {
            return .Button.Label.Tertiary.pressed
        }
        return .Button.Label.Tertiary.default
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == TertiaryButtonStyle {
    /// Tertiary button style with state
    static func tertiary(state: ButtonState = .base, isFullWidth: Bool = false, backgroundType: ButtonBackgroundType = .blurred) -> TertiaryButtonStyle {
        TertiaryButtonStyle(state: state, isFullWidth: isFullWidth, backgroundType: backgroundType)
    }
    
    /// Tertiary icon-only button style with state
    static func tertiaryIconOnly(state: ButtonState = .base, backgroundType: ButtonBackgroundType = .blurred) -> TertiaryButtonStyle {
        TertiaryButtonStyle(state: state, isIconOnly: true, backgroundType: backgroundType)
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Tertiary Button States") {
    VStack(spacing: 16) {
        Button("Continue") {}
            .buttonStyle(.tertiary())
        
        Button("Loading...") {}
            .buttonStyle(.tertiary(state: .loading))
        
        Button("Done") {}
            .buttonStyle(.tertiary(state: .complete))
        
        Button("Disabled") {}
            .buttonStyle(.tertiary())
            .disabled(true)
        
        Button("Continue") {}
            .buttonStyle(.tertiary())
            .debugBackground()
    }
    .padding()
    .background(Color.Background.primary)
}

#endif
