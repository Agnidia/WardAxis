//
//  PostgresConfigChangeNotifier.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Logging
import PostgresNIO

/// ``ConfigChangeNotifier`` on PostgreSQL `LISTEN config_changes`.
///
/// Holds one pool connection while it listens. Any end of the notification sequence
/// counts as a disconnect: it listens again after a backoff, and each successful LISTEN
/// yields a wake-up, so the relay catches up on what committed in between. LISTEN does
/// not work through a transaction-pooling proxy such as PgBouncer in transaction mode.
package struct PostgresConfigChangeNotifier: ConfigChangeNotifier {
    /// The channel migration 6's trigger notifies.
    package static let channel: String = "config_changes"

    private let client: PostgresClient
    private let backoff: RetryBackoff
    private let logger: Logger

    package init(client: PostgresClient, backoff: RetryBackoff, logger: Logger) {
        self.client = client
        self.backoff = backoff
        self.logger = logger
    }

    package func wakeUps() -> AsyncStream<Void> {
        // One pending wake-up is enough: the relay reads every change after its last one.
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        let listener = Task {
            await listen(into: continuation)
        }
        continuation.onTermination = { _ in listener.cancel() }
        return stream
    }

    private func listen(into continuation: AsyncStream<Void>.Continuation) async {
        var attempt = 0
        while !Task.isCancelled {
            do {
                try await client.withConnection { connection in
                    try await connection.listen(on: Self.channel) { notifications in
                        attempt = 0
                        continuation.yield()
                        for try await _ in notifications {
                            continuation.yield()
                        }
                    }
                }
            } catch {
                if Task.isCancelled {
                    break
                }
                // The type only: a driver error can carry connection details.
                logger.warning("Config change listener lost its connection", metadata: ["error.type": "\(type(of: error))"])
            }
            attempt += 1
            do {
                try await Task.sleep(for: backoff.delay(forAttempt: attempt))
            } catch {
                break
            }
        }
        continuation.finish()
    }
}
