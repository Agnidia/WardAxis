//
//  MockSystemExtensionService.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if DEBUG
import Foundation

/// Replays a scripted sequence of events for each request; never calls the OS.
final class MockSystemExtensionService: SystemExtensionServiceProtocol, @unchecked Sendable {
    /// What one request yields, and how it ends.
    struct Script: Sendable {
        var events: [SystemExtensionEvent]
        /// Thrown after `events`; `nil` finishes the stream normally.
        var error: SystemExtensionError?
        /// `false` leaves the stream open until ``finishPending()``.
        var finishes = true
        
        static let approvedAndCompleted = Script(events: [.needsUserApproval, .completed])
        static let completed = Script(events: [.completed])
    }
    
    private let lock = NSLock()
    private let activation: Script
    private let deactivation: Script
    private var _activateCount = 0
    private var _deactivateCount = 0
    private var pending: [AsyncThrowingStream<SystemExtensionEvent, any Error>.Continuation] = []
    
    init(activation: Script = .approvedAndCompleted, deactivation: Script = .completed) {
        self.activation = activation
        self.deactivation = deactivation
    }
    
    var activateCount: Int {
        lock.withLock { _activateCount }
    }
    
    var deactivateCount: Int {
        lock.withLock { _deactivateCount }
    }
    
    func activate() -> AsyncThrowingStream<SystemExtensionEvent, any Error> {
        lock.withLock { _activateCount += 1 }
        return replay(activation)
    }
    
    func deactivate() -> AsyncThrowingStream<SystemExtensionEvent, any Error> {
        lock.withLock { _deactivateCount += 1 }
        return replay(deactivation)
    }
    
    /// Finishes every stream that a script with `finishes == false` left open.
    func finishPending() {
        let continuations = lock.withLock {
            defer { pending.removeAll() }
            return pending
        }
        continuations.forEach { $0.finish() }
    }
    
    private func replay(_ script: Script) -> AsyncThrowingStream<SystemExtensionEvent, any Error> {
        AsyncThrowingStream { continuation in
            script.events.forEach { continuation.yield($0) }
            if let error = script.error {
                continuation.finish(throwing: error)
            } else if script.finishes {
                continuation.finish()
            } else {
                lock.withLock { pending.append(continuation) }
            }
        }
    }
}
#endif
