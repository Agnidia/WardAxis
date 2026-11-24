//
//  AppError.swift
//
//  Created on 07.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Generic application error type for cross-cutting failure modes.
///
/// `AppError` is the canonical error surface returned by services in
/// `Source/Shared/Services/`. Concrete services may throw their own typed
/// errors and map them to `AppError` at the service boundary so that the
/// presentation layer never needs to know about transport-level details.
///
/// ## Adding a new case
///
/// 1. Add the case to the enum.
/// 2. Add the matching `L.Errors.*` key to `LocalizedStrings.swift`.
/// 3. Add the localized value to `Resources/Localizable.xcstrings`.
/// 4. Update the `errorDescription` switch.
enum AppError: Error, Sendable {
    /// The device cannot reach the network.
    case networkUnavailable

    /// The server did not accept this device's identity.
    case unauthorized

    /// The server rejected the request as malformed or invalid.
    case invalidRequest

    /// Too many requests. `retryAfter` is the server's suggested wait in seconds, if it sent one.
    case rateLimited(retryAfter: Int?)

    /// The server failed, answered outside its contract, or is not configured.
    case serverError

    /// An unexpected error from a lower layer. Kept for logging at the catch site;
    /// never shown to the user.
    case unknown(any Error)
}

// MARK: - LocalizedError

extension AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            String(localized: "errors.networkUnavailable", defaultValue: "Network is unavailable.")
        case .unauthorized:
            String(localized: "errors.unauthorized", defaultValue: "This device is not enrolled or its enrollment was revoked.")
        case .invalidRequest:
            String(localized: "errors.invalidRequest", defaultValue: "The request is not valid. Check the details and try again.")
        case .rateLimited:
            String(localized: "errors.rateLimited", defaultValue: "Too many attempts. Try again later.")
        case .serverError:
            String(localized: "errors.serverError", defaultValue: "Something went wrong on the server. Try again later.")
        case .unknown:
            // A lower layer's text can name paths, hosts or OS codes.
            String(localized: "errors.unknown", defaultValue: "Something went wrong. Try again later.")
        }
    }
}
