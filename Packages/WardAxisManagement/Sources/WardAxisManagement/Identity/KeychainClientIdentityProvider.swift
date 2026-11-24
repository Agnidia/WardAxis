//
//  KeychainClientIdentityProvider.swift
//
//  Created on 24.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Security

/// Reads the client identity that enrollment stored in the Keychain.
///
/// The lookup is by label inside one access group, so the app, the agent and the
/// extensions that share the group all present the same identity, and nothing
/// outside the group can.
public struct KeychainClientIdentityProvider: ClientIdentityProvider {
    public let label: String
    public let accessGroup: String?

    public init(label: String, accessGroup: String?) {
        self.label = label
        self.accessGroup = accessGroup
    }

    public func currentIdentity() async throws(ClientIdentityError) -> ClientIdentity? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(Self.query(label: label, accessGroup: accessGroup) as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let result, CFGetTypeID(result) == SecIdentityGetTypeID() else {
                return nil
            }
            // The type ID check above makes the forced cast safe.
            return ClientIdentity(identity: result as! SecIdentity)
        case errSecItemNotFound:
            return nil
        default:
            throw .osStatus(status)
        }
    }

    static func query(label: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: label,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: false,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}

/// The provider for a device that is not enrolled: the feed never connects.
public struct NoClientIdentityProvider: ClientIdentityProvider {
    public init() {}

    public func currentIdentity() async throws(ClientIdentityError) -> ClientIdentity? {
        nil
    }
}
