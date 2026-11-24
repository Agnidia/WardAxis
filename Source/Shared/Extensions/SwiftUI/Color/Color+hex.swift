//
//  Color+hex.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Color Hex Support

extension Color {
    /// Creates a color from a hex string (e.g. "#BD2620" or "BD2620").
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}
