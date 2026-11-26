//
//  APIError.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import HTTPTypes

/// An error response in the contract's terms: status, stable code and a fixed message.
///
/// Routes throw it; ``ErrorHandlingMiddleware`` is the only place that renders it. The
/// message is a constant per case and never quotes input.
package struct APIError: Error, Sendable, Equatable {
    package let status: HTTPResponse.Status
    package let code: String
    package let message: String
    
    package init(status: HTTPResponse.Status, code: String, message: String) {
        self.status = status
        self.code = code
        self.message = message
    }
    
    package static func invalidRequest(message: String) -> APIError {
        APIError(status: .badRequest, code: "invalid_request", message: message)
    }
    
    package static let malformedRequest: APIError = .invalidRequest(message: "The request is malformed.")
    package static let internalError: APIError = .init(
        status: .internalServerError,
        code: "internal_error",
        message: "Something went wrong. Try again later."
    )
    
    /// The contract's code for a status the router or a framework produced.
    package static func forStatus(_ status: HTTPResponse.Status) -> APIError {
        switch status.code {
        case 400:
            .malformedRequest
        case 404:
            APIError(status: status, code: "not_found", message: "The resource does not exist.")
        case 405:
            APIError(status: status, code: "method_not_allowed", message: "The method is not allowed on this resource.")
        case 413:
            APIError(status: status, code: "payload_too_large", message: "The request body is too large.")
        case 400..<500:
            APIError(status: status, code: "invalid_request", message: "The request cannot be served.")
        default:
            .internalError
        }
    }
}
