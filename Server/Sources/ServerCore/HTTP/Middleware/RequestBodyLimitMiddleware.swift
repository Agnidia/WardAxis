//
//  RequestBodyLimitMiddleware.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Hummingbird

/// Rejects a request body larger than its route's limit with `413 Content Too Large`.
///
/// Hummingbird's `maxUploadSize` applies only to its own `request.decode`, so a route
/// that reads the body another way would read it without any size bound. This
/// middleware collects the body first, up to the limit, and stores the bounded buffer
/// back on the request, so every later reader sees at most that many bytes.
///
/// It runs before routing, so an override matches the exact method and path text; any
/// other spelling of a path (a trailing slash, a different case) gets the default, which
/// is the stricter limit.
package struct RequestBodyLimitMiddleware: RouterMiddleware {
    package typealias Context = AppRequestContext

    /// One route's method and literal path.
    package struct RouteKey: Hashable, Sendable {
        package let method: HTTPRequest.Method
        package let path: String

        package init(method: HTTPRequest.Method, path: String) {
            self.method = method
            self.path = path
        }
    }

    /// Ample for the small JSON bodies the API takes; routes that need more get an override.
    package static let defaultLimit: Int = 64 * 1024

    private let defaultLimit: Int
    private let overrides: [RouteKey: Int]

    package init(defaultLimit: Int = Self.defaultLimit, overrides: [RouteKey: Int] = [:]) {
        self.defaultLimit = defaultLimit
        self.overrides = overrides
    }

    package func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        let limit = overrides[RouteKey(method: request.method, path: request.uri.path)] ?? defaultLimit
        // A declared length over the limit fails before any byte is read.
        if let declaredLength = request.headers[.contentLength].flatMap(Int.init), declaredLength > limit {
            throw HTTPError(.contentTooLarge)
        }
        var request = request
        // A chunked body has no declared length; an overflow throws NIOTooManyBytesError,
        // which Hummingbird answers with 413.
        _ = try await request.collectBody(upTo: limit)
        return try await next(request, context)
    }
}
