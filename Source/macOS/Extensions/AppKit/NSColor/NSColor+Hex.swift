//
//  NSColor+Hex.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if os(macOS)

import AppKit

public extension NSColor {    
    /// Create an NSColor from a hexadecimal value with an optional alpha value.
    ///
    /// - Parameters:
    ///   - hex: The hexadecimal color value as an integer.
    ///   - alpha: The alpha (opacity) value for the color, ranging from 0 (transparent) to 1 (opaque).
    convenience init(hex: Int, alpha: CGFloat = 1) {
        let (red, green, blue) = NSColor.intToRGB(value: UInt64(hex))
        self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
    
    /// Create an NSColor from a hexadecimal value represented as a string with an optional alpha value.
    ///
    /// - Parameters:
    ///   - hex: The hexadecimal color value as a string, which may include a prefix like "0x" or "#" (e.g., "#FF5733").
    ///   - alpha: The alpha (opacity) value for the color, ranging from 0 (transparent) to 1 (opaque).
    convenience init(hex: String, alpha: CGFloat = 1) {
        // Handle two types of literals: 0x and # prefixed
        var cleanedString = ""
        if hex.hasPrefix("0x") {
            cleanedString = String(hex.suffix(from: hex.index(hex.startIndex, offsetBy: 2)))
        } else if hex.hasPrefix("#") {
            cleanedString = String(hex.suffix(from: hex.index(hex.startIndex, offsetBy: 1)))
        }
        
        // Ensure it only contains valid hex characters
        if cleanedString.isMatches(for: "[a-fA-F0-9]+") {
            var theInt: UInt64 = 0
            let scanner = Scanner(string: cleanedString)
            scanner.scanHexInt64(&theInt)
            
            let (red, green, blue) = NSColor.intToRGB(value: theInt)
            
            self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
        } else {
            self.init(calibratedRed: 0, green: 0, blue: 0, alpha: 0)
        }
    }
    
    private static func intToRGB(value: UInt64) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let red = CGFloat((value & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((value & 0xFF00) >> 8) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        
        return (r: red, g: green, b: blue)
    }
}

#endif
