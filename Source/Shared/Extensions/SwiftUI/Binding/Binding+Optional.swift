//
//  Binding+Optional.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

public extension Binding where Value: Equatable & Sendable {
    /// Creates a two-way binding with a default value for optional Bindings.
    ///
    /// This convenience initializer helps you create a `Binding` with a default value when working with optional Bindings. It's especially useful when you want to handle `nil` values by providing a default value.
    ///
    /// - Parameters:
    ///   - source: The optional Binding you want to enhance.
    ///   - nilProxy: The default value to use when the source Binding is `nil`.
    init(_ source: Binding<Value?>?, default nilProxy: Value) {
        self.init(
            get: { source?.wrappedValue ?? nilProxy },
            set: { newValue in
                if newValue == nilProxy {
                    source?.wrappedValue = nil
                } else {
                    source?.wrappedValue = newValue
                }
            }
        )
    }
}
