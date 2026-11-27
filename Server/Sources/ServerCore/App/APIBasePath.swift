//
//  APIBasePath.swift
//
//  Created on 16.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisAPIContract
import WardAxisAPIServer

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
    
    /// Applies ``APIBasePathRule``, the rule the client applies to the same path.
    package static func validate(_ path: String) throws(InvalidPath) -> String {
        guard APIBasePathRule.isValid(path) else {
            throw InvalidPath(path: path)
        }
        return path
    }
}
