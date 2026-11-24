//
//  UnavailableItemStore.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// A store that holds nothing: loads find no item, saves throw
/// ``SecureItemStoreError/unavailable``, and deletes succeed at once.
///
/// For processes that must never touch the real item, such as a fallback
/// container: a second reader of a shared secret is a second party able to use it.
public struct UnavailableItemStore<Value: SecurePayload>: SecureItemStoreProtocol {
    public init() {}

    public func load() throws(SecureItemStoreError) -> Value? {
        nil
    }

    public func save(_: Value) throws(SecureItemStoreError) {
        throw .unavailable
    }

    public func delete() throws(SecureItemStoreError) {}
}
