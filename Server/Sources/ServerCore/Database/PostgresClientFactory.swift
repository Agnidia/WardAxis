//
//  PostgresClientFactory.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Logging
import PostgresNIO

/// The single place that turns a ``DatabaseConfiguration`` into a PostgresNIO client.
package enum PostgresClientFactory {
    /// Creates a client. It serves no query until its `run()` starts, which the
    /// application's service group does.
    package static func makeClient(configuration: DatabaseConfiguration, logger: Logger) -> PostgresClient {
        var tlsConfiguration: TLSConfiguration = .makeClientConfiguration()
        tlsConfiguration.minimumTLSVersion = ServerTLS.minimumVersion
        let tls: PostgresClient.Configuration.TLS = switch configuration.tls {
        case .disable:
            .disable
        case .prefer:
            .prefer(tlsConfiguration)
        case .require:
            .require(tlsConfiguration)
        }
        let clientConfiguration = PostgresClient.Configuration(
            host: configuration.host,
            port: configuration.port,
            username: configuration.username,
            password: configuration.password?.value,
            database: configuration.database,
            tls: tls
        )
        return PostgresClient(configuration: clientConfiguration, backgroundLogger: logger)
    }
}
