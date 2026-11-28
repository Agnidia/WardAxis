//
//  SearchField.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Search Field

/// A pill-shaped search input field matching the design system.
///
/// Features:
/// - Pill shape with blurred background
/// - Search icon on left
/// - Clear button on right when active
/// - State-based border and text colors
///
/// Usage:
/// ```swift
/// SearchField(
///     placeholder: "Search...",
///     text: $searchText,
///     accessibility: AccessibilityID.Search.field
/// )
/// ```
struct SearchField: View {
    // MARK: - Search Field State
    
    /// Visual state of the search field.
    enum SearchFieldState: Sendable {
        /// Default unfocused state with placeholder
        case `default`
        /// Field is focused/pressed
        case pressed
        /// Field has entered text
        case entered
    }
    
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let accessibilityConfig: any AccessibilityProtocol
    
    @FocusState private var isFocused: Bool
    
    /// Creates a search field.
    /// - Parameters:
    ///   - placeholder: The placeholder text
    ///   - text: Binding to the search text
    ///   - accessibility: Accessibility configuration
    init(
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        accessibility: any AccessibilityProtocol
    ) {
        self.placeholder = placeholder
        _text = text
        accessibilityConfig = accessibility
    }
    
    var body: some View {
        HStack(spacing: .spacing.m) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .frame(width: IconSize.m, height: IconSize.m)
                .foregroundStyle(Color.Textfield.text)
                .accessibilityHidden(true)
            
            // Text field
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .bodyText()
                .foregroundStyle(textColor)
                .accentColor(Color.Textfield.text)
                .focused($isFocused)
            
            // Clear button (only when editing)
            if isFocused {
                Button {
                    text = .empty
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: IconSize.s, height: IconSize.s)
                        .foregroundStyle(Color.Textfield.text)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, .spacing.xxl)
        .frame(height: FormSize.searchHeight)
        .background {
            RoundedRectangle.pill
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle.pill
                        .fill(Color.Textfield.background)
                )
        }
        .overlay {
            RoundedRectangle.pill
                .stroke(borderColor, lineWidth: FormSize.borderWidth)
        }
        .clipShape(.pill)
        .accessibleTextField(accessibilityConfig,
                             label: LocalizedStringKey(accessibilityConfig.label),
                             value: text.realValue)
    }
    
    // MARK: - Computed Properties
    
    private var currentState: SearchFieldState {
        if isFocused {
            .pressed
        } else if !text.isEmpty {
            .entered
        } else {
            .default
        }
    }
    
    private var borderColor: Color {
        switch currentState {
        case .default: .Textfield.Border.primary
        case .pressed: .Textfield.Border.focused
        case .entered: .Textfield.Border.focused
        }
    }
    
    private var textColor: Color {
        switch currentState {
        case .default: .Textfield.placeholder
        case .pressed: .Textfield.text
        case .entered: .Textfield.text
        }
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Search Field States") {
    VStack(spacing: 24) {
        SearchField(
            placeholder: "Search...",
            text: .constant(""),
            accessibility: PreviewSearchAccessibility()
        )
        
        SearchField(
            placeholder: "Search",
            text: .constant("Query"),
            accessibility: PreviewSearchAccessibility()
        )
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.Background.primary)
}

// MARK: - Preview Accessibility Helper

private struct PreviewSearchAccessibility: AccessibilityProtocol {
    var label: String {
        "Search"
    }
    
    var hint: String {
        "Enter search query"
    }
    
    var id: String {
        "search-field"
    }
}

#endif
