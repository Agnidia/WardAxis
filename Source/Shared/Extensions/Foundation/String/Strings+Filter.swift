//
//  Strings+Filter.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

public extension String {
    /// Extracts the digit characters from the string.
    var digits: String {
        components(separatedBy: .decimalDigits.inverted).joined()
    }
    
    /// Extracts the letter characters from the string.
    var letters: String {
        components(separatedBy: .letters.inverted).joined()
    }
}
