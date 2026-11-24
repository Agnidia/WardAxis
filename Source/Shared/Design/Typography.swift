//
//  Typography.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Typography System

/// Semantic text styles for consistent typography across the app.
enum Typography {
    // MARK: - Display
    
    /// Large display text - splash screens, hero sections (40pt editorial, 110% line height)
    case titleLarge
    /// Display title (32pt editorial, 110% line height)
    case title
    /// Small display text - labels and tags (16pt mono uppercase, 110% line height)
    case titleSmall
    
    // MARK: - Heading
    
    /// Primary heading - screen titles (26pt editorial, 105% line height)
    case subtitleLarge
    /// Secondary heading - section titles (20pt editorial, 105% line height)
    case subtitleSmall
    
    // MARK: - Body
    
    /// Large body text - featured content (16pt sans, 150% line height)
    case bodyLarge
    /// Standard body text - primary content (14pt sans, 140% line height)
    case body
    /// Monospace body text - codes, technical (14pt mono uppercase, 140% line height)
    case bodyMono
    /// Serif body text - elegant content (14pt editorial, 105% line height)
    case bodySerif
    /// Small body text - supporting content (12pt mono uppercase, 100% line height)
    case bodySmall
    /// Small alert body text - sans-serif variant (12pt sans uppercase, 100% line height)
    case bodyAlertSmall
    
    // MARK: - Label
    
    /// Regular label - non-bold mono labels (16pt mono, 100% line height)
    case labelRegular
    /// Large label - digit codes, prominent labels (24pt mono, 100% line height)
    case labelLarge
    /// Bold label - emphasized labels (16pt mono bold, 100% line height)
    case labelBold
    /// Small label - captions, tags (12pt mono bold, 100% line height)
    case labelSmall
    
    // MARK: - Button
    
    /// Large button text - uppercase (16pt mono, 100% line height)
    case buttonLarge
    /// Large tertiary button text (16pt mono, -2% tracking, 100% line height)
    case buttonLargeTertiary
    /// Medium button text - title case (16pt mono, 100% line height)
    case buttonMedium
    /// Small button text - uppercase (12pt mono, 100% line height)
    case buttonSmall
    
    // MARK: - Font Properties
    
    /// The font for this typography style
    var font: Font {
        switch self {
        case .titleLarge: .editorial(size: FontSize.titleLarge)
        case .title: .editorial(size: FontSize.title)
        case .titleSmall: .mono(size: FontSize.titleSmall)
        case .subtitleLarge: .editorial(size: FontSize.subtitleLarge)
        case .subtitleSmall: .editorial(size: FontSize.subtitleSmall)
        case .bodyLarge: .flex(size: FontSize.bodyLarge)
        case .body: .flex(size: FontSize.body)
        case .bodyMono: .mono(size: FontSize.body)
        case .bodySerif: .editorial(size: FontSize.body)
        case .bodySmall: .mono(size: FontSize.bodySmall)
        case .bodyAlertSmall: .flex(size: FontSize.bodySmall)
        case .labelLarge: .mono(size: FontSize.labelXL)
        case .labelBold: .mono(size: FontSize.labelLarge, weight: .bold)
        case .labelSmall: .mono(size: FontSize.label, weight: .bold)
        case .labelRegular, .buttonLarge, .buttonLargeTertiary: .mono(size: FontSize.buttonLarge)
        case .buttonMedium: .mono(size: FontSize.buttonLarge)
        case .buttonSmall: .mono(size: FontSize.buttonSmall)
        }
    }
    
    /// The font size for this typography style
    var size: CGFloat {
        switch self {
        case .titleLarge: FontSize.titleLarge
        case .title: FontSize.title
        case .titleSmall: FontSize.titleSmall
        case .subtitleLarge: FontSize.subtitleLarge
        case .subtitleSmall: FontSize.subtitleSmall
        case .bodyLarge: FontSize.bodyLarge
        case .body, .bodyMono, .bodySerif: FontSize.body
        case .bodySmall, .bodyAlertSmall: FontSize.bodySmall
        case .labelLarge: FontSize.labelXL
        case .labelBold: FontSize.labelLarge
        case .labelSmall: FontSize.label
        case .labelRegular: FontSize.labelLarge
        case .buttonLarge, .buttonLargeTertiary, .buttonMedium: FontSize.buttonLarge
        case .buttonSmall: FontSize.buttonSmall
        }
    }
    
    /// The line height multiplier for this typography style
    var lineHeight: CGFloat {
        switch self {
        case .titleLarge, .title, .titleSmall: LineHeight.display
        case .subtitleLarge, .subtitleSmall: LineHeight.heading
        case .bodyLarge: LineHeight.bodyLarge
        case .body, .bodyMono: LineHeight.body
        case .bodySerif: LineHeight.heading
        case .bodySmall, .bodyAlertSmall, .labelRegular, .labelLarge, .labelBold, .labelSmall: LineHeight.compact
        case .buttonLarge, .buttonLargeTertiary, .buttonMedium, .buttonSmall: LineHeight.compact
        }
    }
    
    /// The letter spacing (tracking) for this typography style
    var tracking: CGFloat {
        switch self {
        case .titleLarge, .buttonLargeTertiary, .title, .subtitleLarge, .subtitleSmall, .bodySerif:
            LetterSpacing.editorial
        case .bodyMono: -LetterSpacing.editorial
        default:
            LetterSpacing.none
        }
    }
    
    /// The text case transformation for this typography style
    var textCase: Text.Case? {
        switch self {
        case .buttonLarge, .buttonSmall, .bodyAlertSmall, .bodyMono, .bodySmall, .titleSmall: .uppercase
        default: nil
        }
    }
    
    /// The frame height for this typography style (from FontHeight tokens)
    var frameHeight: CGFloat {
        switch self {
        case .titleLarge: FontHeight.titleLarge
        case .title: FontHeight.title
        case .titleSmall: FontHeight.titleSmall
        case .subtitleLarge: FontHeight.subtitleLarge
        case .subtitleSmall: FontHeight.subtitleSmall
        case .bodyLarge: FontHeight.bodyLarge
        case .body, .bodyMono: FontHeight.body
        case .bodySerif, .bodySmall, .bodyAlertSmall: FontHeight.bodySmall
        case .labelLarge: FontHeight.labelLarge
        case .labelBold, .labelSmall: FontHeight.label
        case .labelRegular: FontHeight.labelLarge
        case .buttonLarge: FontHeight.buttonLarge
        case .buttonLargeTertiary: FontHeight.buttonLarge
        case .buttonMedium: FontHeight.button
        case .buttonSmall: FontHeight.buttonSmall
        }
    }
}

/// Font size tokens
enum FontSize {
    /// 40pt - Large display text
    static let titleLarge: CGFloat = 40
    /// 32pt - Display title
    static let title: CGFloat = 32
    /// 16pt - Small display text
    static let titleSmall: CGFloat = 16
    /// 26pt - Primary heading (H1)
    static let subtitleLarge: CGFloat = 26
    /// 20pt - Secondary heading (H2)
    static let subtitleSmall: CGFloat = 20
    /// 16pt - Large body text
    static let bodyLarge: CGFloat = 16
    /// 14pt - Default body text
    static let body: CGFloat = 14
    /// 12pt - Small body text
    static let bodySmall: CGFloat = 12
    /// 24pt - Large label (digit codes)
    static let labelXL: CGFloat = 24
    /// 16pt - Large label
    static let labelLarge: CGFloat = 16
    /// 12pt - Default label
    static let label: CGFloat = 12
    /// 16pt - Large/Medium button text
    static let buttonLarge: CGFloat = 16
    /// 12pt - Small button text
    static let buttonSmall: CGFloat = 12
}

/// Line height multipliers
enum LineHeight {
    /// 1.10 (110%) - Display text
    static let display: CGFloat = 1.10
    /// 1.05 (105%) - Headings
    static let heading: CGFloat = 1.05
    /// 1.50 (150%) - Large body text
    static let bodyLarge: CGFloat = 1.50
    /// 1.40 (140%) - Default body text
    static let body: CGFloat = 1.40
    /// 1.30 (130%) - Small body text
    static let bodySmall: CGFloat = 1.30
    /// 1.05 (105%) - Extra body text
    static let bodyExtra: CGFloat = 1.05
    /// 1.00 (100%) - Labels and buttons
    static let compact: CGFloat = 1.00
}

/// Frame-height tokens for typography presets
enum FontHeight {
    /// 44pt - Large display text height
    static let titleLarge: CGFloat = 44
    /// 35pt - Display title height
    static let title: CGFloat = 35
    /// 16pt - Small display text height
    static let titleSmall: CGFloat = 16
    
    /// 27pt - Primary heading (H1) height
    static let subtitleLarge: CGFloat = 27
    /// 20pt - Secondary heading (H2) height
    static let subtitleSmall: CGFloat = 20
    
    /// 20pt - Large body text height
    static let bodyLarge: CGFloat = 20
    /// 20pt - Default body text height
    static let body: CGFloat = 20
    /// 16pt - Small body text height
    static let bodySmall: CGFloat = 16
    
    /// 24pt - Large label (digit codes) height
    static let labelXL: CGFloat = 24
    /// 20pt - Large label height
    static let labelLarge: CGFloat = 20
    /// 16pt - Default label height
    static let label: CGFloat = 16
    
    /// 20pt - Large button text height
    static let buttonLarge: CGFloat = 20
    /// 16pt - Medium button text height
    static let button: CGFloat = 16
    /// 12pt - Small button text height
    static let buttonSmall: CGFloat = 12
}

/// Letter spacing (tracking) tokens
enum LetterSpacing {
    /// -2% tracking for editorial/serif fonts
    static let editorial: CGFloat = -0.02
    /// 0% tracking (no adjustment)
    static let none: CGFloat = 0
}

// MARK: - Typography View Modifier

/// View modifier that applies a semantic typography style
struct TypographyModifier: ViewModifier {
    let style: Typography
    
    func body(content: Content) -> some View {
        content
            .font(style.font)
            .lineSpacing((style.size * style.lineHeight) - style.size)
            .tracking(style.size * style.tracking)
    }
}

extension View {
    /// Applies a semantic typography style to the view.
    func typography(_ style: Typography) -> some View {
        modifier(TypographyModifier(style: style))
    }
}

// MARK: - Text Style Presets

@MainActor
extension View {
    /// Large display text (40pt serif)
    func titleLarge() -> some View {
        textCase(Typography.titleLarge.textCase)
            .typography(.titleLarge)
            .frame(minHeight: Typography.titleLarge.frameHeight)
    }
    
    /// Display title (32pt serif)
    func title() -> some View {
        textCase(Typography.title.textCase)
            .typography(.title)
            .frame(minHeight: Typography.title.frameHeight)
    }
    
    /// Small display text (16pt mono uppercase)
    func titleSmall() -> some View {
        textCase(Typography.titleSmall.textCase)
            .typography(.titleSmall)
            .frame(minHeight: Typography.titleSmall.frameHeight)
    }
    
    /// Primary heading (26pt serif)
    func subtitleLarge() -> some View {
        textCase(Typography.subtitleLarge.textCase)
            .typography(.subtitleLarge)
            .frame(minHeight: Typography.subtitleLarge.frameHeight)
    }
    
    /// Secondary heading (20pt serif)
    func subtitleSmall() -> some View {
        textCase(Typography.subtitleSmall.textCase)
            .typography(.subtitleSmall)
            .frame(minHeight: Typography.subtitleSmall.frameHeight)
    }
    
    /// Standard body text (14pt sans-serif)
    func bodyText() -> some View {
        textCase(Typography.body.textCase)
            .typography(.body)
            .frame(minHeight: Typography.body.frameHeight)
    }
    
    /// Large body text (16pt sans-serif)
    func bodyLarge() -> some View {
        textCase(Typography.bodyLarge.textCase)
            .typography(.bodyLarge)
            .frame(minHeight: Typography.bodyLarge.frameHeight)
    }
    
    /// Monospace body text (14pt mono uppercase)
    func bodyMono() -> some View {
        textCase(Typography.bodyMono.textCase)
            .typography(.bodyMono)
            .frame(minHeight: Typography.bodyMono.frameHeight)
    }
    
    /// Serif body text (14pt serif)
    func bodySerif() -> some View {
        textCase(Typography.bodySerif.textCase)
            .typography(.bodySerif)
            .frame(minHeight: Typography.bodySerif.frameHeight)
    }
    
    /// Small body text (12pt mono uppercase)
    func bodySmall() -> some View {
        textCase(Typography.bodySmall.textCase)
            .typography(.bodySmall)
            .frame(minHeight: Typography.bodySmall.frameHeight)
    }
    
    /// Small alert body text (12pt sans-serif uppercase)
    func bodyAlertSmall() -> some View {
        textCase(Typography.bodyAlertSmall.textCase)
            .typography(.bodyAlertSmall)
            .frame(minHeight: Typography.bodyAlertSmall.frameHeight)
    }
    
    /// Large label (24pt mono)
    func labelLarge() -> some View {
        textCase(Typography.labelLarge.textCase)
            .typography(.labelLarge)
            .frame(minHeight: Typography.labelLarge.frameHeight)
    }
    
    /// Bold label (16pt mono bold)
    func labelBold() -> some View {
        textCase(Typography.labelBold.textCase)
            .typography(.labelBold)
            .frame(minHeight: Typography.labelBold.frameHeight)
    }
    
    /// Regular label (16pt mono)
    func labelRegular() -> some View {
        textCase(Typography.labelRegular.textCase)
            .typography(.labelRegular)
            .frame(minHeight: Typography.labelRegular.frameHeight)
    }
    
    /// Small label (12pt mono bold)
    func labelSmall() -> some View {
        textCase(Typography.labelSmall.textCase)
            .typography(.labelSmall)
            .frame(minHeight: Typography.labelSmall.frameHeight)
    }
    
    /// Large button text (16pt mono uppercase)
    func buttonLarge() -> some View {
        textCase(Typography.buttonLarge.textCase)
            .typography(.buttonLarge)
            .frame(minHeight: Typography.buttonLarge.frameHeight)
    }
    
    /// Large tertiary button text (16pt mono, -2% tracking)
    func buttonLargeTertiary() -> some View {
        textCase(Typography.buttonLargeTertiary.textCase)
            .typography(.buttonLargeTertiary)
            .frame(minHeight: Typography.buttonLargeTertiary.frameHeight)
    }
    
    /// Medium button text (16pt mono, title case)
    func buttonMedium() -> some View {
        textCase(Typography.buttonMedium.textCase)
            .typography(.buttonMedium)
            .frame(minHeight: Typography.buttonMedium.frameHeight)
    }
    
    /// Small button text (12pt mono uppercase)
    func buttonSmall() -> some View {
        textCase(Typography.buttonSmall.textCase)
            .typography(.buttonSmall)
            .frame(minHeight: Typography.buttonSmall.frameHeight)
    }
}
