//
//  Redacted.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// Holds a secret so that no string conversion, `dump` or log interpolation can print it.
///
/// Read ``value`` only at the call site that hands the secret to its consumer
/// (the database driver). Every textual form is `<redacted>`.
package struct Redacted<Value: Sendable>: Sendable {
    package let value: Value

    package init(_ value: Value) {
        self.value = value
    }
}

// MARK: - CustomStringConvertible

extension Redacted: CustomStringConvertible {
    package var description: String {
        "<redacted>"
    }
}

// MARK: - CustomDebugStringConvertible

extension Redacted: CustomDebugStringConvertible {
    package var debugDescription: String {
        "<redacted>"
    }
}

// MARK: - CustomReflectable

extension Redacted: CustomReflectable {
    /// Without this, `dump` and the default struct description walk the stored `value`.
    package var customMirror: Mirror {
        Mirror(self, children: [], displayStyle: .struct)
    }
}

// MARK: - Equatable

extension Redacted: Equatable where Value: Equatable {}
