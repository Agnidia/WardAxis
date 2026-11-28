//
//  PostgresHealthProbe.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Logging
import PostgresNIO

/// Probes PostgreSQL with `SELECT 1`, bounded by a timeout.
///
/// A down database can stall a connection attempt for the pool's full connect
/// timeout; health checks need a fast "not ready" instead.
package struct PostgresHealthProbe: DatabaseHealthProbe {
    package static let defaultTimeout: Duration = .seconds(2)
    
    private let client: PostgresClient
    private let timeout: Duration
    private let logger: Logger
    
    package init(client: PostgresClient, timeout: Duration = Self.defaultTimeout, logger: Logger) {
        self.client = client
        self.timeout = timeout
        self.logger = logger
    }
    
    package func isReachable() async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask { [client, logger] in
                do {
                    try await client.query("SELECT 1", logger: logger)
                    return true
                } catch {
                    // The type only: driver errors can carry connection details.
                    logger.warning("Database health probe failed", metadata: .errorType(error))
                    return false
                }
            }
            group.addTask { [timeout] in
                try? await Task.sleep(for: timeout)
                return false
            }
            let reachable: Bool = await group.next() ?? false
            group.cancelAll()
            return reachable
        }
    }
}
