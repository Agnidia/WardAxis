//
//  SecureItemVault.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Serializes secure item store access off the main actor and fences writes by
/// generation.
///
/// The caller gives every write and erase a generation from one increasing
/// counter, in the order it issues them. Actor jobs from different tasks do not
/// run in that order, so a late write could otherwise bring back an item the
/// app already erased (for example after unenrollment), or replace a rotated
/// value with the one before it. The
/// vault keeps two marks instead:
/// - `floor`: the highest generation erased so far. A write at or below it is dropped.
/// - `onDisk`: the generation of the stored item. An older write is dropped, and
///   an older erase leaves the newer item in place.
///
/// The final store content therefore depends only on which generations wrote and
/// erased, never on the order in which those calls arrive.
///
/// The vault also keeps the erase-pending marker, which outlives the process. It is
/// set before an erase deletes and cleared once a delete or a newer save covers
/// the erased item. The marker is written in the same actor turn as the fence
/// check, so an erase fenced off by a newer item never sets it.
public actor SecureItemVault<Value: SecurePayload> {
    // Existentials: the store and the marker are the seams that swap the Keychain
    // and the marker file for test doubles.
    private let store: any SecureItemStoreProtocol<Value>
    private let marker: any ErasePendingMarkerProtocol
    private var floor: UInt64 = 0
    private var onDisk: UInt64 = 0

    /// - Parameter marker: Has no default, so a new production call site cannot
    ///   lose the persisted erase by omission.
    public init(store: any SecureItemStoreProtocol<Value>, marker: any ErasePendingMarkerProtocol) {
        self.store = store
        self.marker = marker
    }

    /// Finishes an erase that a previous launch could not complete.
    ///
    /// Deletes the stored item without reading it when the marker is set, then
    /// clears the marker.
    /// - Returns: `true` when an erase was pending and is now done; `false` when
    ///   none was pending and nothing ran.
    /// - Throws: The delete's error. The marker stays set for a later try.
    public func resumePendingErase() throws(SecureItemStoreError) -> Bool {
        guard marker.isSet else {
            return false
        }
        try store.delete()
        marker.clear()
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
        guard !marker.isSet else {
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

    /// Writes `value` unless a newer generation already wrote or erased.
    /// - Returns: `false` when the write was fenced off and nothing was stored.
    @discardableResult
    public func persist(_ value: Value, generation: UInt64) throws(SecureItemStoreError) -> Bool {
        guard generation > floor, generation > onDisk else {
            return false
        }
        try store.save(value)
        onDisk = generation
        // Cleared only after the save: a crash between the two drops the new
        // value at relaunch rather than reviving the erased one.
        if marker.isSet {
            marker.clear()
        }
        return true
    }

    /// Deletes the stored item and blocks every later write at or below `generation`.
    /// An item written by a newer generation stays, and the marker is not touched.
    ///
    /// The marker is set before the delete, so a quit during any try still
    /// keeps the next launch from adopting the item. A failed delete leaves it set.
    public func erase(generation: UInt64) throws(SecureItemStoreError) {
        floor = max(floor, generation)
        guard onDisk <= generation else {
            return
        }
        if !marker.isSet {
            marker.set()
        }
        try store.delete()
        marker.clear()
    }
}
