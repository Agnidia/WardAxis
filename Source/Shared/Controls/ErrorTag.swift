//
//  ErrorTag.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Error Tag

/// Inline error message display with warning soft background.
///
/// Matches design system: rounded corners, warning soft background,
/// warning text color, uppercase text style.
///
/// Usage:
/// ```swift
/// ErrorTag(message: "Invalid code")
/// ```
struct ErrorTag: View {
    let message: String
    
    var body: some View {
        Text(message.uppercased())
            .bodyAlertSmall()
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.Text.white)
            .padding(.spacing.m)
            .frame(maxWidth: .infinity)
            .background(Color.State.error)
            .clipShape(RoundedRectangle(cornerRadius: FormSize.innerRadius))
            .accessibilityLabel(message)
            .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Preview

#if DEBUG

#Preview("Error Tag") {
    VStack(spacing: 16) {
        ErrorTag(message: "Invalid code")
        ErrorTag(message: "Phone number is required")
        ErrorTag(message: "Please enter a valid email address")
        
        ErrorTag(message: "Please enter a valid email address and bla bla bla long text")
    }
    .padding()
    .frame(maxWidth: 400, maxHeight: .infinity)
    .background(Color.Background.primary)
}

#endif
