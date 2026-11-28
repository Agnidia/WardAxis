//
//  ServerDependencies+Production.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Logging
import PostgresNIO

package extension ServerDependencies {
    /// The production composition root.
    ///
    /// - Parameter logger: The server logger; the stores get ``Logging/Logger/cappedForPostgres()``.
    static func production(
        configuration: AppConfiguration,
        client: PostgresClient,
        logger: Logger
    ) -> ServerDependencies {
        let streamPolicy = ConfigStreamPolicy.standard
        let storeLogger = logger.cappedForPostgres()
        return ServerDependencies(
            databaseProbe: PostgresHealthProbe(client: client, logger: Logger(label: "server.health")),
            configStore: PostgresConfigStore(client: client, logger: storeLogger),
            configNotifier: PostgresConfigChangeNotifier(client: client, backoff: streamPolicy.retryBackoff, logger: logger),
            configStreamPolicy: streamPolicy,
            apiDocs: configuration.apiDocsEnabled ? APIDocs.bundled() : nil,
            environment: configuration.environment
        )
    }
}
