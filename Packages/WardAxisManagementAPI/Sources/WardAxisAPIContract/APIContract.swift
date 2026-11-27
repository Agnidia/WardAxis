//
//  APIContract.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// Rules on the contract's `servers` path that the server and the client both apply (ADR 0019).
public enum APIBasePathRule {
    /// Accepts `/v1` and `/api/v1`.
    ///
    /// A spec edit to `/` would serve the API unversioned, and `/v1/` or `//v1`
    /// would produce paths that the other side does not route. Both sides refuse
    /// all three, so the failure shows at start-up and not as a silent 404.
    public static func isValid(_ path: String) -> Bool {
        path.hasPrefix("/") && path != "/" && !path.hasSuffix("/") && !path.contains("//")
    }
}

/// The stable error codes listed in the contract's `ErrorResponse.code`.
///
/// The set is open for clients: an unknown code is a generic error.
public enum APIErrorCode {
    public static let invalidRequest = "invalid_request"
    public static let notFound = "not_found"
    public static let methodNotAllowed = "method_not_allowed"
    public static let payloadTooLarge = "payload_too_large"
    public static let internalError = "internal_error"
    
    /// Every code the server sends, in the order the contract lists them.
    public static let all = [invalidRequest, notFound, methodNotAllowed, payloadTooLarge, internalError]
}
