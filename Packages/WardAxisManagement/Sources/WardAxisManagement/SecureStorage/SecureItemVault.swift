//
//  SecureItemVault.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Generation fences prevent late writes from reviving erased credentials.
/// An erase failure suppresses restores until deletion or a newer save succeeds.
public actor SecureItemVault<Value: SecurePayload> {
    // Existentials: the store and the marker are the seams that swap the Keychain
    // and the marker file for test doubles.
    private let store: any SecureItemStoreProtocol<Value>
    private let marker: any ErasePendingMarkerProtocol
    private var floor: UInt64 = 0
    private var onDisk: UInt64 = 0
    private var erasePending = false
    private var persistCleanupPending = false
    
    /// - Parameter marker: Has no default, so a new production call site cannot
    ///   lose the persisted erase by omission.
    public init(store: any SecureItemStoreProtocol<Value>, marker: any ErasePendingMarkerProtocol) {
        self.store = store
        self.marker = marker
    }
    
    /// Retries an erase retained in memory or on disk; failures remain pending.
    public func resumePendingErase() throws(SecureItemStoreError) -> Bool {
        guard erasePending || marker.isSet else {
            return false
        }
        erasePending = true
        persistCleanupPending = false
        try store.delete()
        try marker.clear()
        erasePending = false
        return true
    }
    
    /// Reads the stored value once at launch.
    ///
    /// An item that can never be decoded is deleted and reads as no item. While
    /// the erase-pending marker is set, the item was already erased and
    /// reads as no item without a load.
    /// - Throws: ``SecureItemStoreError/osStatus(_:)`` or ``SecureItemStoreError/unavailable``
    ///   when the OS refused the read; the item, if any, stays for a later attempt.
    public func restore() throws(SecureItemStoreError) -> Value? {
        guard !erasePending, !marker.isSet else {
            return nil
        }
        do throws(SecureItemStoreError) {
            return try store.load()
        } catch {
            guard error == .unreadable else {
                throw error
            }
            try store.delete()
            return nil
        }
    }
    
    /// Persists a new generation or completes pending cleanup for the same stored value.
    /// Returns `false` for fenced writes, different values at the same generation, or completed duplicates.
    @discardableResult
    public func persist(_ value: Value, generation: UInt64) throws(SecureItemStoreError) -> Bool {
        guard generation > floor, generation >= onDisk else {
            return false
        }
        if generation == onDisk {
            guard persistCleanupPending, try store.load() == value else {
                return false
            }
        } else {
            try store.save(value)
            onDisk = generation
        }
        // Cleared only after the save: a crash between the two drops the new
        // value at relaunch rather than reviving the erased one.
        if erasePending || marker.isSet {
            erasePending = true
            persistCleanupPending = true
            try marker.clear()
        }
        erasePending = false
        persistCleanupPending = false
        return true
    }
    
    /// Success requires deletion and marker cleanup. A failed marker write still permits deletion.
    /// If both stores fail, callers must report incomplete erasure and retry before restart.
    public func erase(generation: UInt64) throws(SecureItemStoreError) {
        floor = max(floor, generation)
        guard onDisk <= generation else {
            return
        }
        persistCleanupPending = false
        erasePending = true
        if !marker.isSet {
            do {
                try marker.set()
            } catch {
                // Deletion can still establish safety when marker storage is unavailable.
                try store.delete()
                try marker.clear()
                erasePending = false
                return
            }
        }
        try store.delete()
        try marker.clear()
        erasePending = false
    }
}
