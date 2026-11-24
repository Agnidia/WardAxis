//
//  FormTextField.swift
//
//  Created on 05.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

// MARK: - Form Text Field

/// A styled text field with label, states, and error handling.
///
/// Features:
/// - Uppercase mono label above the field
/// - Outer halo background with inner field
/// - Automatic state management based on focus and text content
/// - State-based border colors (default, focused, active, error)
/// - Error tag display below field when error message is provided
struct FormTextField: View {
    // MARK: - Form Text Field State
    
    private enum FormTextFieldState: Sendable {
        case `default`
        case focused
        case active
        case error(String)
    }
    
    let label: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let errorMessage: String?
    let accessibilityConfig: any AccessibilityProtocol
    let autofocus: Bool
    let autocorrectionDisabled: Bool
    let axis: Axis?
    let lineLimit: ClosedRange<Int>?
    let minHeight: CGFloat

#if os(iOS) || os(tvOS) || os(visionOS)
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let autocapitalization: TextInputAutocapitalization?
#endif

    @FocusState private var isFocused: Bool

#if os(iOS) || os(tvOS) || os(visionOS)
    init(label: LocalizedStringKey,
         placeholder: LocalizedStringKey,
         text: Binding<String>,
         errorMessage: String? = nil,
         keyboardType: UIKeyboardType = .default,
         textContentType: UITextContentType? = nil,
         autofocus: Bool = false,
         autocorrectionDisabled: Bool = true,
         autocapitalization: TextInputAutocapitalization? = nil,
         axis: Axis? = nil,
         lineLimit: ClosedRange<Int>? = nil,
         minHeight: CGFloat = TextFieldSize.height,
         accessibility: any AccessibilityProtocol)
    {
        self.label = label
        self.placeholder = placeholder
        _text = text
        self.errorMessage = errorMessage
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.autofocus = autofocus
        self.autocorrectionDisabled = autocorrectionDisabled
        self.autocapitalization = autocapitalization
        self.axis = axis
        self.lineLimit = lineLimit
        self.minHeight = minHeight
        accessibilityConfig = accessibility
    }
#else
    init(label: LocalizedStringKey,
         placeholder: LocalizedStringKey,
         text: Binding<String>,
         errorMessage: String? = nil,
         autofocus: Bool = false,
         autocorrectionDisabled: Bool = true,
         axis: Axis? = nil,
         lineLimit: ClosedRange<Int>? = nil,
         minHeight: CGFloat = TextFieldSize.height,
         accessibility: any AccessibilityProtocol)
    {
        self.label = label
        self.placeholder = placeholder
        _text = text
        self.errorMessage = errorMessage
        self.autofocus = autofocus
        self.autocorrectionDisabled = autocorrectionDisabled
        self.axis = axis
        self.lineLimit = lineLimit
        self.minHeight = minHeight
        accessibilityConfig = accessibility
    }
#endif

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing.s) {
            VStack(alignment: .leading, spacing: .spacing.l) {
                Text(label)
                    .bodyMono()
                    .foregroundStyle(Color.Label.primary)
                
                VStack(spacing: .zero) {
                    fieldView
                }
                .padding(FormSize.borderWidth)
                .background(borderColor)
                .clipShape(RoundedRectangle(cornerRadius: FormSize.innerRadius))
                .padding(FormSize.outerPadding)
                .background(Color.Border.primary)
                .clipShape(RoundedRectangle(cornerRadius: FormSize.outerRadius))
            }
            
            if let errorMessage {
                ErrorTag(message: errorMessage)
            }
        }
        .onAppear {
            if autofocus {
                isFocused = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    @ViewBuilder
    private var fieldView: some View {
        textField
            .bodyLarge()
            .foregroundStyle(Color.Textfield.text)
            .accentColor(Color.Textfield.text)
            .autocorrectionDisabled(autocorrectionDisabled)
#if os(iOS) || os(tvOS) || os(visionOS)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .textInputAutocapitalization(autocapitalization)
#endif
            .focused($isFocused)
            .accessibleTextField(accessibilityConfig,
                                 label: label,
                                 value: text.isEmpty ? nil : text)
            .padding(.vertical, FormSize.innerPaddingVertical)
            .padding(.horizontal, FormSize.innerPaddingHorizontal)
            .frame(minHeight: minHeight)
            .background(Color.Textfield.background)
            .clipShape(RoundedRectangle(cornerRadius: FormSize.innerRadius - FormSize.borderWidth))
    }
    
    @ViewBuilder
    private var textField: some View {
        let prompt = Text(placeholder).foregroundColor(Color.Textfield.placeholder)
        Group {
            if let axis {
                TextField("", text: $text, prompt: prompt, axis: axis)
                    .lineLimit(lineLimit ?? 1...10)
            } else {
                TextField("", text: $text, prompt: prompt)
            }
        }
        .textFieldStyle(.plain)
    }
    
    private var currentState: FormTextFieldState {
        if let errorMessage {
            .error(errorMessage)
        } else if isFocused {
            .focused
        } else if !text.isEmpty {
            .active
        } else {
            .default
        }
    }
    
    private var borderColor: Color {
        switch currentState {
        case .default: .Textfield.Border.secondary
        case .focused: .Textfield.Border.primary
        case .active: .Textfield.Border.primary
        case .error: .Textfield.Border.accent
        }
    }
}

// MARK: - Preview

#if DEBUG

#Preview("Form Text Field States") {
    VStack(spacing: 24) {
        FormTextField(
            label: "Label",
            placeholder: "Enter Phone Number",
            text: .constant(""),
            accessibility: PreviewFormFieldAccessibility()
        )
        
        FormTextField(
            label: "Label",
            placeholder: "Enter Phone Number",
            text: .constant("Text"),
            accessibility: PreviewFormFieldAccessibility()
        )
        
        FormTextField(
            label: "Label",
            placeholder: "Enter Phone Number",
            text: .constant(""),
            errorMessage: "Invalid phone number",
            accessibility: PreviewFormFieldAccessibility()
        )
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.Background.primary)
}

private struct PreviewFormFieldAccessibility: AccessibilityProtocol {
    var label: String {
        "Preview Field"
    }
    
    var hint: String {
        "Enter text"
    }
    
    var id: String {
        "preview-field"
    }
}

#endif
