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
    let onTap: (() -> Void)?
    
    // MARK: - Initialization
    
    init(
        message: String,
        style: Style = .accent,
        isLoading: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.message = message
        self.style = style
        self.isLoading = isLoading
        self.onTap = onTap
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: .spacing.m) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(labelColor)
                    .scaleEffect(0.8)
            }
            
            Text(message.uppercased())
                .bodySmall()
                .foregroundStyle(labelColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AlertSize.accentPaddingV)
        .padding(.horizontal, .padding.xxl)
        .background(backgroundColor)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityHint(onTap != nil ? "Double tap to dismiss" : "")
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        switch style {
        case .accent: .Brand.primary
        case .alert: .State.accent
        }
    }
    
    private var labelColor: Color {
        switch style {
        case .accent: .white
        case .alert: .white
        }
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Accent Alert - Dark") {
    VStack(spacing: 0) {
        AccentAlert(message: "Text", style: .accent, isLoading: true)
        
        Spacer()
    }
    .background(Color.Background.primary)
}

#Preview("Accent Alert - Orange") {
    VStack(spacing: 0) {
        AccentAlert(
            message: "Please ensure you're connected to the internet",
            style: .alert
        )
        
        Spacer()
    }
    .background(Color.Background.primary)
}

#Preview("Accent Alert States") {
    VStack(spacing: 16) {
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
