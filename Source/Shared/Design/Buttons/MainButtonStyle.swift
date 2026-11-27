//
//  MainButtonStyle.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Primary Button Style

/// Full-width primary action button with filled background.
/// Supports base, loading, complete, pressed, and disabled states.
///
/// Usage:
/// ```swift
/// Button("Continue") {}
///     .buttonStyle(.main(state: .base, isFullWidth: true))
/// ```
struct MainButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    private let state: ButtonState
    
    private let isFullWidth: Bool
    
    private let isIconOnly: Bool
    
    init(state: ButtonState = .base, isFullWidth: Bool = false, isIconOnly: Bool = false) {
        self.state = state
        self.isFullWidth = isFullWidth
        self.isIconOnly = isIconOnly
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .buttonLarge()
            .dynamicTypeSize(.xSmall ... .xxxLarge)
            .foregroundStyle(labelColor(isPressed: configuration.isPressed))
            .padding(.horizontal, ButtonPadding.horizontal(isIconOnly: isIconOnly))
            .padding(.vertical, ButtonPadding.vertical)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .clipped()
            .background {
                backgroundColor(isPressed: configuration.isPressed)
                    .shimmerEffect(
                        colors: [.Button.Background.Primary.loading, .Background.primary, .Button.Background.Primary.loading],
                        isEnabled: state.isLoading,
                        isAnimated: state.isLoading
                    )
                    .clipShape(.pill)
            }
            .padding(.border.thin)
            .background {
                Color.Button.Background.Primary.Border.default
                    .clipShape(.pill)
            }
            .clipShape(.pill)
            .animation(.quick, value: configuration.isPressed)
            .animation(.standard, value: state)
    }
    
    private static let background = ButtonPalette(
        disabled: .Button.Background.Primary.disabled,
        loading: .Button.Background.Primary.loading,
        pressed: .Button.Background.Primary.pressed,
        normal: .Button.Background.Primary.default
    )
    
    private static let label = ButtonPalette(
        disabled: .Button.Label.Primary.disabled,
        loading: .Button.Label.Primary.loading,
        pressed: .Button.Label.Primary.pressed,
        normal: .Button.Label.Primary.default
    )
    
    private func backgroundColor(isPressed: Bool) -> Color {
        state.color(Self.background, isEnabled: isEnabled, isPressed: isPressed)
    }
    
    private func labelColor(isPressed: Bool) -> Color {
        state.color(Self.label, isEnabled: isEnabled, isPressed: isPressed)
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == MainButtonStyle {
    /// Primary button style with state
    static func main(state: ButtonState = .base, isFullWidth: Bool = false) -> MainButtonStyle {
        MainButtonStyle(state: state, isFullWidth: isFullWidth)
    }
    
    /// Primary icon-only button style with state
    static func mainIconOnly(state: ButtonState = .base) -> MainButtonStyle {
        MainButtonStyle(state: state, isIconOnly: true)
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Primary Button States") {
    VStack(spacing: 16) {
        Button("Continue") {}
            .buttonStyle(.main())
        
        Button("Loading...") {}
            .buttonStyle(.main(state: .loading))
        
        Button("Done") {}
            .buttonStyle(.main(state: .complete))
        
        Button("Disabled") {}
            .buttonStyle(.main())
            .disabled(true)
        
        Button("Full Width") {}
            .buttonStyle(.main(isFullWidth: true))
        
        Button("Full Width Loading") {}
            .buttonStyle(.main(state: .loading, isFullWidth: true))
        
        Button("Continue") {}
            .buttonStyle(.main())
            .debugBackground()
    }
    .padding()
    .background(Color.Background.primary)
}

#endif
