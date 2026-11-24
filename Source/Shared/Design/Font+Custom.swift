//
//  Font+Custom.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Font Extension

extension Font {
    // MARK: - Editorial (Serif)
    
    /// Serif font for display text and headings.
    /// Uses the system serif design by default.
    /// Override with `.custom(name, size:)` for branded fonts.
    static func editorial(size: CGFloat) -> Font {
        .system(size: size, design: .serif)
    }
    
    // MARK: - Flex (Default)
    
    /// Sans-serif font for body text.
    /// Uses the system default design.
    /// Override with `.custom(name, size:)` for branded fonts.
    static func flex(size: CGFloat) -> Font {
        .system(size: size, design: .default)
    }
    
    // MARK: - Mono (Monospaced)
    
    /// Monospace font for labels and buttons.
    /// - Parameters:
    ///   - size: The font size in points
    ///   - weight: The font weight (default: .regular)
    /// - Returns: A Font configured with monospaced design
    static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Custom Font Registration

//
// To use custom fonts instead of system fonts, uncomment and adapt:
//
// private enum FontName {
//     static let editorial = "YourSerifFont-Regular"
// }
//
// extension Font {
//     static func editorial(size: CGFloat) -> Font {
//         .custom(FontName.editorial, size: size)
//     }
// }
