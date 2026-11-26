//
//  ErrorHandlingMiddleware.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Hummingbird
import Logging
import WardAxisAPIServer

/// Turns every error thrown inside the router into an `ErrorResponse` body.
///
/// The only renderer of `ErrorResponse`, so one place guarantees the `requestId` and the
/// `Cache-Control: no-store` header (an error answer is never worth caching), and that no
/// body carries a type name, SQL, a stack trace or an error's text. The log line carries
/// the error's type and the request ID, never its description.
package struct ErrorHandlingMiddleware: RouterMiddleware {
    package typealias Context = AppRequestContext
    
    package init() {}
    
    package func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        do {
            return try await next(request, context)
        } catch {
            let (apiError, cause) = Self.classify(error)
            let level: Logger.Level = apiError.status.code >= 500 ? .error : .debug
            context.logger.log(
                level: level,
                "Request failed",
                metadata: [
                    "error.type": "\(type(of: cause))",
                    "error.code": "\(apiError.code)",
                    "http.status": "\(apiError.status.code)"
                ]
            )
            return Self.response(for: apiError, requestID: context.requestID)
        }
    }
    
    /// Maps `error` to the response it gets, and returns the error that caused it.
    package static func classify(_ error: any Error) -> (APIError, cause: any Error) {
        if let apiError = error as? APIError {
            return (apiError, error)
        }
        // HTTPError and NIOTooManyBytesError (413) both conform.
        if let responseError = error as? any HTTPResponseError {
            return (.forStatus(responseError.status), error)
        }
        return (.internalError, error)
    }
    
    package static func response(for error: APIError, requestID: String?) -> Response {
        let body = Components.Schemas.ErrorResponse(code: error.code, message: error.message, requestId: requestID)
        let headers: HTTPFields = [.contentType: "application/json; charset=utf-8", .cacheControl: "no-store"]
        // Encoding three strings cannot fail; the fallback still sends a valid body.
        let data = (try? JSONEncoder().encode(body)) ?? Data(#"{"code":"internal_error","message":""}"#.utf8)
        return Response(status: error.status, headers: headers, body: ResponseBody(byteBuffer: ByteBuffer(bytes: data)))
    }
}
