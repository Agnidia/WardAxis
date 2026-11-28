//
//  ASCII.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Byte ranges and folds for byte-level checks on untrusted text.
///
/// Every check here works on UTF-8 bytes and touches ASCII only, so no locale
/// or Unicode case mapping can turn a non-ASCII character into one that a
/// grammar accepts. ``FieldRules``, ``BoundedJSON`` and the policy matchers all
/// read their ranges from here, so one grammar cannot drift from another.
public enum ASCII {
    public static let digits = UInt8(ascii: "0")...UInt8(ascii: "9")
    public static let lowercaseLetters = UInt8(ascii: "a")...UInt8(ascii: "z")
    public static let uppercaseLetters = UInt8(ascii: "A")...UInt8(ascii: "Z")
    public static let lowercaseHexLetters = UInt8(ascii: "a")...UInt8(ascii: "f")
    public static let uppercaseHexLetters = UInt8(ascii: "A")...UInt8(ascii: "F")
    
    /// `0-9` and `a-f`: the only hex digits a canonical form may hold.
    public static func isLowercaseHexDigit(_ byte: UInt8) -> Bool {
        digits.contains(byte) || lowercaseHexLetters.contains(byte)
    }
    
    /// `0-9`, `a-f` and `A-F`.
    public static func isHexDigit(_ byte: UInt8) -> Bool {
        isLowercaseHexDigit(byte) || uppercaseHexLetters.contains(byte)
    }
    
    /// Folds `A-Z` to `a-z` and leaves every other byte as it is, so the result
    /// has exactly the input's bytes outside ASCII letters.
    public static func lowercased(_ value: some StringProtocol) -> String {
        String(decoding: value.utf8.map { uppercaseLetters.contains($0) ? $0 | 0x20 : $0 }, as: UTF8.self)
    }
}
