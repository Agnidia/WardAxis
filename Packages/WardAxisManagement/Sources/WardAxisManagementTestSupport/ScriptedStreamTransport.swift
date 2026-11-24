//
//  ScriptedStreamTransport.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Synchronization
import WardAxisManagement

/// ``ConfigurationStreamTransport`` double: each `open` creates a
/// ``Connection`` that a test drives by hand. Never touches the network.
public final class ScriptedStreamTransport: ConfigurationStreamTransport {
    public init() {}

    /// One opened connection: the request it was opened with, and the server side.
    public final class Connection: Sendable {
        public let request: URLRequest
        private let continuation: AsyncStream<ConfigurationStreamEvent>.Continuation
        private let termination = Signal()

        fileprivate init(request: URLRequest, continuation: AsyncStream<ConfigurationStreamEvent>.Continuation) {
            self.request = request
            self.continuation = continuation
        }

        /// `true` once the client side has ended the stream or the server closed it.
        public var isTerminated: Bool {
            termination.isRaised
        }

        public func send(_ event: ConfigurationStreamEvent) {
            continuation.yield(event)
        }

        /// Sends one text frame.
        public func send(frame json: String) {
            continuation.yield(.message(Data(json.utf8)))
        }

        /// Ends the connection from the server side.
        public func close(_ reason: ConfigurationStreamClose) {
            continuation.yield(.closed(reason))
            continuation.finish()
        }

        public func close(code: Int) {
            close(.closeCode(code))
        }

        /// Returns once the stream has ended.
        public func terminated() async {
            await termination.wait()
        }

        fileprivate func markTerminated() {
            termination.raise()
        }
    }

    private struct State {
        var connections: [Connection] = []
        var waiters: [(count: Int, continuation: CheckedContinuation<Connection, Never>)] = []
    }

    private let state = Mutex(State())

    public var openCount: Int {
        state.withLock { $0.connections.count }
    }

    public var connections: [Connection] {
        state.withLock { $0.connections }
    }

    /// The `number`-th connection (1-based), once it has been opened.
    public func connection(_ number: Int) async -> Connection {
        await withCheckedContinuation { continuation in
            let ready: Connection? = state.withLock { state in
                guard state.connections.count >= number else {
                    state.waiters.append((number, continuation))
                    return nil
                }
                return state.connections[number - 1]
            }
            if let ready {
                continuation.resume(returning: ready)
            }
        }
    }

    public func open(_ request: URLRequest, identity _: ClientIdentity) -> AsyncStream<ConfigurationStreamEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: ConfigurationStreamEvent.self, bufferingPolicy: .unbounded)
        let connection = Connection(request: request, continuation: continuation)
        continuation.onTermination = { _ in connection.markTerminated() }
        let ready = state.withLock { state in
            state.connections.append(connection)
            let count = state.connections.count
            let ready = state.waiters.filter { $0.count <= count }
            state.waiters.removeAll { $0.count <= count }
            return ready.map { ($0.continuation, state.connections[$0.count - 1]) }
        }
        for (waiter, opened) in ready {
            waiter.resume(returning: opened)
        }
        return stream
    }
}

/// A one-shot flag that tasks can await.
private final class Signal: Sendable {
    private struct State {
        var isRaised = false
        var waiters: [CheckedContinuation<Void, Never>] = []
    }

    private let state = Mutex(State())

    var isRaised: Bool {
        state.withLock { $0.isRaised }
    }

    func raise() {
        let waiters = state.withLock { state in
            state.isRaised = true
            defer { state.waiters = [] }
            return state.waiters
        }
        waiters.forEach { $0.resume() }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            let passes = state.withLock { state in
                guard !state.isRaised else { return true }
                state.waiters.append(continuation)
                return false
            }
            if passes {
                continuation.resume()
            }
        }
    }
}
