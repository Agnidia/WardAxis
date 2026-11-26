//
//  ConfigurationCacheProtocol.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Keeps the last applied configuration across launches.
///
/// Callers order the operations themselves; an implementation need not order
/// calls that overlap.
public protocol ConfigurationCacheProtocol: Sendable {
    /// The cached configuration, or `nil` when there is none or it is unreadable.
    func load() async -> ManagedConfiguration?
    
    func save(_ configuration: ManagedConfiguration) async throws
    
    /// Removes the cache. A missing cache is success.
    func delete() async throws
}

/// A cache that keeps nothing. Used where no per-app storage location exists,
/// and by a container that must never touch the user's cache.
public struct NoConfigurationCache: ConfigurationCacheProtocol {
    public init() {}
    
    public func load() async -> ManagedConfiguration? {
        nil
    }
    
    public func save(_: ManagedConfiguration) async throws {}
    
    public func delete() async throws {}
}
