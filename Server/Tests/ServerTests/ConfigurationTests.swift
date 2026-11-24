//
//  ConfigurationTests.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Logging
import ServerCore
import Testing

@Suite("Configuration")
struct ConfigurationTests {
    // Sample values only: distinctive strings that the redaction tests search for.
    private static let samplePasswordText: String = "Pa55-w0rd-sample"
    private static let sampleURL: String = "postgres://app:\(samplePasswordText)@db.internal:6543/appdb?sslmode=require"
    // Parsing reads the paths only; `ServerTLS` opens the files, in `TLSListenerTests`.
    private static let sampleChainPath: String = "/run/secrets/tls-sample/chain.pem"
    private static let sampleKeyPath: String = "/run/secrets/tls-sample/key.pem"
    private static let sampleClientCAPath: String = "/run/secrets/tls-sample/device-ca.pem"
    
    /// Production (the default) with every required variable, TLS included.
    private static var completeEnvironment: [String: String] {
        [
            AppConfiguration.Variable.databaseURL: sampleURL,
            AppConfiguration.Variable.tlsCertificateChainPath: sampleChainPath,
            AppConfiguration.Variable.tlsPrivateKeyPath: sampleKeyPath
        ]
    }
    
    @Test
    func `Defaults apply when only the required variables are set`() throws {
        let configuration = try AppConfiguration(environment: Self.completeEnvironment)
        
        #expect(configuration.host == "0.0.0.0")
        #expect(configuration.port == 8080)
        #expect(configuration.logLevel == .info)
        #expect(configuration.environment == .production)
        #expect(configuration.database.host == "db.internal")
        #expect(configuration.database.port == 6543)
        #expect(configuration.database.username == "app")
        #expect(configuration.database.password?.value == Self.samplePasswordText)
        #expect(configuration.database.database == "appdb")
        #expect(configuration.database.tls == .require)
        #expect(configuration.tls == TLSFiles(certificateChainPath: Self.sampleChainPath, privateKeyPath: Self.sampleKeyPath))
        #expect(configuration.tls?.clientCertificateAuthorityPath == nil)
    }
    
    @Test
    func `Optional variables override the defaults`() throws {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.host] = "127.0.0.1"
        environment[AppConfiguration.Variable.port] = "9090"
        environment[AppConfiguration.Variable.logLevel] = "DEBUG"
        
        let configuration = try AppConfiguration(environment: environment)
        
        #expect(configuration.host == "127.0.0.1")
        #expect(configuration.port == 9090)
        #expect(configuration.logLevel == .debug)
    }
    
    @Test(
        arguments: [AppConfiguration.Variable.databaseURL]
    )
    func `A missing or empty required variable throws an error that names it`(variable: String) {
        var absent = Self.completeEnvironment
        absent[variable] = nil
        #expect(throws: ConfigurationError.missing(variable: variable)) {
            try AppConfiguration(environment: absent)
        }
        
        var empty = Self.completeEnvironment
        empty[variable] = ""
        #expect(throws: ConfigurationError.missing(variable: variable)) {
            try AppConfiguration(environment: empty)
        }
        
        let message = ConfigurationError.missing(variable: variable).description
        #expect(message.contains(variable))
    }
    
    @Test(
        arguments: [
            (AppConfiguration.Variable.port, "0"),
            (AppConfiguration.Variable.port, "65536"),
            (AppConfiguration.Variable.port, "http"),
            (AppConfiguration.Variable.logLevel, "verbose"),
            (AppConfiguration.Variable.serverEnvironment, "staging")
        ]
    )
    func `An invalid optional variable throws an error that names it`(variable: String, value: String) {
        var environment = Self.completeEnvironment
        environment[variable] = value
        
        do throws(ConfigurationError) {
            _ = try AppConfiguration(environment: environment)
            Issue.record("Expected \(variable) to be rejected")
        } catch {
            guard case let .invalid(reported, _) = error else {
                Issue.record("Expected .invalid, got \(error)")
                return
            }
            #expect(reported == variable)
            #expect(!error.description.contains(value))
        }
    }
    
    @Test(
        arguments: [
            "mysql://app:Pa55-w0rd-sample@db/appdb",
            "postgres://db.internal/appdb",
            "postgres://app:Pa55-w0rd-sample@/appdb",
            "postgres://app:Pa55-w0rd-sample@db.internal",
            "postgres://app:Pa55-w0rd-sample@db.internal/appdb?sslmode=verify-full"
        ]
    )
    func `A malformed DATABASE_URL is rejected without quoting it`(url: String) {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.databaseURL] = url
        
        do throws(ConfigurationError) {
            _ = try AppConfiguration(environment: environment)
            Issue.record("Expected the URL to be rejected")
        } catch {
            guard case let .invalid(reported, _) = error else {
                Issue.record("Expected .invalid, got \(error)")
                return
            }
            #expect(reported == AppConfiguration.Variable.databaseURL)
            #expect(!error.description.contains(Self.samplePasswordText))
            #expect(!error.description.contains("db.internal"))
        }
    }
    
    @Test
    func `DATABASE_URL defaults: port 5432, sslmode require, percent-decoded password, no password`() throws {
        let encoded = try DatabaseConfiguration(url: "postgresql://app:p%40ss%2Fword@db/appdb", variable: "URL")
        #expect(encoded.port == DatabaseConfiguration.defaultPort)
        #expect(encoded.tls == .require)
        #expect(encoded.password?.value == "p@ss/word")
        
        let trusted = try DatabaseConfiguration(url: "postgres://postgres@db:5432/postgres?sslmode=disable", variable: "URL")
        #expect(trusted.password == nil)
        #expect(trusted.tls == .disable)
        let preferred = try DatabaseConfiguration(url: "postgres://app@db/appdb?sslmode=prefer", variable: "URL")
        #expect(preferred.tls == .prefer)
    }
    
    @Test
    func `No textual form of the configuration contains the password or a TLS path`() throws {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.tlsClientCAPath] = Self.sampleClientCAPath
        let configuration = try AppConfiguration(environment: environment)
        
        var dumped = ""
        dump(configuration, to: &dumped)
        let renderings = [
            String(describing: configuration),
            String(reflecting: configuration),
            "\(configuration)",
            String(describing: configuration.database),
            dumped
        ]
        for text in renderings {
            #expect(!text.contains(Self.samplePasswordText))
        }
        #expect(!String(describing: configuration).contains(Self.sampleClientCAPath))
        #expect(String(describing: configuration).contains("<redacted>"))
    }
    
    // MARK: Environment
    
    @Test
    func `SERVER_ENVIRONMENT accepts development and production; absent or empty means production`() throws {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.serverEnvironment] = "development"
        #expect(try AppConfiguration(environment: environment).environment == .development)
        environment[AppConfiguration.Variable.serverEnvironment] = "production"
        #expect(try AppConfiguration(environment: environment).environment == .production)
        environment[AppConfiguration.Variable.serverEnvironment] = ""
        #expect(try AppConfiguration(environment: environment).environment == .production)
    }
    
    // MARK: TLS
    
    @Test(
        arguments: [
            (nil, nil, AppConfiguration.Variable.tlsCertificateChainPath),
            ("", "", AppConfiguration.Variable.tlsCertificateChainPath),
            (sampleChainPath, nil, AppConfiguration.Variable.tlsPrivateKeyPath),
            (nil, sampleKeyPath, AppConfiguration.Variable.tlsCertificateChainPath)
        ] as [(String?, String?, String)]
    )
    func `Production without both TLS paths fails start-up and names the missing one`(chainPath: String?, keyPath: String?, missing: String) {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.tlsCertificateChainPath] = chainPath
        environment[AppConfiguration.Variable.tlsPrivateKeyPath] = keyPath
        #expect(throws: ConfigurationError.missing(variable: missing)) {
            try AppConfiguration(environment: environment)
        }
        environment[AppConfiguration.Variable.serverEnvironment] = "production"
        #expect(throws: ConfigurationError.missing(variable: missing)) {
            try AppConfiguration(environment: environment)
        }
    }
    
    @Test
    func `Development without TLS paths parses and serves plain HTTP`() throws {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.serverEnvironment] = "development"
        environment[AppConfiguration.Variable.tlsCertificateChainPath] = nil
        environment[AppConfiguration.Variable.tlsPrivateKeyPath] = nil
        let configuration = try AppConfiguration(environment: environment)
        #expect(configuration.tls == nil)
        #expect(String(describing: configuration).contains("tls: disabled"))
    }
    
    @Test(
        arguments: [
            (sampleChainPath, nil, AppConfiguration.Variable.tlsPrivateKeyPath),
            (nil, sampleKeyPath, AppConfiguration.Variable.tlsCertificateChainPath)
        ] as [(String?, String?, String)]
    )
    func `Development with only one TLS path fails rather than falling back to plain HTTP`(chainPath: String?, keyPath: String?, missing: String) {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.serverEnvironment] = "development"
        environment[AppConfiguration.Variable.tlsCertificateChainPath] = chainPath
        environment[AppConfiguration.Variable.tlsPrivateKeyPath] = keyPath
        #expect(throws: ConfigurationError.missing(variable: missing)) {
            try AppConfiguration(environment: environment)
        }
    }
    
    @Test(arguments: ServerEnvironment.allCases)
    func `Both TLS paths enable TLS in either environment, and the description says only that`(environmentValue: ServerEnvironment) throws {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.serverEnvironment] = environmentValue.rawValue
        let configuration = try AppConfiguration(environment: environment)
        #expect(configuration.tls == TLSFiles(certificateChainPath: Self.sampleChainPath, privateKeyPath: Self.sampleKeyPath))
        let text = String(describing: configuration)
        #expect(text.contains("tls: enabled"))
        #expect(!text.contains(Self.sampleKeyPath))
    }
    
    @Test(arguments: ServerEnvironment.allCases)
    func `TLS_CLIENT_CA_PATH with both TLS paths requires client certificates, in either environment`(environmentValue: ServerEnvironment) throws {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.serverEnvironment] = environmentValue.rawValue
        environment[AppConfiguration.Variable.tlsClientCAPath] = Self.sampleClientCAPath
        let configuration = try AppConfiguration(environment: environment)
        #expect(configuration.tls?.clientCertificateAuthorityPath == Self.sampleClientCAPath)
        let text = String(describing: configuration)
        #expect(text.contains("clientCertificates: required"))
        #expect(!text.contains(Self.sampleClientCAPath))
    }
    
    @Test
    func `An empty TLS_CLIENT_CA_PATH counts as unset: TLS without client certificates`() throws {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.tlsClientCAPath] = ""
        let configuration = try AppConfiguration(environment: environment)
        #expect(configuration.tls?.clientCertificateAuthorityPath == nil)
        #expect(String(describing: configuration).contains("clientCertificates: off"))
    }
    
    @Test(
        arguments: [
            ("development", nil, nil),
            ("production", nil, nil),
            ("development", "", "")
        ] as [(String, String?, String?)]
    )
    func `TLS_CLIENT_CA_PATH without the server chain and key fails start-up, naming the variable and never the path`(serverEnvironment: String, chainPath: String?, keyPath: String?) {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.serverEnvironment] = serverEnvironment
        environment[AppConfiguration.Variable.tlsCertificateChainPath] = chainPath
        environment[AppConfiguration.Variable.tlsPrivateKeyPath] = keyPath
        environment[AppConfiguration.Variable.tlsClientCAPath] = Self.sampleClientCAPath
        do throws(ConfigurationError) {
            _ = try AppConfiguration(environment: environment)
            Issue.record("Expected TLS_CLIENT_CA_PATH alone to be rejected")
        } catch {
            guard case let .invalid(reported, _) = error else {
                Issue.record("Expected .invalid, got \(error)")
                return
            }
            #expect(reported == AppConfiguration.Variable.tlsClientCAPath)
            #expect(!error.description.contains(Self.sampleClientCAPath))
        }
    }
    
    @Test
    func `compose.yaml and .env.example run the stack in development`() throws {
        let serverDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for name in ["compose.yaml", ".env.example"] {
            let text = try String(contentsOf: serverDirectory.appendingPathComponent(name), encoding: .utf8)
            #expect(text.contains("SERVER_ENVIRONMENT"), "\(name) must set SERVER_ENVIRONMENT")
            #expect(text.contains("development"), "\(name) must default to development")
        }
        // Named for discovery only: no committed file holds a TLS path, key or certificate.
        let example = try String(contentsOf: serverDirectory.appendingPathComponent(".env.example"), encoding: .utf8)
        for variable in [
            AppConfiguration.Variable.tlsCertificateChainPath,
            AppConfiguration.Variable.tlsPrivateKeyPath,
            AppConfiguration.Variable.tlsClientCAPath
        ] {
            #expect(example.contains("# \(variable)="), "\(variable) must appear commented out and empty")
            #expect(!example.contains("\n\(variable)="), "\(variable) must not be set")
        }
    }
    
    // MARK: - API_DOCS_ENABLED
    
    @Test
    func `API docs default to on in development and off in production or when SERVER_ENVIRONMENT is unset`() throws {
        var environment = Self.completeEnvironment
        let unset = try AppConfiguration(environment: environment)
        #expect(unset.environment == .production)
        #expect(unset.apiDocsEnabled == false)
        #expect(String(describing: unset).contains("apiDocs: disabled"))
        
        environment[AppConfiguration.Variable.serverEnvironment] = "production"
        #expect(try AppConfiguration(environment: environment).apiDocsEnabled == false)
        
        environment[AppConfiguration.Variable.serverEnvironment] = "development"
        let development = try AppConfiguration(environment: environment)
        #expect(development.apiDocsEnabled == true)
        #expect(String(describing: development).contains("apiDocs: enabled"))
        
        // Empty counts as missing, as for every other variable.
        environment[AppConfiguration.Variable.apiDocsEnabled] = ""
        #expect(try AppConfiguration(environment: environment).apiDocsEnabled == true)
    }
    
    @Test(arguments: [true, false])
    func `An explicit API_DOCS_ENABLED wins in development`(enabled: Bool) throws {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.serverEnvironment] = "development"
        environment[AppConfiguration.Variable.apiDocsEnabled] = enabled ? "true" : "false"
        #expect(try AppConfiguration(environment: environment).apiDocsEnabled == enabled)
    }
    
    @Test(
        arguments: ["production", nil], [nil, "", "false"]
    )
    func `Production keeps docs off with API_DOCS_ENABLED unset, empty or false, also when SERVER_ENVIRONMENT is unset`(serverEnvironment: String?, value: String?) throws {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.serverEnvironment] = serverEnvironment
        environment[AppConfiguration.Variable.apiDocsEnabled] = value
        let configuration = try AppConfiguration(environment: environment)
        #expect(configuration.environment == .production)
        #expect(configuration.apiDocsEnabled == false)
    }
    
    @Test(
        arguments: ["production", nil]
    )
    func `Production refuses to start with API_DOCS_ENABLED=true, also when SERVER_ENVIRONMENT is unset`(serverEnvironment: String?) {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.serverEnvironment] = serverEnvironment
        environment[AppConfiguration.Variable.apiDocsEnabled] = "true"
        let expected = ConfigurationError.invalid(variable: "API_DOCS_ENABLED", reason: "must not be true in production")
        #expect(throws: expected) {
            _ = try AppConfiguration(environment: environment)
        }
        #expect(expected.description == "Invalid environment variable API_DOCS_ENABLED: must not be true in production")
    }
    
    @Test(
        arguments: ["yes", "no", "1", "0", "TRUE", "False", " true", "on"]
    )
    func `API_DOCS_ENABLED accepts only true or false`(value: String) {
        var environment = Self.completeEnvironment
        environment[AppConfiguration.Variable.serverEnvironment] = "development"
        environment[AppConfiguration.Variable.apiDocsEnabled] = value
        #expect(AppConfiguration.Variable.apiDocsEnabled == "API_DOCS_ENABLED")
        #expect(throws: ConfigurationError.invalid(variable: "API_DOCS_ENABLED", reason: "must be true or false")) {
            _ = try AppConfiguration(environment: environment)
        }
    }
    
    @Test
    func `compose.yaml passes API_DOCS_ENABLED through empty, and .env.example documents it`() throws {
        let serverDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let compose = try String(contentsOf: serverDirectory.appendingPathComponent("compose.yaml"), encoding: .utf8)
        #expect(compose.contains("API_DOCS_ENABLED: ${API_DOCS_ENABLED:-}"))
        let example = try String(contentsOf: serverDirectory.appendingPathComponent(".env.example"), encoding: .utf8)
        #expect(example.contains("API_DOCS_ENABLED"))
    }
}
