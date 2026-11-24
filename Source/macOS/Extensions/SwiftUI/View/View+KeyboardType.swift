//
//  View+KeyboardType.swift
//
//  Created on 08.03.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

#if os(macOS)

public enum KeyboardType: Int, @unchecked Sendable {
    case `default` = 0 // Default type for the current input method.
    
    case decimalPad = 8 // A number pad with a decimal point.
}

extension View {
    func keyboardType(_ type: KeyboardType) -> some View {
        self
    }
}

#endif
