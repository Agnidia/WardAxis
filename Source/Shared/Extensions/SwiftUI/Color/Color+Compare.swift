//
//  Color+Compare.swift
//
//  Created on 10.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

public extension Color {
    /// Compares two colors component by component after resolving them.
    ///
    /// Semantic and asset colors resolve differently per appearance, so the
    /// comparison needs the environment the colors are shown in.
    ///
    /// - Parameters:
    ///   - other: The color to compare with.
    ///   - tolerance: The largest allowed difference per sRGB component, in `0...1`.
    ///   - environment: The environment used to resolve both colors.
    /// - Returns: `true` when red, green, blue, and opacity all differ by at most `tolerance`.
    func isApproximatelyEqual(
        to other: Color,
        tolerance: Float = 0,
        in environment: EnvironmentValues = EnvironmentValues()
    ) -> Bool {
        resolve(in: environment).isApproximatelyEqual(to: other.resolve(in: environment), tolerance: tolerance)
    }
}

public extension Color.Resolved {
    /// Compares two resolved colors component by component.
    ///
    /// - Parameters:
    ///   - other: The resolved color to compare with.
    ///   - tolerance: The largest allowed difference per sRGB component, in `0...1`.
    func isApproximatelyEqual(to other: Color.Resolved, tolerance: Float = 0) -> Bool {
        abs(red - other.red) <= tolerance
            && abs(green - other.green) <= tolerance
            && abs(blue - other.blue) <= tolerance
            && abs(opacity - other.opacity) <= tolerance
    }

    /// The sRGB components and opacity scaled to `0...255`.
    var rgba8: (red: Int, green: Int, blue: Int, alpha: Int) {
        (Self.byte(red), Self.byte(green), Self.byte(blue), Self.byte(opacity))
    }

    private static func byte(_ component: Float) -> Int {
        Int((min(max(component, 0), 1) * 255).rounded())
    }
}
