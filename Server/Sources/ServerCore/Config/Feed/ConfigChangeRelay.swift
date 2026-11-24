//
//  ConfigChangeRelay.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Logging
import ServiceLifecycle

/// Moves committed configuration changes from the store to every open config stream.
///
/// A notifier wake-up and a periodic poll both trigger one catch-up: a read of every
/// change after the last one relayed, in version order. A lost notification or a
/// silently dead LISTEN connection therefore delays a change by at most one poll
/// interval and never drops it. Each change is encoded once and handed to the hub.
///
/// Runs as an application service. It starts while the start-up migrations may still
/// run, so it retries its first read until the config tables exist. Config streams wait
/// for that first read (``ConfigConnectionHub/markRelayReady()``) before their snapshot.
package struct ConfigChangeRelay: Service {
    private let store: any ConfigStore
    private let notifier: any ConfigChangeNotifier
    private let hub: ConfigConnectionHub
    private let policy: ConfigStreamPolicy
    private let logger: Logger

    package init(
        store: any ConfigStore,
        notifier: any ConfigChangeNotifier,
        hub: ConfigConnectionHub,
        policy: ConfigStreamPolicy,
        logger: Logger
    ) {
        self.store = store
        self.notifier = notifier
        self.hub = hub
        self.policy = policy
        self.logger = logger
    }

    /// Returns only on graceful shutdown or cancellation: a service that returns early
    /// ends the whole application.
    package func run() async throws {
        await cancelWhenGracefulShutdown {
            await relay()
        }
    }

    private func relay() async {
        guard let startVersion = await startingVersion() else { return }
        // From here every version above `startVersion` reaches the hub, so a snapshot read
        // from now on leaves no gap before its first delta.
        hub.markRelayReady()
        let (triggers, trigger) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in notifier.wakeUps() {
                    trigger.yield()
                }
            }
            group.addTask {
                while true {
                    do {
                        try await Task.sleep(for: policy.relayPollInterval)
                    } catch {
                        return
                    }
                    trigger.yield()
                }
            }
            var lastVersion = startVersion
            for await _ in triggers {
                lastVersion = await catchUp(after: lastVersion)
            }
            group.cancelAll()
        }
    }

    /// The store's version at start; `nil` when cancelled before a read succeeds.
    private func startingVersion() async -> Int64? {
        var attempt = 0
        while !Task.isCancelled {
            do {
                return try await store.currentVersion()
            } catch {
                if Task.isCancelled {
                    return nil
                }
                attempt += 1
                logger.warning(
                    "Config relay cannot read the configuration version; retrying",
                    metadata: ["error.type": "\(type(of: error))", "retry.attempt": "\(attempt)"]
                )
                do {
                    try await Task.sleep(for: policy.retryBackoff.delay(forAttempt: attempt))
                } catch {
                    return nil
                }
            }
        }
        return nil
    }

    /// Publishes every stored change after `version` and returns the last version
    /// published. A read error stops early; the next trigger resumes from the same place.
    private func catchUp(after version: Int64) async -> Int64 {
        var lastVersion = version
        while true {
            let changes: [ConfigChange]
            do {
                changes = try await store.changes(after: lastVersion, limit: policy.catchUpBatchSize)
            } catch {
                if !Task.isCancelled {
                    logger.error("Config relay cannot read changes", metadata: ["error.type": "\(type(of: error))"])
                }
                return lastVersion
            }
            for change in changes {
                if change.version != lastVersion + 1 {
                    // Unreachable while the log is never pruned. Sessions see the same gap
                    // and close with 1011, so their clients take a fresh snapshot.
                    logger.error(
                        "Config change log has a gap",
                        metadata: ["config.version.expected": "\(lastVersion + 1)", "config.version.found": "\(change.version)"]
                    )
                }
                do {
                    try hub.publish(ConfigFrameEncoder.delta(change))
                } catch {
                    logger.error("Config relay cannot encode a change", metadata: ["error.type": "\(type(of: error))"])
                }
                lastVersion = change.version
            }
            if changes.count < policy.catchUpBatchSize {
                return lastVersion
            }
        }
    }
}
