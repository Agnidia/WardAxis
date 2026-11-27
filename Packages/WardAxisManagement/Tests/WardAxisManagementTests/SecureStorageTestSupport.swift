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
    
    /// A secret that differs from another only by `nonce`.
    static func credential(_ nonce: String) -> TestSecret {
        TestSecret(secret: "a", nonce: nonce, expiresAt: .distantFuture, identifier: nil)
    }
}

/// A fresh path under the temporary directory that no other test uses. The
/// directory does not exist yet; the caller removes it.
func makeTemporaryDirectory(_ prefix: String) -> URL {
    FileManager.default.temporaryDirectory.appending(path: "\(prefix)-\(UUID().uuidString)", directoryHint: .isDirectory)
}

enum KeychainAvailability {
    /// Every Keychain service these tests create starts with this, so a leftover
    /// item is easy to find and never collides with the app's own.
    static let testServicePrefix = "com.agnidia.wardaxis.tests"
    
    /// Whether this process may use the data-protection keychain. An unsigned
    /// `swift test` runner lacks the entitlement (errSecMissingEntitlement), so the
    /// real-Keychain checks run only in the signed app test host.
    static let hasDataProtectionKeychain: Bool = {
        let location = KeychainItemLocation(service: "\(testServicePrefix).probe", account: UUID().uuidString)
        let status = SecItemAdd(KeychainQuery.add(location, payload: Data([0])) as CFDictionary, nil)
        SecItemDelete(KeychainQuery.item(location) as CFDictionary)
        return status == errSecSuccess
    }()
}
