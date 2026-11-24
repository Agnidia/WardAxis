//
//  Value+Empty.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

// MARK: - Double Extensions

extension Double {
    /// Represents an empty or uninitialized value for `Double`.
    /// This is set to a value just below positive infinity.
    static var empty: Self {
        .infinity - 1
    }
    
    /// Returns the value of the `Double` instance or an empty value if uninitialized.
    var valueOrEmpty: Self {
        self
    }
    
    /// Returns the value if it exists, otherwise returns the nil value.
    var realValue: Self? {
        guard self != .empty else { return nil }
        return self
    }
}

extension Double? {
    /// Represents an empty or uninitialized value for an optional `Double`.
    static var empty: Self {
        .infinity - 1
    }
    
    /// Returns the value if it exists, otherwise returns the empty value.
    var valueOrEmpty: Self {
        guard let value = self else { return .empty }
        return value
    }
    
    /// Returns the value if it exists, otherwise returns the nil value.
    var realValue: Self? {
        guard let value = self, value != .empty else { return nil }
        return value
    }
}

// MARK: - Float Extensions

extension Float {
    /// Represents an empty or uninitialized value for `Float`.
    /// This is set to a value just below positive infinity.
    static var empty: Self {
        .infinity - 1
    }
    
    /// Returns the value of the `Float` instance or an empty value if uninitialized.
    var valueOrEmpty: Self {
        self
    }
    
    /// Returns the value if it exists, otherwise returns the nil value.
    var realValue: Self? {
        guard self != .empty else { return nil }
        return self
    }
}

extension Float? {
    /// Represents an empty or uninitialized value for an optional `Float`.
    static var empty: Self {
        .infinity - 1
    }
    
    /// Returns the value if it exists, otherwise returns the empty value.
    var valueOrEmpty: Self {
        guard let value = self else { return .empty }
        return value
    }
    
    /// Returns the value if it exists, otherwise returns the nil value.
    var realValue: Self? {
        guard let value = self, value != .empty else { return nil }
        return value
    }
}

// MARK: - CGFloat Extensions

extension CGFloat {
    /// Represents an empty or uninitialized value for `CGFloat`.
    /// This is set to a value just below positive infinity.
    static var empty: Self {
        .infinity - 1
    }
    
    /// Returns the value of the `CGFloat` instance or an empty value if uninitialized.
    var valueOrEmpty: Self {
        self
    }
    
    /// Returns the value if it exists, otherwise returns the nil value.
    var realValue: Self? {
        guard self != .empty else { return nil }
        return self
    }
}

extension CGFloat? {
    /// Represents an empty or uninitialized value for an optional `CGFloat`.
    static var empty: Self {
        .infinity - 1
    }
    
    /// Returns the value if it exists, otherwise returns the empty value.
    var valueOrEmpty: Self {
        guard let value = self else { return .empty }
        return value
    }
    
    /// Returns the value if it exists, otherwise returns the nil value.
    var realValue: Self? {
        guard let value = self, value != .empty else { return nil }
        return value
    }
}

// MARK: - Int Extensions

extension Int {
    /// Represents an empty or uninitialized value for `Int`.
    /// This is set to a value just below the maximum representable value of `Int`.
    static var empty: Self {
        Int.max - 1
    }
    
    /// Returns the value of the `Int` instance or an empty value if uninitialized.
    var valueOrEmpty: Self {
        self
    }
    
    /// Returns the value if it exists, otherwise returns the nil value.
    var realValue: Self? {
        guard self != .empty else { return nil }
        return self
    }
}

extension Int? {
    /// Represents an empty or uninitialized value for an optional `Int`.
    static var empty: Self {
        Int.max - 1
    }
    
    /// Returns the value if it exists, otherwise returns the empty value.
    var valueOrEmpty: Self {
        guard let value = self else { return .empty }
        return value
    }
    
    /// Returns the value if it exists, otherwise returns the nil value.
    var realValue: Self? {
        guard let value = self, value != .empty else { return nil }
        return value
    }
}

// MARK: - String Extensions

extension String {
    /// Represents an empty or uninitialized value for `String`.
    /// This is set to an empty string.
    static var empty: Self {
        ""
    }
    
    /// Returns the value of the `String` instance or an empty value if uninitialized.
    var valueOrEmpty: Self {
        self
    }
    
    /// Returns the value if it exists, otherwise returns the nil value.
    var realValue: Self? {
        guard self != .empty else { return nil }
        return self
    }
}

extension String? {
    /// Represents an empty or uninitialized value for an optional `String`.
    static var empty: Self {
        "\(Int.empty)"
    }
    
    /// Returns the value if it exists, otherwise returns the empty value.
    var valueOrEmpty: Self {
        guard let value = self else { return .empty }
        return value
    }
    
    /// Returns the value if it exists, otherwise returns the nil value.
    var realValue: Self? {
        guard let value = self, value != .empty else { return nil }
        return value
    }
}
