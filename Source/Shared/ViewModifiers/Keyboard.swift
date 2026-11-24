//
//  Keyboard.swift
//
//  Created on 05.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
enum Keyboard {
    /// Resigns the first responder, dismissing the on-screen keyboard.
    static func dismiss() {
#if canImport(UIKit) && !os(watchOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
#elseif canImport(AppKit)
        NSApp?.keyWindow?.makeFirstResponder(nil)
#endif
    }
}
