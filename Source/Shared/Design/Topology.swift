//
//  Topology.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Topology Design System

// Semantic spacing and dimension tokens following t-shirt sizing convention

/// Animation duration tokens
enum AnimationDuration {
    /// 0.1s - Ultra fast animations
    static let ultraFast: CGFloat = 0.1
    /// 0.2s - Fast animations
    static let fast: CGFloat = 0.2
    /// 0.3s - Default animation speed
    static let normal: CGFloat = 0.3
    /// 0.6s - Slow animations
    static let slow: CGFloat = 0.6
    /// 1.0s - Ultra slow animations
    static let ultraSlow: CGFloat = 1.0
    /// 0s - Without animation
    static let zero: CGFloat = .zero
}

/// Delay tokens for sequenced animations
enum Delay {
    /// Minimal delay after ultra-fast animation
    static let ultraShort: CGFloat = AnimationDuration.ultraFast + 0.005
    /// Short delay after fast animation
    static let short: CGFloat = AnimationDuration.fast + 0.005
    /// Default delay after normal animation
    static let normal: CGFloat = AnimationDuration.normal + 0.005
    /// Longer delay for emphasis
    static let long: CGFloat = AnimationDuration.normal + 0.1
    /// Double duration delay
    static let ultraLong: CGFloat = AnimationDuration.normal * 2
    /// Quadruple duration delay
    static let extraLong: CGFloat = AnimationDuration.normal * 4
}

/// Scale effect tokens for interactive animations
enum Scale {
    /// 1.025x - Subtle hover lift (macOS)
    static let hoverLift: CGFloat = 1.025
    /// 1.01x - tvOS focus scale
    static let focusLift: CGFloat = 1.01
    /// 1.0x - unfocus scale
    static let unfocuse: CGFloat = 1.0
}

/// Distance tokens for swipe thresholds and gesture recognition
enum Distance {
    /// 25pt - Short swipe threshold for quick interactions
    static let short: CGFloat = 25
    /// 50pt - Medium swipe threshold for standard gestures
    static let medium: CGFloat = 50
    /// 100pt - Long swipe threshold for intentional actions
    static let long: CGFloat = 100
}

/// Shadow tokens for elevation effects
enum Shadow {
    /// 12pt - Hover shadow radius
    static let hoverRadius: CGFloat = 12
    /// 4pt - Hover shadow Y offset
    static let hoverY: CGFloat = 4
}

// MARK: - Convenience Extensions

extension CGFloat {
    /// Spacing tokens namespace
    enum spacing {
        /// 1pt - Ultra-thin spacing for hairline separators
        static let xxs: CGFloat = 1
        /// 2pt - Extra small spacing for tight layouts
        static let xs: CGFloat = 2
        /// 4pt - Small spacing for compact elements
        static let s: CGFloat = 4
        /// 8pt - Medium spacing (default)
        static let m: CGFloat = 6
        /// 8pt - Medium-large spacing
        static let l: CGFloat = 8
        /// 10pt - Large spacing for section gaps
        static let xl: CGFloat = 10
        /// 12pt - Extra large spacing
        static let xxl: CGFloat = 12
        /// 26pt - Huge spacing for major sections
        static let xxxl: CGFloat = 16
        /// 20pt - Maximum spacing for prominent gaps
        static let xxxxl: CGFloat = 20
    }
    
    enum padding {
        /// 1pt - Ultra-thin padding for hairline separators
        static let xxs: CGFloat = 1
        /// 2pt - Extra small padding for tight layouts
        static let xs: CGFloat = 2
        /// 4pt - Small padding for compact elements
        static let s: CGFloat = 4
        /// 8pt - Medium padding (default)
        static let m: CGFloat = 8
        /// 12pt - Medium-large padding
        static let l: CGFloat = 12
        /// 16pt - Large padding for section gaps
        static let xl: CGFloat = 16
        /// 24pt - Extra large padding
        static let xxl: CGFloat = 24
        /// 32pt - Huge padding for major sections
        static let xxxl: CGFloat = 32
        /// 48pt - Maximum padding for prominent gaps
        static let xxxxl: CGFloat = 48
    }
    
    /// Radius tokens namespace
    enum radius {
        /// 2pt - Subtle rounding
        static let xs: CGFloat = 2
        /// 4pt - Small radius for chips/tags
        static let s: CGFloat = 4
        /// 8pt - Medium radius for cards
        static let m: CGFloat = 8
        /// 16pt - Default radius
        static let l: CGFloat = 16
        /// 24pt - Large radius for modals
        static let xl: CGFloat = 24
        /// 32pt - Extra large radius
        static let xxl: CGFloat = 32
        /// 48pt - Pill/capsule shapes
        static let xxxl: CGFloat = 48
    }
    
    /// Blur radius tokens
    enum blurRadius {
        /// 1pt - Hairline blur
        static let xxs: CGFloat = 1
        /// 4pt - Subtle blur
        static let xs: CGFloat = 4
        /// 8pt - Subtle blur
        static let s: CGFloat = 8
        /// 16pt - Default blur
        static let m: CGFloat = 16
        /// 32pt - Heavy blur
        static let l: CGFloat = 32
        /// 40pt - Extra heavy blur
        static let xl: CGFloat = 40
    }
}

extension Double {
    /// Opacity tokens (0.0 - 1.0)
    enum opacity {
        /// Fully transparent
        static let transparent: CGFloat = 0.0
        /// 10% opacity - Very faint
        static let faint: CGFloat = 0.1
        /// 20% opacity - Light overlay
        static let light: CGFloat = 0.2
        /// 30% opacity - Subtle
        static let subtle: CGFloat = 0.3
        /// 40% opacity - Medium-light
        static let mediumLight: CGFloat = 0.4
        /// 50% opacity - Half
        static let medium: CGFloat = 0.5
        /// 60% opacity - Medium-strong
        static let mediumStrong: CGFloat = 0.6
        /// 70% opacity - Strong
        static let strong: CGFloat = 0.7
        /// 80% opacity - Very strong
        static let veryStrong: CGFloat = 0.8
        /// 90% opacity - Nearly opaque
        static let nearlyOpaque: CGFloat = 0.9
        /// 99% opacity - Almost fully opaque
        static let almostOpaque: CGFloat = 0.99
        /// Fully opaque
        static let opaque: CGFloat = 1.0
    }
}

/// Icon size tokens
enum IconSize {
    /// 8pt - Tiny indicators
    static let xs: CGFloat = 8
    /// 16pt - Small icons
    static let s: CGFloat = 16
    /// 32pt - Default icon size
    static let m: CGFloat = 32
    /// 48pt - Large icons
    static let l: CGFloat = 48
    /// 64pt - Extra large icons
    static let xl: CGFloat = 64
    /// 128pt - Hero icons
    static let xxl: CGFloat = 128
}

/// Button size tokens
enum ButtonSize {
    /// 24pt - Compact buttons
    static let s: CGFloat = 24
    /// 48pt - Default button size
    static let m: CGFloat = 48
    /// 64pt - Large buttons
    static let l: CGFloat = 64
    /// 128pt - Hero buttons
    static let xl: CGFloat = 128
}

/// Grid item size tokens
enum GridSize {
    /// 128pt - Default grid item
    static let m: CGFloat = 128
    /// 256pt - Large grid item
    static let l: CGFloat = 256
}

/// Text field dimension tokens
enum TextFieldSize {
    /// 40pt - Default text field height
    static let height: CGFloat = 40
}

/// Button border width tokens
enum Border {
    /// 4pt - Primary button border
    static let primary: CGFloat = 4
    /// 2pt - Secondary button border
    static let secondary: CGFloat = 2
    /// 1pt - Thin border for input fields
    static let thin: CGFloat = 1
}

/// Button background appearance type
enum ButtonBackgroundType: Sendable {
    /// Solid background color without blur
    case solid
    /// Blurred background with default blur radius
    case blurred
    /// Transparency (white.0001) background color without blur
    case clear
}

/// Icon badge container sizes for empty states, status and feature highlights
enum IconBadgeSize {
    /// 44pt - Standard touch target badge
    static let s: CGFloat = 44
    /// 80pt - Medium emphasis badge
    static let m: CGFloat = 80
    /// 120pt - Large emphasis badge (empty and status screens)
    static let l: CGFloat = 120
    /// 160pt - Hero badge (welcome, splash)
    static let xl: CGFloat = 160
}

/// Form control dimension tokens
enum FormSize {
    /// 4pt - Outer padding around form container
    static let outerPadding: CGFloat = .padding.xs
    /// 11pt - Vertical padding inside input field
    static let innerPaddingVertical: CGFloat = .spacing.l - 1
    /// 14pt - Horizontal padding inside input field
    static let innerPaddingHorizontal: CGFloat = .spacing.l + 2
    /// 16pt - Outer container corner radius
    static let outerRadius: CGFloat = .radius.l
    /// 12pt - Inner input field corner radius
    static let innerRadius: CGFloat = .radius.l - 2
    /// 1pt - Border width for input fields
    static let borderWidth: CGFloat = Border.thin
    /// 56pt - Digit code input size (width and height)
    static let digitCodeSize: CGFloat = 56
    /// 48pt - Search field height
    static let searchHeight: CGFloat = 48
    /// 44pt - Toggle row height
    static let toggleHeight: CGFloat = 44
    /// 48pt - Menu page row height
    static let menuRowHeight: CGFloat = 48
    /// 16pt - Color swatch diameter
    static let colorSwatchSize: CGFloat = 16
}

/// Cart / counter badge dimension tokens
enum BadgeSize {
    /// 18pt - Single-digit cart/counter badge (min size)
    static let s: CGFloat = 18
    /// 22pt - Two-digit cart/counter badge
    static let m: CGFloat = 22
}

/// Carousel page-dot dimension tokens
enum CarouselDotSize {
    /// 6pt - Inactive dot
    static let inactive: CGFloat = 6
    /// 8pt - Active dot (matches IconSize.xs)
    static let active: CGFloat = IconSize.xs
}

/// Alert dimension tokens
enum AlertSize {
    /// 8pt - Banner alert corner radius
    static let bannerRadius: CGFloat = .radius.m
    /// 16pt - Horizontal padding for banner alerts
    static let bannerPaddingH: CGFloat = .padding.m
    /// 12pt - Vertical padding for banner alerts
    static let bannerPaddingV: CGFloat = .spacing.l
    /// 16pt - Vertical padding for accent alerts
    static let accentPaddingV: CGFloat = .padding.m
    /// 16pt - Icon size in banner alerts
    static let iconSize: CGFloat = IconSize.s
    /// 4pt - Outer halo container padding
    static let bannerHaloPadding: CGFloat = .spacing.s
    /// 16pt - Outer halo container corner radius
    static let bannerHaloRadius: CGFloat = .radius.l
}
