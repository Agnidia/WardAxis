//
//  ASCII.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Byte ranges for the byte-level checks in ``FieldRules`` and ``BoundedJSON``.
enum ASCII {
    static let digits = UInt8(ascii: "0")...UInt8(ascii: "9")
    static let lowercaseLetters = UInt8(ascii: "a")...UInt8(ascii: "z")
    static let uppercaseLetters = UInt8(ascii: "A")...UInt8(ascii: "Z")
    static let lowercaseHexLetters = UInt8(ascii: "a")...UInt8(ascii: "f")
    static let uppercaseHexLetters = UInt8(ascii: "A")...UInt8(ascii: "F")
}
