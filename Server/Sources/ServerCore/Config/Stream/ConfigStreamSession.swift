//
//  ConfigStreamSession.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import HummingbirdWebSocket
import Logging
import NIOWebSocket

/// One upgraded `GET /v1/config/stream` connection, from admission to close.
///
/// One task writes every frame, so frames leave in version order and the current version
/// needs no lock. A sibling task drains `inbound`: the library answers pings and records
/// pongs only while something iterates it, so without the drain the idle timer would
/// close a healthy connection. When the client goes away the drain ends, and so does the
/// session.
struct ConfigStreamSession {
    /// Close code 1013 (Try Again Later), which `WebSocketErrorCode` has no case for.
    static let tryAgainLater: WebSocketErrorCode = .unknown(1013)
    
    /// Close code 1000 with this reason ends a stream at its lifetime cap; the client
    /// reconnects at once with a new TLS handshake.
    static let lifetimeReason: String = "lifetime"
    
    let store: any ConfigStore
    let hub: ConfigConnectionHub
    let policy: ConfigStreamPolicy
    let logger: Logger
    
    private enum Event: Sendable {
        case delta(ConfigDeltaFrame)
        case heartbeat
        case lifetimeReached
    }
    
    private enum TaskEnd: Sendable {
        case clientGone
        case serverClosed
        case writeFailed
        case graceElapsed
        case idle
    }
    
    private enum RelayReadiness: Sendable {
        case alreadyReady
        case readyAfterWait
        case timedOut
        case cancelled
    }
    
    /// - Parameter client: Set by ``ConfigStreamAdmissionMiddleware``; `nil` only if the
    ///   route was mounted without it, and then the stream closes with 1011 before any frame.
    func run(client: ConfigStreamClient?, inbound: WebSocketInboundStream, outbound: WebSocketOutboundWriter) async {
        // Counted from the upgrade, so a slow relay start does not extend it.
        let lifetimeDeadline = ContinuousClock.now + policy.connectionLifetime()
        guard let client else {
            await close(outbound, code: .unexpectedServerError, reason: nil, cause: "no_client_certificate")
            return
        }
        guard let subscription = hub.register(client: client) else {
            await close(outbound, code: Self.tryAgainLater, reason: "too many connections", cause: "connection_limit")
            return
        }
        defer { hub.unregister(subscription) }
        
        // A snapshot read before the relay reads its start version can be older than that
        // version. The versions in between then get no delta, and the client misses them
        // until the next change.
        switch await relayReadiness() {
        case .alreadyReady, .readyAfterWait:
            break
        case .timedOut:
            await close(outbound, code: Self.tryAgainLater, reason: "server starting", cause: "relay_not_ready")
            return
        case .cancelled:
            return
        }
        
        // Subscribed before the snapshot is read: a delta that committed before the
        // snapshot has a version the snapshot covers and is skipped, and one that
        // committed after it arrives through the subscription.
        let snapshot: ConfigSnapshotRecord
        do {
            snapshot = try await store.snapshot()
        } catch {
            logger.error("Config stream cannot read the snapshot", metadata: ["error.type": "\(type(of: error))"])
            await close(outbound, code: .unexpectedServerError, reason: nil, cause: "store_error")
            return
        }
        do {
            try await outbound.writeTextMessage(ConfigFrameEncoder.snapshot(snapshot))
        } catch {
            logger.debug("Config stream ended before the snapshot was sent", metadata: ["error.type": "\(type(of: error))"])
            return
        }
        
        let (events, sink) = AsyncStream.makeStream(of: Event.self, bufferingPolicy: .bufferingNewest(policy.subscriberBufferSize))
        await withTaskGroup(of: TaskEnd.self) { group in
            group.addTask {
                await drain(inbound)
                return .clientGone
            }
            group.addTask {
                await writeFrames(from: events, startingAt: snapshot.version, outbound: outbound)
            }
            group.addTask {
                for await frame in subscription.frames {
                    sink.yield(.delta(frame))
                }
                return .idle
            }
            group.addTask {
                await tick(every: policy.heartbeatInterval) { sink.yield(.heartbeat) }
                return .idle
            }
            group.addTask {
                // Through the writer, like every other close, so the lifetime close never
                // interleaves with a frame being written.
                do {
                    try await Task.sleep(until: lifetimeDeadline, clock: .continuous)
                    sink.yield(.lifetimeReached)
                } catch {}
                return .idle
            }
            for await end in group {
                switch end {
                case .idle:
                    continue
                case .serverClosed:
                    // Let the client answer the close frame, but do not hold the slot for
                    // a client that never does.
                    group.addTask {
                        try? await Task.sleep(for: policy.closeGracePeriod)
                        return .graceElapsed
                    }
                case .clientGone, .writeFailed, .graceElapsed:
                    group.cancelAll()
                }
            }
        }
    }
    
    /// Waits for the relay to start, at most ``ConfigStreamPolicy/relayReadyTimeout``. The
    /// session keeps its slot meanwhile, so the per-user cap still holds.
    private func relayReadiness() async -> RelayReadiness {
        if hub.isRelayReady {
            return .alreadyReady
        }
        let hub = hub
        let timeout = policy.relayReadyTimeout
        return await withTaskGroup(of: RelayReadiness.self) { group in
            group.addTask {
                await hub.awaitRelayReady() ? .readyAfterWait : .cancelled
            }
            group.addTask {
                do {
                    try await Task.sleep(for: timeout)
                } catch {
                    return .cancelled
                }
                return .timedOut
            }
            let first = await group.next() ?? .cancelled
            group.cancelAll()
            return first
        }
    }
    
    /// Consumes `events` until the session closes the stream or a write fails.
    private func writeFrames(
        from events: AsyncStream<Event>,
        startingAt version: Int64,
        outbound: WebSocketOutboundWriter
    ) async -> TaskEnd {
        var currentVersion = version
        do {
            for await event in events {
                switch event {
                case .delta(let frame):
                    guard frame.version > currentVersion else { continue }
                    if frame.version > currentVersion + 1 {
                        // The subscription dropped frames: send the missing ones from the
                        // store, which holds every version.
                        guard let filled = try await sendStoredChanges(after: currentVersion, through: frame.version, outbound: outbound) else {
                            await close(outbound, code: .unexpectedServerError, reason: nil, cause: "gap_unfillable")
                            return .serverClosed
                        }
                        currentVersion = filled
                        continue
                    }
                    try await outbound.writeTextMessage(frame.text)
                    currentVersion = frame.version
                case .heartbeat:
                    try await outbound.writeTextMessage(ConfigFrameEncoder.heartbeat(version: currentVersion))
                case .lifetimeReached:
                    await close(outbound, code: .normalClosure, reason: Self.lifetimeReason, cause: "lifetime")
                    return .serverClosed
                }
            }
        } catch {
            logger.debug("Config stream write failed", metadata: ["error.type": "\(type(of: error))"])
            return .writeFailed
        }
        return .idle
    }
    
    /// Sends the stored changes after `version` up to `target`, in order.
    ///
    /// - Returns: The last version sent; `nil` when the store cannot be read or its log
    ///   has a gap, in which case the client needs a new snapshot.
    private func sendStoredChanges(after version: Int64, through target: Int64, outbound: WebSocketOutboundWriter) async throws -> Int64? {
        var currentVersion = version
        while currentVersion < target {
            let changes: [ConfigChange]
            do {
                changes = try await store.changes(after: currentVersion, limit: policy.catchUpBatchSize)
            } catch {
                logger.error("Config stream cannot read changes", metadata: ["error.type": "\(type(of: error))"])
                return nil
            }
            guard !changes.isEmpty else { return nil }
            for change in changes {
                guard change.version == currentVersion + 1 else { return nil }
                try await outbound.writeTextMessage(ConfigFrameEncoder.delta(change).text)
                currentVersion = change.version
            }
        }
        return currentVersion
    }
    
    /// Reads and discards client frames. Ends on the client's close frame or a dropped connection.
    private func drain(_ inbound: WebSocketInboundStream) async {
        do {
            for try await _ in inbound {}
        } catch {
            logger.debug("Config stream inbound ended with an error", metadata: ["error.type": "\(type(of: error))"])
        }
    }
    
    private func tick(every interval: Duration, _ action: () -> Void) async {
        while true {
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }
            action()
        }
    }
    
    private func close(_ outbound: WebSocketOutboundWriter, code: WebSocketErrorCode, reason: String?, cause: String) async {
        logger.info("Config stream closed by the server", metadata: ["config.close.cause": "\(cause)"])
        do {
            try await outbound.close(code, reason: reason)
        } catch {
            logger.debug("Config stream close frame not sent", metadata: ["error.type": "\(type(of: error))"])
        }
    }
}
