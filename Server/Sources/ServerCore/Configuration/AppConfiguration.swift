//
//  AppConfiguration.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Logging

/// The server's start-up settings, read from environment variables only.
///
/// The initializer takes the environment as a dictionary so tests never mutate the
/// process environment. The type holds no default for any credential.
package struct AppConfiguration: Sendable {
    /// The environment variable names this type reads.
    package enum Variable {
        package static let host: String = "HOST"
        package static let port: String = "PORT"
        package static let databaseURL: String = "DATABASE_URL"
        package static let logLevel: String = "LOG_LEVEL"
        package static let serverEnvironment: String = "SERVER_ENVIRONMENT"
        package static let tlsCertificateChainPath: String = "TLS_CERTIFICATE_CHAIN_PATH"
        package static let tlsPrivateKeyPath: String = "TLS_PRIVATE_KEY_PATH"
        package static let tlsClientCAPath: String = "TLS_CLIENT_CA_PATH"
        package static let apiDocsEnabled: String = "API_DOCS_ENABLED"
    }
    
    package static let defaultHost: String = "0.0.0.0"
    package static let defaultPort: Int = 8080
    /// TCP ports a listener or a database URL may name.
    package static let validPorts: ClosedRange<Int> = 1...65_535
    package static let defaultLogLevel: Logger.Level = .info
    package static let defaultServerEnvironment: ServerEnvironment = .production
    
    package let host: String
    package let port: Int
    package let database: DatabaseConfiguration
    package let logLevel: Logger.Level
    package let environment: ServerEnvironment
    /// The PEM files the listener serves TLS with; `nil` means plain HTTP, which only
    /// ``ServerEnvironment/development`` allows. Its
    /// ``TLSFiles/clientCertificateAuthorityPath`` turns on client-certificate verification,
    /// without which the config stream is not served.
    package let tls: TLSFiles?
    /// Whether `/v1/docs`, `/v1/openapi.yaml` and the Redoc script are served. Defaults to
    /// on in ``ServerEnvironment/development``; production never serves them, and refuses
    /// to start when asked to.
    package let apiDocsEnabled: Bool
    
    /// Parses and validates the environment. An empty value counts as missing.
    ///
    /// - Throws: ``ConfigurationError`` naming the first variable that is missing or invalid.
    package init(environment: [String: String]) throws(ConfigurationError) {
        func value(_ name: String) -> String? {
            guard let raw = environment[name], !raw.isEmpty else { return nil }
            return raw
        }
        
        host = value(Variable.host) ?? Self.defaultHost
        
        if let rawPort = value(Variable.port) {
            guard let parsed = Int(rawPort), AppConfiguration.validPorts.contains(parsed) else {
                throw .invalid(variable: Variable.port, reason: "must be an integer between 1 and 65535")
            }
            port = parsed
        } else {
            port = Self.defaultPort
        }
        
        guard let databaseURL = value(Variable.databaseURL) else {
            throw .missing(variable: Variable.databaseURL)
        }
        database = try DatabaseConfiguration(url: databaseURL, variable: Variable.databaseURL)
        
        if let rawEnvironment = value(Variable.serverEnvironment) {
            guard let parsed = ServerEnvironment(rawValue: rawEnvironment) else {
                throw .invalid(variable: Variable.serverEnvironment, reason: "must be development or production")
            }
            self.environment = parsed
        } else {
            self.environment = Self.defaultServerEnvironment
        }
        
        if let rawLevel = value(Variable.logLevel) {
            guard let level = Logger.Level(rawValue: rawLevel.lowercased()) else {
                throw .invalid(
                    variable: Variable.logLevel,
                    reason: "must be one of trace, debug, info, notice, warning, error, critical"
                )
            }
            logLevel = level
        } else {
            logLevel = Self.defaultLogLevel
        }
        
        switch value(Variable.apiDocsEnabled) {
        case "true":
            // A refusal, not a silent off: a deployment that asks for docs in production
            // has a wrong environment or a wrong flag, and either one needs a person.
            guard self.environment == .development else {
                throw .invalid(variable: Variable.apiDocsEnabled, reason: "must not be true in production")
            }
            apiDocsEnabled = true
        case "false":
            apiDocsEnabled = false
        case nil:
            apiDocsEnabled = self.environment == .development
        case _?:
            throw .invalid(variable: Variable.apiDocsEnabled, reason: "must be true or false")
        }
        
        // Both paths or neither: one alone is a typo, never a request for plain HTTP.
        // Production has no plain-HTTP option at all. A device CA without them is refused
        // too: client certificates exist only inside TLS, so it would protect nothing.
        let clientCAPath = value(Variable.tlsClientCAPath)
        switch (value(Variable.tlsCertificateChainPath), value(Variable.tlsPrivateKeyPath)) {
        case (let chain?, let key?):
            tls = TLSFiles(certificateChainPath: chain, privateKeyPath: key, clientCertificateAuthorityPath: clientCAPath)
        case (_?, nil):
            throw .missing(variable: Variable.tlsPrivateKeyPath)
        case (nil, _?):
            throw .missing(variable: Variable.tlsCertificateChainPath)
        case (nil, nil):
            guard clientCAPath == nil else {
                throw .invalid(
                    variable: Variable.tlsClientCAPath,
                    reason: "needs \(Variable.tlsCertificateChainPath) and \(Variable.tlsPrivateKeyPath)"
                )
            }
            guard self.environment == .development else {
                throw .missing(variable: Variable.tlsCertificateChainPath)
            }
            tls = nil
        }
    }
}

// MARK: - CustomStringConvertible

extension AppConfiguration: CustomStringConvertible {
    package var description: String {
        "AppConfiguration(host: \(host), port: \(port), database: \(database), "
            + "logLevel: \(logLevel), environment: \(environment.rawValue), "
            + "tls: \(tls == nil ? "disabled" : "enabled"), "
            + "clientCertificates: \(tls?.clientCertificateAuthorityPath == nil ? "off" : "required"), "
            + "apiDocs: \(apiDocsEnabled ? "enabled" : "disabled"))"
    }
}
