//
//  AccentAlert.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Accent Alert

/// Full-width alert displayed at the top of the screen.
///
/// Two visual styles:
/// - **Accent**: Dark navy background for neutral/loading states
/// - **Alert**: Orange background for warnings/errors
///
/// Usage:
/// ```swift
/// AccentAlert(message: "Loading...", style: .accent, isLoading: true)
/// AccentAlert(message: "Connection lost", style: .alert)
/// ```
struct AccentAlert: View {
    // MARK: - Style
    
    /// The visual style of the accent alert.
    enum Style: Sendable {
        /// Dark navy background (default/loading)
        case accent
        /// Orange background (warning/error)
        case alert
    }
    
    // MARK: - Properties
    
    let message: String
    let style: Style
    let isLoading: Bool
    let onTap: Closure.EmptyBlock?
    
    // MARK: - Initialization
    
    init(message: String,
         style: Style = .accent,
         isLoading: Bool = false,
         onTap: Closure.EmptyBlock? = nil)
    {
        self.message = message
        self.style = style
        self.isLoading = isLoading
        self.onTap = onTap
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: .spacing.m) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(labelColor)
                .scaleEffect(0.8)
                .isHidden(!isLoading)
            
            Text(message)
                .bodySmall()
                .foregroundStyle(labelColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AlertSize.accentPaddingV)
        .padding(.horizontal, .padding.xxl)
        .background(backgroundColor)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityHint(onTap != nil ? AccessibilityHint.dismiss : "")
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        switch style {
        case .accent: .Background.primary
        case .alert: .State.accent
        }
    }
    
    private var labelColor: Color {
        switch style {
        case .accent: .Label.primary
        case .alert: .Label.secondary
        }
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Accent Alert - Dark") {
    VStack(spacing: .zero) {
        AccentAlert(message: "Text", style: .accent, isLoading: true)
        
        Spacer()
    }
    .background(Color.Background.primary)
}

#Preview("Accent Alert - Orange") {
    VStack(spacing: .zero) {
        AccentAlert(
            message: "Please ensure you're connected to the internet",
            style: .alert
        )
        
        Spacer()
    }
    .background(Color.Background.primary)
}

#Preview("Accent Alert States") {
    VStack(spacing: .spacing.xxxl) {
        AccentAlert(message: "Loading...", style: .accent, isLoading: true)
        
        AccentAlert(message: "Processing your request", style: .accent)
        
        AccentAlert(
            message: "Please ensure you're connected to the internet",
            style: .alert
        )
        
        AccentAlert(message: "Connection lost", style: .alert, isLoading: true)
    }
}

#endif
