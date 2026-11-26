//
//  ConfigConnectionHub.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import NIOConcurrencyHelpers

/// One delta, encoded once as a `ConfigMessage` text frame and shared by every subscriber.
package struct ConfigDeltaFrame: Sendable, Equatable {
    package let version: Int64
    package let text: String
    
    package init(version: Int64, text: String) {
        self.version = version
        self.text = text
    }
}

/// A registered stream: the connection slot it holds and the deltas published after it
/// registered.
package struct ConfigSubscription: Sendable {
    package let id: UInt64
    package let client: ConfigStreamClient
    package let frames: AsyncStream<ConfigDeltaFrame>
}

/// The open config streams of this process: the per-client connection cap and the delta
/// fan-out. One instance per process, so the cap counts per instance.
///
/// A locked class with a synchronous API rather than an actor, so a session releases its
/// slot in a `defer`, which cannot await; with an actor a cancelled session could leak
/// its slot. Each subscription keeps only the newest deltas: a slow reader loses the
/// oldest, and its session refetches the gap from the store, so memory stays bounded
/// and the client still sees every version.
///
/// The hub also carries the relay's readiness. The relay publishes every version above
/// the one it read at start, so a snapshot read before that read could predate it, and the
/// versions in between would reach no client. Sessions therefore read their snapshot only
/// once ``isRelayReady`` is true.
package final class ConfigConnectionHub: Sendable {
    private struct Subscriber {
        let client: ConfigStreamClient
        let continuation: AsyncStream<ConfigDeltaFrame>.Continuation
    }
    
    private struct State {
        var nextID: UInt64 = 0
        var subscribers: [UInt64: Subscriber] = [:]
        var connectionsPerClient: [ConfigStreamClient: Int] = [:]
        var relayReady: Bool = false
        var nextWaiterID: UInt64 = 0
        var readinessWaiters: [UInt64: CheckedContinuation<Bool, Never>] = [:]
    }
    
    package let maxConnectionsPerClient: Int
    private let bufferSize: Int
    private let state: NIOLockedValueBox<State> = .init(State())
    
    package init(maxConnectionsPerClient: Int, bufferSize: Int) {
        self.maxConnectionsPerClient = maxConnectionsPerClient
        self.bufferSize = bufferSize
    }
    
    /// Takes a connection slot for `client` and subscribes to deltas, in one atomic step.
    ///
    /// - Returns: `nil` when the client already holds ``maxConnectionsPerClient`` slots.
    package func register(client: ConfigStreamClient) -> ConfigSubscription? {
        state.withLockedValue { state in
            let held = state.connectionsPerClient[client, default: 0]
            guard held < maxConnectionsPerClient else { return nil }
            let (frames, continuation) = AsyncStream.makeStream(
                of: ConfigDeltaFrame.self,
                bufferingPolicy: .bufferingNewest(bufferSize)
            )
            state.nextID += 1
            let id = state.nextID
            state.subscribers[id] = Subscriber(client: client, continuation: continuation)
            state.connectionsPerClient[client] = held + 1
            return ConfigSubscription(id: id, client: client, frames: frames)
        }
    }
    
    /// Releases the slot and ends the subscription's stream. Calling it twice is harmless.
    package func unregister(_ subscription: ConfigSubscription) {
        let removed = state.withLockedValue { state -> Subscriber? in
            guard let subscriber = state.subscribers.removeValue(forKey: subscription.id) else { return nil }
            let remaining = state.connectionsPerClient[subscriber.client, default: 1] - 1
            state.connectionsPerClient[subscriber.client] = remaining > 0 ? remaining : nil
            return subscriber
        }
        removed?.continuation.finish()
    }
    
    /// Hands `frame` to every subscriber without waiting. Under the lock, so concurrent
    /// publishers cannot interleave frames out of version order.
    package func publish(_ frame: ConfigDeltaFrame) {
        state.withLockedValue { state in
            for subscriber in state.subscribers.values {
                subscriber.continuation.yield(frame)
            }
        }
    }
    
    package func connectionCount(for client: ConfigStreamClient) -> Int {
        state.withLockedValue { $0.connectionsPerClient[client, default: 0] }
    }
    
    package var subscriberCount: Int {
        state.withLockedValue { $0.subscribers.count }
    }
    
    // MARK: Relay readiness
    
    /// Whether the relay has read its start version, so it publishes every later version.
    package var isRelayReady: Bool {
        state.withLockedValue { $0.relayReady }
    }
    
    /// Records that the relay has read its start version and wakes every waiting session.
    /// Calling it again changes nothing.
    package func markRelayReady() {
        let waiters = state.withLockedValue { state -> [CheckedContinuation<Bool, Never>] in
            state.relayReady = true
            let waiters = Array(state.readinessWaiters.values)
            state.readinessWaiters.removeAll()
            return waiters
        }
        for waiter in waiters {
            waiter.resume(returning: true)
        }
    }
    
    /// Suspends until ``markRelayReady()`` runs.
    ///
    /// - Returns: `true` once the relay is ready; `false` when the calling task is
    ///   cancelled first, as it is when a timeout races this call.
    package func awaitRelayReady() async -> Bool {
        let waiterID = state.withLockedValue { state -> UInt64? in
            guard !state.relayReady else { return nil }
            state.nextWaiterID += 1
            return state.nextWaiterID
        }
        guard let waiterID else { return true }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                // Decided under the lock that `markRelayReady()` and the cancellation
                // handler take, so the continuation resumes exactly once: a cancellation
                // that ran before this point finds no waiter, and this check sees it.
                let immediate = state.withLockedValue { state -> Bool? in
                    if state.relayReady {
                        return true
                    }
                    if Task.isCancelled {
                        return false
                    }
                    state.readinessWaiters[waiterID] = continuation
                    return nil
                }
                if let immediate {
                    continuation.resume(returning: immediate)
                }
            }
        } onCancel: {
            let waiter = state.withLockedValue { $0.readinessWaiters.removeValue(forKey: waiterID) }
            waiter?.resume(returning: false)
        }
    }
}
