//
//  RawRepresentable+Codable.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// A generic wrapper for `Codable` values that provides serialization and Equatable conformance.
struct CodableWrapper<Value: Codable> {
    var value: Value
}

extension CodableWrapper: Equatable where Value: Equatable {}

extension CodableWrapper: RawRepresentable {
    typealias RawValue = String
    
    /// The raw string representation of the wrapped `Codable` value.
    var rawValue: RawValue {
        guard
            let data = try? JSONEncoder().encode(value),
            let string = String(data: data, encoding: .utf8)
        else {
            // TODO: Handle serialization error
            return ""
        }
        return string
    }
    
    /// Initializes the wrapper with a raw string representation.
    /// - Parameter rawValue: The raw string representation of the `Codable` value.
    init?(rawValue: RawValue) {
        guard
            let data = rawValue.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(Value.self, from: data)
        else {
            // TODO: Handle deserialization error
            return nil
        }
        value = decoded
    }
}
