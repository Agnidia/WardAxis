//
//  ManualConfigChangeNotifier.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import NIOConcurrencyHelpers
import ServerCore

/// A ``ConfigChangeNotifier`` that wakes only when a test calls ``wake()``.
final class ManualConfigChangeNotifier: ConfigChangeNotifier, Sendable {
    private let continuations: NIOLockedValueBox<[AsyncStream<Void>.Continuation]> = .init([])
    
    /// Streams handed out so far; the relay takes one once it has read its start version.
    var listenerCount: Int {
        continuations.withLockedValue { $0.count }
    }
    
    func wakeUps() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        continuations.withLockedValue { $0.append(continuation) }
        return stream
    }
    
    func wake() {
        for continuation in continuations.withLockedValue({ $0 }) {
            continuation.yield()
        }
    }
}
