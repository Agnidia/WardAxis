//
//  DocsController.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import HTTPTypes
import Hummingbird

/// Serves the API reference: `GET /v1/docs` (a Redoc page), `GET /v1/openapi.yaml` (the
/// contract) and the Redoc script, all hand-written routes outside the contract.
///
/// The composition root registers this controller only in development with the docs flag
/// on, so otherwise each path gets the router's own not-found response. Every docs path
/// literal lives in this file; each is relative to the group the routes register on.
package struct DocsController: Sendable {
    package static let pagePath: String = "/docs"
    package static let documentPath: String = "/openapi.yaml"
    /// Equals the version in `Resources/APIDocs/PROVENANCE.md`.
    package static let redocVersion: String = "2.5.4"
    /// Versioned, so the script can be cached as immutable and an upgrade changes the URL.
    package static let redocScriptPath: String = "/docs/redoc/\(redocVersion)/redoc.standalone.js"
    
    /// Sent on `/v1/docs` only. Redoc's styled-components inject `<style>` elements, its
    /// search index runs in a `blob:` worker, and its icons are `data:` SVG images; nothing
    /// else is relaxed, and no remote origin or string evaluation is ever allowed. Redoc's
    /// footer logo from cdn.redoc.ly is blocked on purpose; Redoc hides it on load failure.
    package static let contentSecurityPolicy: String = [
        "default-src 'self'",
        "script-src 'self'",
        "style-src 'self' 'unsafe-inline'",
        "worker-src blob:",
        "img-src 'self' data:",
        "font-src 'self'",
        "connect-src 'self'",
        "object-src 'none'",
        "base-uri 'none'",
        "frame-ancestors 'none'",
        "form-action 'none'"
    ].joined(separator: "; ")
    
    package static let pageContentType: String = "text/html; charset=utf-8"
    /// RFC 9512.
    package static let documentContentType: String = "application/yaml"
    package static let scriptContentType: String = "text/javascript; charset=utf-8"
    
    /// No inline script and no URL with an origin: the CSP forbids the first, and the page
    /// must load nothing from another origin. System fonts only, so no font link.
    ///
    /// - Parameter basePath: The group's prefix. The URLs are root-relative, not relative
    ///   to the page, so they still resolve when a client requests the page with a
    ///   trailing slash.
    package static func page(basePath: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>API reference</title>
        </head>
        <body>
        <redoc spec-url="\(basePath)\(documentPath)"></redoc>
        <script src="\(basePath)\(redocScriptPath)"></script>
        </body>
        </html>
        """
    }
    
    private static let referrerPolicy = HTTPField.Name("Referrer-Policy")!
    
    private let docs: APIDocs
    private let pageBody: ByteBuffer
    
    /// - Parameter basePath: The prefix of the group ``addRoutes(to:)`` receives, which the
    ///   page needs for its absolute URLs.
    package init(docs: APIDocs, basePath: String) {
        self.docs = docs
        pageBody = ByteBuffer(string: Self.page(basePath: basePath))
    }
    
    package func addRoutes(to group: RouterGroup<AppRequestContext>) {
        group.get(RouterPath(Self.pagePath)) { _, _ in
            Response(
                status: .ok,
                headers: [
                    .contentType: Self.pageContentType,
                    .cacheControl: HeaderValue.revalidate,
                    .contentSecurityPolicy: Self.contentSecurityPolicy,
                    .xContentTypeOptions: HeaderValue.noSniff,
                    Self.referrerPolicy: "no-referrer"
                ],
                body: ResponseBody(byteBuffer: pageBody)
            )
        }
        group.get(RouterPath(Self.documentPath)) { _, _ in
            Response(
                status: .ok,
                headers: [
                    .contentType: Self.documentContentType,
                    .cacheControl: HeaderValue.revalidate,
                    .xContentTypeOptions: HeaderValue.noSniff
                ],
                body: ResponseBody(byteBuffer: docs.openAPIDocument)
            )
        }
        group.get(RouterPath(Self.redocScriptPath)) { _, _ in
            Response(
                status: .ok,
                headers: [
                    .contentType: Self.scriptContentType,
                    .cacheControl: "public, max-age=31536000, immutable",
                    .xContentTypeOptions: HeaderValue.noSniff
                ],
                body: ResponseBody(byteBuffer: docs.redocScript)
            )
        }
    }
}
