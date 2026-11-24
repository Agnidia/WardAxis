//
//  KeychainItemStore.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Security

/// Where one generic-password item lives.
public struct KeychainItemLocation: Sendable, Equatable {
    public let service: String
    public let account: String

    /// The shared Keychain access group, for an item the app and its extensions
    /// all read; `nil` keeps it in the process's default group.
    public let accessGroup: String?

    public init(service: String, account: String, accessGroup: String? = nil) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }
}

/// Builds the Keychain queries. Pure functions, so the protection attributes are
/// testable without touching the Keychain.
enum KeychainQuery {
    /// Identifies the item. Also the delete query.
    static func item(_ location: KeychainItemLocation) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: location.service,
            kSecAttrAccount as String: location.account,
            // macOS: the legacy file keychain ignores kSecAttrAccessible, so the item
            // must live in the data-protection keychain. iOS ignores the key.
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: false
        ]
        if let accessGroup = location.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    static func load(_ location: KeychainItemLocation) -> [String: Any] {
        item(location).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }
    }

    /// Attributes written by an update of an existing item.
    static func updateAttributes(payload: Data) -> [String: Any] {
        [
            kSecValueData as String: payload,
            // Readable by background extensions after the first unlock; never
            // restored to another device and never synced.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }

    /// Creates the item when no update target exists.
    static func add(_ location: KeychainItemLocation, payload: Data) -> [String: Any] {
        item(location).merging(updateAttributes(payload: payload)) { _, new in new }
    }
}

/// Keeps one ``SecurePayload`` in one generic-password Keychain item.
///
/// Every call blocks on `securityd`, so call it only from ``SecureItemVault``.
public struct KeychainItemStore<Value: SecurePayload>: SecureItemStoreProtocol {
    public let location: KeychainItemLocation

    public init(location: KeychainItemLocation) {
        self.location = location
    }

    public func load() throws(SecureItemStoreError) -> Value? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(KeychainQuery.load(location) as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw .unreadable
            }
            return try SecurePayloadCoding.decode(data)
        case errSecItemNotFound:
            return nil
        default:
            throw .osStatus(status)
        }
    }

    public func save(_ value: Value) throws(SecureItemStoreError) {
        let payload = try SecurePayloadCoding.encode(value)
        let updateStatus = SecItemUpdate(
            KeychainQuery.item(location) as CFDictionary,
            KeychainQuery.updateAttributes(payload: payload) as CFDictionary
        )
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let addStatus = SecItemAdd(KeychainQuery.add(location, payload: payload) as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw .osStatus(addStatus)
            }
        default:
            throw .osStatus(updateStatus)
        }
    }

    public func delete() throws(SecureItemStoreError) {
        let status = SecItemDelete(KeychainQuery.item(location) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw .osStatus(status)
        }
    }
}
