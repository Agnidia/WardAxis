//
//  SecureStorageTestSupport.swift
//
//  Created on 24.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Security
@testable import WardAxisManagement

/// A two-field secret with an expiry and an optional label, shaped like the
/// enrollment record the vault will hold.
struct TestSecret: SecurePayload {
    static let payloadVersion = 1

    let secret: String
    let nonce: String
    let expiresAt: Date
    let identifier: String?
}

enum KeychainAvailability {
    /// Whether this process may use the data-protection keychain. An unsigned
    /// `swift test` runner lacks the entitlement (errSecMissingEntitlement), so the
    /// real-Keychain checks run only in the signed app test host.
    static let hasDataProtectionKeychain: Bool = {
        let location = KeychainItemLocation(service: "com.agnidia.wardaxis.tests.probe", account: UUID().uuidString)
        let status = SecItemAdd(KeychainQuery.add(location, payload: Data([0])) as CFDictionary, nil)
        SecItemDelete(KeychainQuery.item(location) as CFDictionary)
        return status == errSecSuccess
    }()
}
