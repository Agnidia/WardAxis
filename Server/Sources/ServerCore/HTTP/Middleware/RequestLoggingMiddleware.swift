//
//  RequestLoggingMiddleware.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Hummingbird
import Logging

/// Logs one line per request from an allow-list: method, matched route template,
/// status and duration.
///
/// Headers, bodies, query strings and raw paths are never logged, so a credential cannot
/// reach the log through a header or a path segment. The template (`/users/:id`) is
/// bounded by the routes; an unmatched request logs `NotFound`. Runs inside
/// ``RequestIDMiddleware``, so each line carries `request.id`.
package struct RequestLoggingMiddleware: RouterMiddleware {
    package typealias Context = AppRequestContext

    package init() {}

    package func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        let start: ContinuousClock.Instant = .now
        do {
            let response = try await next(request, context)
            log(request, context: context, status: response.status, since: start)
            return response
        } catch {
            let status = (error as? any HTTPResponseError)?.status ?? .internalServerError
            log(request, context: context, status: status, since: start)
            throw error
        }
    }

    private func log(_ request: Request, context: Context, status: HTTPResponse.Status, since start: ContinuousClock.Instant) {
        let elapsed = start.duration(to: .now).components
        let milliseconds = Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15
        // Read after `next`: the router fills the shared endpoint box during routing.
        context.logger.info(
            "Request completed",
            metadata: [
                "http.method": "\(request.method.rawValue)",
                "http.route": "\(context.endpointPath ?? "unmatched")",
                "http.status": "\(status.code)",
                "http.duration_ms": "\(milliseconds)"
            ]
        )
    }
}
