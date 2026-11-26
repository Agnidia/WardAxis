//
//  ConfigStreamPolicy.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// Limits and timings of `GET /v1/config/stream`. A value, so a test runs the production
/// code path with sub-second intervals and a small cap.
package struct ConfigStreamPolicy: Sendable, Equatable {
    /// Concurrent streams one client certificate may hold in this process.
    package var maxConnectionsPerClient: Int
    /// Period of `ConfigHeartbeat` frames.
    package var heartbeatInterval: Duration
    /// A connection that answers no ping for this long is closed with code 1001.
    package var idleTimeout: Duration
    /// The longest a stream stays open before the server closes it with 1000 `lifetime`.
    ///
    /// The client certificate is checked only in the TLS handshake. This cap forces a new
    /// handshake, so a certificate that the server stops trusting (a rotated device CA
    /// bundle, or revocation once the handshake checks it) loses the feed within this
    /// bound rather than keeping a stream open indefinitely.
    package var maximumConnectionLifetime: Duration
    /// Up to this much is taken off ``maximumConnectionLifetime`` at random per stream, so
    /// streams opened together, as after a restart, do not all reconnect together.
    package var connectionLifetimeJitter: Duration
    /// Upper bound on delta latency when every notification is lost.
    package var relayPollInterval: Duration
    /// Deltas buffered per subscriber before the oldest are dropped and refetched.
    package var subscriberBufferSize: Int
    package var catchUpBatchSize: Int
    package var retryBackoff: RetryBackoff
    /// How long a session that closed the stream waits for the client's close frame.
    package var closeGracePeriod: Duration
    /// How long a new session waits for the change relay to start before it closes with
    /// 1013. Only streams opened in the first moments after start-up wait at all.
    package var relayReadyTimeout: Duration
    
    package static let standard: ConfigStreamPolicy = .init(
        maxConnectionsPerClient: 5,
        heartbeatInterval: .seconds(30),
        idleTimeout: .seconds(90),
        maximumConnectionLifetime: .seconds(15 * 60),
        connectionLifetimeJitter: .seconds(3 * 60),
        relayPollInterval: .seconds(30),
        subscriberBufferSize: 32,
        catchUpBatchSize: 256,
        retryBackoff: .standard,
        closeGracePeriod: .seconds(5),
        relayReadyTimeout: .seconds(10)
    )
    
    package init(
        maxConnectionsPerClient: Int,
        heartbeatInterval: Duration,
        idleTimeout: Duration,
        maximumConnectionLifetime: Duration,
        connectionLifetimeJitter: Duration,
        relayPollInterval: Duration,
        subscriberBufferSize: Int,
        catchUpBatchSize: Int,
        retryBackoff: RetryBackoff,
        closeGracePeriod: Duration,
        relayReadyTimeout: Duration = .seconds(10)
    ) {
        self.maxConnectionsPerClient = maxConnectionsPerClient
        self.heartbeatInterval = heartbeatInterval
        self.idleTimeout = idleTimeout
        self.maximumConnectionLifetime = maximumConnectionLifetime
        self.connectionLifetimeJitter = connectionLifetimeJitter
        self.relayPollInterval = relayPollInterval
        self.subscriberBufferSize = subscriberBufferSize
        self.catchUpBatchSize = catchUpBatchSize
        self.retryBackoff = retryBackoff
        self.closeGracePeriod = closeGracePeriod
        self.relayReadyTimeout = relayReadyTimeout
    }
    
    /// The WebSocket auto-ping period. The library closes a connection whose pong has not
    /// arrived one period after its ping, so half the idle timeout closes it at
    /// ``idleTimeout``.
    package var pingInterval: Duration {
        idleTimeout / 2
    }
    
    /// One stream's lifetime: ``maximumConnectionLifetime`` less a random share of
    /// ``connectionLifetimeJitter``, never above the maximum and never below zero.
    package func connectionLifetime() -> Duration {
        let jitter = max(connectionLifetimeJitter, .zero)
        guard jitter > .zero else { return maximumConnectionLifetime }
        let fraction = Double.random(in: 0...1)
        return max(maximumConnectionLifetime - jitter * fraction, .zero)
    }
}
