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
    
    private var paddingHorizontal: CGFloat {
        isIconOnly ? (.padding.m - .padding.xxs) : .padding.xl
    }
    
    private var paddingVertical: CGFloat {
        .padding.m - .padding.xxs
    }
    
    private var isLoading: Bool {
        state == .loading
    }
    
    private var isComplete: Bool {
        state == .complete
    }
    
    private var showShimmer: Bool {
        state != .base
    }
    
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
            .padding(.horizontal, paddingHorizontal)
            .padding(.vertical, paddingVertical)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .clipped()
            .background {
                backgroundColor(isPressed: configuration.isPressed)
                    .shimmerEffect(
                        colors: [.Button.Background.Primary.loading, .Brand.primary, .Button.Background.Primary.loading],
                        isEnabled: isLoading,
                        isAnimated: isLoading
                    )
                    .clipShape(RoundedRectangle(cornerRadius: .radius.xxxl))
            }
            .padding(Border.thin)
            .background {
                Color.Button.Background.Primary.Border.default
                    .clipShape(RoundedRectangle(cornerRadius: .radius.xxxl))
            }
            .clipShape(RoundedRectangle(cornerRadius: .radius.xxxl))
            .animation(.easeInOut(duration: AnimationDuration.fast), value: configuration.isPressed)
            .animation(.easeInOut(duration: AnimationDuration.normal), value: state)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if !isEnabled { .Button.Background.Primary.disabled }
        else if showShimmer { .Button.Background.Primary.loading }
        else if isPressed { .Button.Background.Primary.pressed }
        else { .Button.Background.Primary.default }
    }
    
    private func labelColor(isPressed: Bool) -> Color {
        if !isEnabled { .Button.Label.Primary.disabled }
        else if showShimmer { .Button.Label.Primary.loading }
        else if isPressed { .Button.Label.Primary.pressed }
        else { .Button.Label.Primary.default }
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

#if DEBUG

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
