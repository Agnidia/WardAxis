//
//  InMemoryConfigurationCache.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Synchronization
import WardAxisManagement

/// ``ConfigurationCacheProtocol`` double that keeps the configuration in memory
/// and counts each operation.
public final class InMemoryConfigurationCache: ConfigurationCacheProtocol {
    /// Runs inside each `save`, before the value is stored. Tests use it to hold
    /// a save in flight.
    public typealias SaveHook = @Sendable (ManagedConfiguration) async -> Void
    
    private struct State {
        var stored: ManagedConfiguration?
        var loadCount = 0
        var saveCount = 0
        var deleteCount = 0
    }
    
    private let state: Mutex<State>
    private let saveHook: SaveHook?
    
    public init(stored: ManagedConfiguration? = nil, saveHook: SaveHook? = nil) {
        state = Mutex(State(stored: stored))
        self.saveHook = saveHook
    }
    
    public var stored: ManagedConfiguration? {
        state.withLock { $0.stored }
    }
    
    public var loadCount: Int {
        state.withLock { $0.loadCount }
    }
    
    public var saveCount: Int {
        state.withLock { $0.saveCount }
    }
    
    public var deleteCount: Int {
        state.withLock { $0.deleteCount }
    }
    
    public func load() async -> ManagedConfiguration? {
        state.withLock { state in
            state.loadCount += 1
            return state.stored
        }
    }
    
    public func save(_ configuration: ManagedConfiguration) async throws {
        await saveHook?(configuration)
        state.withLock { state in
            state.saveCount += 1
            state.stored = configuration
        }
    }
    
    public func delete() async throws {
        state.withLock { state in
            state.deleteCount += 1
            state.stored = nil
        }
    }
}
