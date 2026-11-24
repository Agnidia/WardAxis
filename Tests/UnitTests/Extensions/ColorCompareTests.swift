//
//  ColorCompareTests.swift
//
//  Created on 10.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import Testing
@testable import WardAxis

@Suite("Color approximate comparison")
struct ColorCompareTests {
    @Test("Equal colors match with zero tolerance")
    func equalColors() {
        #expect(Color(.sRGB, red: 0.2, green: 0.4, blue: 0.6).isApproximatelyEqual(to: Color(.sRGB, red: 0.2, green: 0.4, blue: 0.6)))
    }

    @Test("Small difference matches only within tolerance")
    func tolerance() {
        let a = Color(.sRGB, red: 0.50, green: 0.5, blue: 0.5)
        let b = Color(.sRGB, red: 0.52, green: 0.5, blue: 0.5)

        #expect(a.isApproximatelyEqual(to: b, tolerance: 0.05))
        #expect(!a.isApproximatelyEqual(to: b, tolerance: 0.001))
    }

    @Test("Opacity takes part in the comparison")
    func opacity() {
        #expect(!Color.red.isApproximatelyEqual(to: Color.red.opacity(0.5), tolerance: 0.1))
    }

    @Test("rgba8 scales components to 0...255")
    func rgba8() {
        let resolved = Color(.sRGB, red: 1, green: 0, blue: 0.5, opacity: 1).resolve(in: EnvironmentValues())
        let value = resolved.rgba8

        #expect(value.red == 255)
        #expect(value.green == 0)
        #expect(value.blue == 128)
        #expect(value.alpha == 255)
    }
}
