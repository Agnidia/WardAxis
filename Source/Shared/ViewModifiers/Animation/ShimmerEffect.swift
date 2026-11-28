//
//  ShimmerEffect.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Shimmer Effect Modifier

/// Animated shimmer gradient overlay for loading states.
/// Uses `isEnabled` to control whether shimmer is visible.
/// Uses `isAnimated` to control whether the shimmer animates or stays static.
struct ShimmerEffectModifier<MaskShape: Shape>: ViewModifier {
    let colors: [Color]
    let isEnabled: Bool
    let isAnimated: Bool
    let maskShape: MaskShape?
    
    @State private var startPoint: UnitPoint = .init(x: -1, y: 0.5)
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isEnabled {
                    shimmerGradient
                }
            }
    }
    
    @ViewBuilder
    private var shimmerGradient: some View {
        let gradient = LinearGradient(
            colors: colors,
            startPoint: isAnimated ? startPoint : .init(x: 0, y: 0.5),
            endPoint: isAnimated ? .init(x: startPoint.x + 1, y: 0.5) : .init(x: 1, y: 0.5)
        )
        .onAppear {
            if isAnimated {
                withAnimation(.linear(duration: AnimationDuration.shimmer).repeatForever(autoreverses: false)) {
                    startPoint = .init(x: 2, y: 0.5)
                }
            }
        }
        
        if let maskShape {
            gradient.mask { maskShape }
        } else {
            gradient
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies an animated shimmer gradient overlay.
    /// - Parameters:
    ///   - colors: Gradient colors for the shimmer effect
    ///   - isEnabled: Controls whether shimmer is visible
    ///   - isAnimated: Controls whether shimmer animates (default: true)
    func shimmerEffect(colors: [Color], isEnabled: Bool, isAnimated: Bool = true) -> some View {
        modifier(ShimmerEffectModifier<Rectangle>(colors: colors, isEnabled: isEnabled, isAnimated: isAnimated, maskShape: nil))
    }
    
    /// Applies an animated shimmer gradient overlay with a mask shape.
    /// - Parameters:
    ///   - colors: Gradient colors for the shimmer effect
    ///   - isEnabled: Controls whether shimmer is visible
    ///   - isAnimated: Controls whether shimmer animates (default: true)
    ///   - mask: Shape to mask the shimmer effect (e.g., stroke for border-only effect)
    func shimmerEffect(colors: [Color], isEnabled: Bool, isAnimated: Bool = true, mask: some Shape) -> some View {
        modifier(ShimmerEffectModifier(colors: colors, isEnabled: isEnabled, isAnimated: isAnimated, maskShape: mask))
    }
}
