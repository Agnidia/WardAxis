//
//  APIBasePath.swift
//
//  Created on 16.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import WardAxisAPIServer
import Foundation

/// The path prefix every route is served under: the path of the contract's `servers` URL.
///
/// Read from the generated `Servers`, so the spec is the only source of the prefix.
package enum APIBasePath {
    /// A `servers` path that cannot prefix routes.
    package struct InvalidPath: Error, Equatable, CustomStringConvertible {
        package let path: String

        package init(path: String) {
            self.path = path
        }

        package var description: String {
            "The contract's servers path \"\(path)\" must start with /, must not be / alone, and must have no trailing or doubled /"
        }
    }

    /// - Throws: ``InvalidPath`` when the contract's `servers` path fails ``validate(_:)``,
    ///   or the generator's URL error. Either one stops start-up before the listener binds.
    package static func resolve() throws -> String {
        // Percent-encoded: `URL.path` drops a trailing slash, which must fail here.
        try validate(Servers.Server1.url().path(percentEncoded: true))
    }

    /// Accepts `/v1` and `/api/v1`. A spec edit to `/` would serve the API unversioned, and
    /// `/v1/` or `//v1` would produce paths that no client sends, so all three fail loudly.
    package static func validate(_ path: String) throws(InvalidPath) -> String {
        guard path.hasPrefix("/"), path != "/", !path.hasSuffix("/"), !path.contains("//") else {
            throw InvalidPath(path: path)
        }
        return path
    }
}
