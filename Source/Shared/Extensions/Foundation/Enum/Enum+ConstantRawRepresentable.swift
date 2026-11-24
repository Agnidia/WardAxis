//
//  Enum+ConstantRawRepresentable.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

// A protocol that represents a type with string raw value representation.
// This protocol is essentially a marker for types that represent constants where each case is a distinct string.
//
// It conforms to `RawRepresentable` where the `RawValue` is a `String`.

public protocol ConstantRawRepresentable: RawRepresentable where RawValue == String {}

public extension ConstantRawRepresentable {
    /// The default implementation of the initializer always returns `nil`.
    ///
    /// This means that types conforming to `ConstantRawRepresentable` cannot be initialized
    /// using string values; they can only be defined directly using their cases.
    ///
    /// - Parameter rawValue: The string representation of the instance.
    /// - Returns: Always returns `nil`.
    init?(rawValue: RawValue) {
        nil
    }
    
    /// The default raw value of the constant, defined as an empty string.
    ///
    /// This property needs to be overridden by the conforming types to provide meaningful raw values for each case.
    ///
    /// - Returns: An empty string.
    var rawValue: RawValue {
        ""
    }
}
