//
//  EntitlementsTests.swift
//
//  Created on 24.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if os(macOS)
import Foundation
import Security
import Testing

/// Checks the entitlements in the host app's code signature, which is what the
/// kernel and the Keychain enforce, not the entitlements file that should produce it.
/// macOS only: other platforms give a process no API to read its own entitlements.
@Suite("Host app entitlements")
struct EntitlementsTests {
    @Test
    func `The App Sandbox is on`() {
        #expect(Self.value(for: "com.apple.security.app-sandbox") as? Bool == true)
    }
    
    @Test
    func `The only App Group is the team-prefixed WardAxis group`() throws {
        let identity = try Self.signingIdentity()
        
        let groups = Self.value(for: "com.apple.security.application-groups") as? [String]
        
        #expect(groups == ["\(identity.teamID).\(identity.bundleID)"])
    }
    
    /// Order matters: the Keychain writes an item with no explicit access group
    /// to the first group, so the app-private group must stay first.
    @Test
    func `Keychain groups are the app-private group first, then the shared group`() throws {
        let identity = try Self.signingIdentity()
        
        let groups = Self.value(for: "keychain-access-groups") as? [String]
        
        #expect(groups == [
            identity.applicationIdentifier,
            "\(identity.appIdentifierPrefix)\(identity.bundleID).shared"
        ])
    }
    
    /// The app is the only bundle that activates the NetworkExtension system
    /// extensions (ADR 0004); `scripts/verify-entitlements.py` keeps it off every other bundle.
    @Test
    func `The app may install system extensions`() {
        #expect(Self.value(for: "com.apple.developer.system-extension.install") as? Bool == true)
    }
    
    /// An exact match: an extra provider type is over-privilege, and a
    /// `-systemextension` value is for Developer ID only, so it never matches.
    @Test
    func `NetworkExtension provider types are exactly the macOS App Store set`() {
        let values = Self.value(for: "com.apple.developer.networking.networkextension") as? [String]
        
        #expect(values.map(Set.init) == [
            "app-proxy-provider",
            "content-filter-provider",
            "dns-proxy",
            "url-filter-provider"
        ])
        #expect(values?.count == 4)
    }
    
    /// Lab or runtime-weakening entitlements. Xcode adds sandbox temporary
    /// exceptions to every test host, so `scripts/verify-entitlements.py` checks
    /// that family on the archive instead.
    static let forbiddenEntitlements: [String] = [
        "com.apple.developer.endpoint-security.client",
        "com.apple.security.cs.allow-dyld-environment-variables",
        "com.apple.security.cs.allow-jit",
        "com.apple.security.cs.allow-unsigned-executable-memory",
        "com.apple.security.cs.disable-executable-page-protection",
        "com.apple.security.cs.disable-library-validation"
    ]
    
    @Test(arguments: forbiddenEntitlements)
    func `No lab or runtime-weakening entitlement is present`(key: String) {
        #expect(Self.value(for: key) == nil)
    }
    
    // MARK: - Signature access
    
    struct SigningIdentity {
        let teamID: String
        let applicationIdentifier: String
        let appIdentifierPrefix: String
        let bundleID: String
    }
    
    enum SignatureError: Error {
        case missingEntitlement(String)
        case applicationIdentifierMismatch
    }
    
    static func value(for key: String) -> Any? {
        guard let task = SecTaskCreateFromSelf(nil) else { return nil }
        return SecTaskCopyValueForEntitlement(task, key as CFString, nil)
    }
    
    /// Derives the prefixes from the signature, never from build settings, so a
    /// mismatch between the profile and the entitlements file cannot hide here.
    static func signingIdentity() throws -> SigningIdentity {
        let teamKey = "com.apple.developer.team-identifier"
        let applicationKey = "com.apple.application-identifier"
        guard let teamID = value(for: teamKey) as? String else {
            throw SignatureError.missingEntitlement(teamKey)
        }
        guard let applicationIdentifier = value(for: applicationKey) as? String else {
            throw SignatureError.missingEntitlement(applicationKey)
        }
        let bundleID = try #require(Bundle.main.bundleIdentifier)
        guard applicationIdentifier.hasSuffix(".\(bundleID)") else {
            throw SignatureError.applicationIdentifierMismatch
        }
        let prefix = String(applicationIdentifier.dropLast(bundleID.count))
        return SigningIdentity(
            teamID: teamID,
            applicationIdentifier: applicationIdentifier,
            appIdentifierPrefix: prefix,
            bundleID: bundleID
        )
    }
}
#endif
