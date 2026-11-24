//
//  BuildRouter.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Hummingbird

/// Whether the listener in front of the router verifies TLS client certificates.
package enum ClientCertificateVerification: Sendable, Equatable {
    /// Every connection passed a handshake that verified a client certificate against the
    /// device CA.
    case required
    /// No client certificate is verified: plain HTTP, or TLS without a device CA.
    case off
}

/// Assembles every route and middleware. Production and tests share this one path.
///
/// Middleware is added first because a Hummingbird router applies it only to routes
/// added after it; it also wraps the not-found responder. Outer to inner: the request ID
/// exists before anything logs or fails; the error renderer sits inside the logger, so
/// the logged status is the rendered one; the body limit sits inside the renderer, so
/// its failures get an `ErrorResponse` too.
///
/// Every route sits on one group at ``APIBasePath``, so a path outside it, such as an
/// unversioned one, gets the router's own `404`.
///
/// Docs mount only in development, even when `apiDocs` is set: `AppConfiguration` already
/// refuses them in production, and this second gate holds for any other composition root.
///
/// - Parameter clientCertificates: The config stream is mounted only with
///   ``ClientCertificateVerification/required``. Its only credential is the client
///   certificate, so without verification the route does not exist (`404`) rather than
///   serve unauthenticated clients. The default is the closed one.
/// - Throws: ``APIBasePath/InvalidPath`` for an unusable contract `servers` path.
package func buildRouter(
    dependencies: ServerDependencies,
    clientCertificates: ClientCertificateVerification = .off
) throws -> Router<AppRequestContext> {
    let basePath = try APIBasePath.resolve()
    let router = Router(context: AppRequestContext.self)
    router.add(middleware: RequestIDMiddleware())
    router.add(middleware: RequestLoggingMiddleware())
    router.add(middleware: ErrorHandlingMiddleware())
    // The limit runs before routing and matches the raw request path, prefix included.
    router.add(middleware: RequestBodyLimitMiddleware())

    let api = router.group(RouterPath(basePath))
    HealthController(probe: dependencies.databaseProbe).addRoutes(to: api)
    if clientCertificates == .required {
        ConfigStreamController(dependencies: dependencies).addRoutes(to: api)
    }
    if dependencies.environment == .development, let apiDocs = dependencies.apiDocs {
        DocsController(docs: apiDocs, basePath: basePath).addRoutes(to: api)
    }
    return router
}
