//
//  ConfigurationError.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// A start-up configuration failure.
///
/// The message names the environment variable and a fixed reason. It never contains
/// the variable's value, because that value can be a credential.
package enum ConfigurationError: Error, Equatable, Sendable {
    case missing(variable: String)
    case invalid(variable: String, reason: String)
}

// MARK: - CustomStringConvertible

extension ConfigurationError: CustomStringConvertible {
    package var description: String {
        switch self {
        case let .missing(variable):
            "Missing required environment variable \(variable)"
        case let .invalid(variable, reason):
            "Invalid environment variable \(variable): \(reason)"
        }
    }
}
