//
//  ErasePendingMarkerProtocol.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// A persisted flag that says the stored item was erased (for example at
/// unenrollment) but may still be in the store.
///
/// The flag holds no secret and no generation: it only tells the next launch
/// not to adopt whatever the store still holds. Only ``SecureItemVault`` reads
/// and writes it, off the main actor, so implementations must be thread-safe.
public protocol ErasePendingMarkerProtocol: Sendable {
    /// `true` while an erase is due and no delete or newer save has covered it.
    var isSet: Bool { get }
    
    /// Records that an erase is due.
    func set() throws(SecureItemStoreError)
    
    /// Records that no erase is due.
    func clear() throws(SecureItemStoreError)
}
