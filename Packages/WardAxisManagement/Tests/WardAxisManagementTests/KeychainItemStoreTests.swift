//
//  KeychainItemStoreTests.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Security
import Testing
import WardAxisManagementTestSupport
@testable import WardAxisManagement

@Suite("KeychainItemStore")
struct KeychainItemStoreTests {
    private static let location = KeychainItemLocation(service: "com.example.tests.vault", account: "enrollment")
    private static let payload = Data("payload".utf8)
    
    private static let credential = TestSecret(
        secret: "secret-1",
        nonce: "nonce-1",
        expiresAt: Date(timeIntervalSince1970: 1_800_000_900),
        identifier: "device-1"
    )
    
    // MARK: - Query attributes
    
    @Test
    func `The add query is a generic password, this device only, not synchronized, data-protection keychain`() {
        let query = KeychainQuery.add(Self.location, payload: Self.payload)
        
        #expect(query[kSecClass as String] as? String == kSecClassGenericPassword as String)
        #expect(query[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        #expect(query[kSecAttrSynchronizable as String] as? Bool == false)
        #expect(query[kSecUseDataProtectionKeychain as String] as? Bool == true)
        #expect(query[kSecAttrService as String] as? String == Self.location.service)
        #expect(query[kSecAttrAccount as String] as? String == Self.location.account)
        #expect(query[kSecValueData as String] as? Data == Self.payload)
        #expect(query[kSecAttrAccessGroup as String] == nil)
    }
    
    @Test
    func `An access group scopes every query, so only the group's members can read the item`() {
        let shared = KeychainItemLocation(service: "s", account: "a", accessGroup: "TEAMID.com.agnidia.wardaxis.shared")
        
        for query in [KeychainQuery.item(shared), KeychainQuery.load(shared), KeychainQuery.add(shared, payload: Self.payload)] {
            #expect(query[kSecAttrAccessGroup as String] as? String == "TEAMID.com.agnidia.wardaxis.shared")
        }
    }
    
    @Test
    func `An update rewrites the accessibility class with the value`() {
        let attributes = KeychainQuery.updateAttributes(payload: Self.payload)
        
        #expect(attributes[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        #expect(attributes[kSecValueData as String] as? Data == Self.payload)
        #expect(attributes.count == 2)
    }
    
    @Test
    func `The item and load queries target the same non-synchronized data-protection item`() {
        let item = KeychainQuery.item(Self.location)
        let load = KeychainQuery.load(Self.location)
        
        #expect(item[kSecClass as String] as? String == kSecClassGenericPassword as String)
        #expect(item[kSecAttrSynchronizable as String] as? Bool == false)
        #expect(item[kSecUseDataProtectionKeychain as String] as? Bool == true)
        #expect(item[kSecValueData as String] == nil)
        #expect(load[kSecReturnData as String] as? Bool == true)
        #expect(load[kSecMatchLimit as String] as? String == kSecMatchLimitOne as String)
        #expect(load[kSecAttrService as String] as? String == Self.location.service)
    }
    
    @Test
    func `The unavailable store loads nothing, refuses saves and treats a delete as success`() throws {
        let store = UnavailableItemStore<TestSecret>()
        
        #expect(try store.load() == nil)
        #expect(throws: SecureItemStoreError.unavailable) { try store.save(Self.credential) }
        #expect(throws: Never.self) { try store.delete() }
    }
    
    // MARK: - Payload envelope
    
    @Test
    func `A payload round-trips through the versioned envelope`() throws {
        let data = try SecurePayloadCoding.encode(Self.credential)
        let json = try #require(String(data: data, encoding: .utf8))
        
        #expect(json.contains(#""v":1"#))
        #expect(try SecurePayloadCoding.decode(data, as: TestSecret.self) == Self.credential)
    }
    
    @Test(arguments: [
        "not json",
        #"{"v":2,"value":{"secret":"s","nonce":"n","expiresAt":0}}"#,
        #"{"value":{"secret":"s","nonce":"n","expiresAt":0}}"#,
        #"{"v":1}"#,
        #"{"v":1,"value":{"secret":"s"}}"#
    ])
    func `Bad JSON, another version, or a missing version is unreadable`(json: String) {
        #expect(throws: SecureItemStoreError.unreadable) {
            try SecurePayloadCoding.decode(Data(json.utf8), as: TestSecret.self)
        }
    }
    
    // MARK: - Vault generation fencing
    
    private enum VaultStep: Sendable, CustomStringConvertible {
        case persist(String, UInt64)
        case erase(UInt64)
        
        var description: String {
            switch self {
            case .persist(let token, let generation): "persist(\(token), \(generation))"
            case .erase(let generation): "erase(\(generation))"
            }
        }
    }
    
    private static func makeCredential(_ nonce: String) -> TestSecret {
        TestSecret(secret: "a", nonce: nonce, expiresAt: .distantFuture, identifier: nil)
    }
    
    private static func apply(_ steps: [VaultStep]) async -> TestSecret? {
        let store = InMemorySecureItemStore<TestSecret>(value: makeCredential("restored"))
        let vault = SecureItemVault<TestSecret>(store: store, marker: MockErasePendingMarker())
        for step in steps {
            switch step {
            case .persist(let token, let generation):
                _ = try? await vault.persist(makeCredential(token), generation: generation)
            case .erase(let generation):
                try? await vault.erase(generation: generation)
            }
        }
        return store.value
    }
    
    private static func permutations<T>(_ items: [T]) -> [[T]] {
        guard items.count > 1 else { return [items] }
        return items.indices.flatMap { index in
            var rest = items
            let head = rest.remove(at: index)
            return permutations(rest).map { [head] + $0 }
        }
    }
    
    @Test
    func `A stale write, an unenrollment erase and a new enrollment write end the same in every arrival order`() async {
        let steps: [VaultStep] = [.persist("stale", 1), .erase(2), .persist("new", 3)]
        
        for order in Self.permutations(steps) {
            let result = await Self.apply(order)
            #expect(result?.nonce == "new", "order \(order)")
        }
    }
    
    @Test
    func `A write and a later erase end with no item in either arrival order`() async {
        let steps: [VaultStep] = [.persist("stale", 1), .erase(2)]
        
        for order in Self.permutations(steps) {
            let result = await Self.apply(order)
            #expect(result == nil, "order \(order)")
        }
    }
    
    @Test
    func `Two writes for one enrollment keep the newer value in either arrival order`() async {
        let steps: [VaultStep] = [.persist("older", 1), .persist("newer", 2)]
        
        for order in Self.permutations(steps) {
            let result = await Self.apply(order)
            #expect(result?.nonce == "newer", "order \(order)")
        }
    }
    
    @Test
    func `A fenced write reports that nothing was stored`() async throws {
        let vault = SecureItemVault<TestSecret>(store: InMemorySecureItemStore<TestSecret>(), marker: MockErasePendingMarker())
        try await vault.erase(generation: 5)
        
        #expect(try await vault.persist(Self.makeCredential("late"), generation: 4) == false)
        #expect(try await vault.persist(Self.makeCredential("next"), generation: 6) == true)
    }
    
    @Test
    func `Restore deletes an undecodable item and keeps an item the OS refused to read`() async throws {
        let unreadable = InMemorySecureItemStore<TestSecret>(loadError: .unreadable)
        #expect(try await SecureItemVault<TestSecret>(store: unreadable, marker: MockErasePendingMarker()).restore() == nil)
        #expect(unreadable.operations == [.load, .delete])
        
        let refused = InMemorySecureItemStore<TestSecret>(value: Self.credential, loadError: .osStatus(-25_308))
        await #expect(throws: SecureItemStoreError.osStatus(-25_308)) {
            try await SecureItemVault<TestSecret>(store: refused, marker: MockErasePendingMarker()).restore()
        }
        #expect(refused.operations == [.load])
        #expect(refused.value == Self.credential)
    }
    
    // MARK: - Real Keychain
    
    /// Run-time evidence for the protection class and backend: a save, read,
    /// attribute check and delete against the real Keychain of the test host.
    @Test(
        .enabled(if: KeychainAvailability.hasDataProtectionKeychain, "needs a signed test host with a keychain access group")
    )
    func `Keychain round-trip stores a this-device-only, non-synchronized item and deletes it`() throws {
        let location = KeychainItemLocation(service: "com.agnidia.wardaxis.tests.\(UUID().uuidString)", account: "enrollment")
        let store = KeychainItemStore<TestSecret>(location: location)
        defer { try? store.delete() }
        
        try store.save(Self.credential)
        #expect(try store.load() == Self.credential)
        
        let rotated = TestSecret(
            secret: "secret-2",
            nonce: "nonce-2",
            expiresAt: Self.credential.expiresAt,
            identifier: Self.credential.identifier
        )
        try store.save(rotated)
        #expect(try store.load() == rotated)
        
        var attributesQuery = KeychainQuery.item(location)
        attributesQuery[kSecReturnAttributes as String] = true
        attributesQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributesQuery as CFDictionary, &result)
        #expect(status == errSecSuccess)
        let attributes = try #require(result as? [String: Any])
        #expect(attributes[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        #expect((attributes[kSecAttrSynchronizable as String] as? Bool ?? false) == false)
        
        try store.delete()
        #expect(try store.load() == nil)
        try store.delete()
    }
}
