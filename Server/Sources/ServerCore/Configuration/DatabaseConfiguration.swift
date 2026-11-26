//
//  DatabaseConfiguration.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// How the client negotiates TLS with PostgreSQL, from the `sslmode` URL query item.
package enum DatabaseTLSMode: String, Sendable, Equatable {
    /// Plain text. Only for a database on a local or private container network.
    case disable
    /// TLS when the server offers it, plain text otherwise. An on-path attacker can
    /// force the plain-text branch, so this is never the default.
    case prefer
    /// TLS with certificate chain and host name verification. The default when the URL
    /// names no `sslmode`; stricter than libpq's `require`, which skips verification.
    case require
}

/// Connection settings parsed from a `postgres://` URL.
///
/// This type exists so that parsing stays free of PostgresNIO and NIOSSL;
/// `PostgresClientFactory` is the only place that maps it to a driver configuration.
package struct DatabaseConfiguration: Sendable, Equatable {
    package static let defaultPort: Int = 5432
    
    package let host: String
    package let port: Int
    package let username: String
    /// `nil` when the URL has no password, for example under `trust` authentication.
    package let password: Redacted<String>?
    package let database: String
    package let tls: DatabaseTLSMode
    
    /// Parses a URL of the form `postgres://user:password@host:port/database?sslmode=mode`.
    ///
    /// - Parameters:
    ///   - url: The raw URL. A password with reserved characters must be percent-encoded.
    ///   - variable: The environment variable name that errors report.
    /// - Throws: ``ConfigurationError/invalid(variable:reason:)`` with a reason that never quotes the URL.
    package init(url: String, variable: String) throws(ConfigurationError) {
        guard let components = URLComponents(string: url) else {
            throw .invalid(variable: variable, reason: "is not a valid URL")
        }
        guard let scheme = components.scheme?.lowercased(), scheme == "postgres" || scheme == "postgresql" else {
            throw .invalid(variable: variable, reason: "must use the postgres:// or postgresql:// scheme")
        }
        guard let host = components.host, !host.isEmpty else {
            throw .invalid(variable: variable, reason: "must include a host")
        }
        guard let username = components.user, !username.isEmpty else {
            throw .invalid(variable: variable, reason: "must include a user name")
        }
        let port = components.port ?? Self.defaultPort
        guard (1...65_535).contains(port) else {
            throw .invalid(variable: variable, reason: "must use a port between 1 and 65535")
        }
        let database = String(components.path.drop { $0 == "/" })
        guard !database.isEmpty, !database.contains("/") else {
            throw .invalid(variable: variable, reason: "must name exactly one database in its path")
        }
        
        let sslMode = components.queryItems?.last { $0.name == "sslmode" }?.value
        let tls: DatabaseTLSMode
        if let sslMode {
            guard let mode = DatabaseTLSMode(rawValue: sslMode) else {
                throw .invalid(variable: variable, reason: "sslmode must be disable, prefer or require")
            }
            tls = mode
        } else {
            // Fail closed: a missing sslmode must not allow a plain-text downgrade.
            tls = .require
        }
        
        self.host = host
        self.port = port
        self.username = username
        // `password` is already percent-decoded by URLComponents.
        password = components.password.flatMap { $0.isEmpty ? nil : Redacted($0) }
        self.database = database
        self.tls = tls
    }
}

// MARK: - CustomStringConvertible

extension DatabaseConfiguration: CustomStringConvertible {
    package var description: String {
        let passwordText: String = password == nil ? "none" : "<redacted>"
        return "DatabaseConfiguration(host: \(host), port: \(port), username: \(username), "
            + "password: \(passwordText), database: \(database), tls: \(tls.rawValue))"
    }
}
