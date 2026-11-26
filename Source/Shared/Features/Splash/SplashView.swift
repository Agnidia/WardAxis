//
//  SplashView.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

/// Animated welcome screen showcasing localized strings and reduce motion support.
///
/// Demonstrates:
/// - `L.Splash.*` localized strings
/// - `reduceMotionAnimation()` for accessibility
/// - Topology design tokens for spacing and sizing
///
/// Example:
/// ```swift
/// SplashView {
///     coordinator.completeSplash()
/// }
/// ```
@MainActor
struct SplashView: View {
    /// Closure called when splash animation completes.
    var onComplete: Closure.EmptyBlock?
    
    @State private var logoScale: CGFloat = Scale.x0_75
    @State private var contentOpacity: CGFloat = .zero
    
    private let logger = Log(category: .ui)
    
    var body: some View {
        VStack(spacing: CGFloat.spacing.xxl) {
            Spacer()
            
            logoView
            textContent
            
            Spacer()
            Spacer()
        }
        .padding(CGFloat.padding.xl)
        .onAppear {
            logger.debug("SplashView appeared")
            startAnimations()
        }
    }
    
    // MARK: - Subviews
    
    private var logoView: some View {
        Image(systemName: "app.badge.checkmark")
            .font(.system(size: IconSize.xxl))
            .foregroundStyle(.tint)
            .scaleEffect(logoScale)
            .accessibleDecorativeImage()
            .reduceMotionAnimation(
                Animation.easeOut(duration: AnimationDuration.slow),
                value: logoScale,
                reducedAnimation: nil
            )
    }
    
    private var textContent: some View {
        VStack(spacing: CGFloat.spacing.m) {
            Text(L.Splash.title)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(L.Splash.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .opacity(contentOpacity)
        .accessibilityElement(children: .combine)
        .reduceMotionAnimation(
            Animation.easeIn(duration: AnimationDuration.normal).delay(Delay.short),
            value: contentOpacity,
            reducedAnimation: nil
        )
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        logoScale = Scale.base
        contentOpacity = Double.opacity.opaque
        
        // Complete splash after animations finish
        Task {
            try? await Task.sleep(for: .seconds(AnimationDuration.slow + Delay.long))
            onComplete?()
        }
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG
#Preview {
    SplashView()
}
#endif
