//
//  BannerAlert.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Banner Alert

/// Compact pill-shaped alert for status notifications.
///
/// Three variants:
/// - **Info**: Orange background for informational messages
/// - **Error**: Muted red background with X icon
/// - **Success**: Teal/green background with checkmark
///
/// Usage:
/// ```swift
/// BannerAlert(message: "Profile updated successfully", type: .success)
/// BannerAlert(message: "Verification failed", type: .error)
/// ```
struct BannerAlert: View {
    // MARK: - Properties
    
    let message: String
    let type: BannerAlertType
    let onTap: Closure.EmptyBlock?
    
    // MARK: - Initialization
    
    init(message: String, type: BannerAlertType, onTap: Closure.EmptyBlock? = nil) {
        self.message = message
        self.type = type
        self.onTap = onTap
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: .spacing.m) {
            if let systemIcon {
                Image(systemName: systemIcon)
                    .frame(width: AlertSize.iconSize, height: AlertSize.iconSize)
                    .foregroundStyle(labelColor)
            }
            
            Text(message)
                .bodySmall()
                .foregroundStyle(labelColor)
        }
        .padding(.horizontal, AlertSize.bannerPaddingH)
        .padding(.vertical, AlertSize.bannerPaddingV)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: AlertSize.bannerRadius))
        .contentShape(RoundedRectangle(cornerRadius: AlertSize.bannerRadius))
        .onTapGesture {
            onTap?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityHint(onTap != nil ? AccessibilityHint.dismiss : "")
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        switch type {
        case .info: .State.accent
        case .error: .State.warning
        case .success: .State.success
        }
    }
    
    private var labelColor: Color {
        .white
    }
    
    private var systemIcon: String? {
        switch type {
        case .info: nil
        case .error: "xmark.circle"
        case .success: nil
        }
    }
    
    /// Localized as one phrase, so a language can order the type and the message itself.
    private var accessibilityLabel: String {
        switch type {
        case .info: String(localized: "Information: \(message)")
        case .error: String(localized: "Error: \(message)")
        case .success: String(localized: "Success: \(message)")
        }
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Banner Alert - Info") {
    VStack(spacing: .spacing.xxxl) {
        Spacer()
        
        BannerAlert(
            message: "Due to limited stock, we are currently capping this item at 5 per order.",
            type: .info
        )
        
        Spacer()
    }
    .padding()
    .background(Color.Background.primary)
}

#Preview("Banner Alert - Error") {
    VStack(spacing: .spacing.xxxl) {
        Spacer()
        
        BannerAlert(message: "Verification failed", type: .error)
        
        Spacer()
    }
    .padding()
    .background(Color.Background.primary)
}

#Preview("Banner Alert - Success") {
    VStack(spacing: .spacing.xxxl) {
        Spacer()
        
        BannerAlert(message: "Profile updated successfully", type: .success)
        
        Spacer()
    }
    .padding()
    .background(Color.Background.primary)
}

#Preview("Banner Alert - All Types") {
    VStack(spacing: .spacing.xxxl) {
        BannerAlert(
            message: "Due to limited stock, we are currently capping this item at 5 per order.",
            type: .info
        )
        
        BannerAlert(message: "Verification failed", type: .error)
        
        BannerAlert(message: "Profile updated successfully", type: .success)
    }
    .padding()
    .background(Color.Background.primary)
}

#endif
