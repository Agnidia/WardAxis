//
//  EmbeddedBundlesTests.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing

/// Checks the code the host app carries in its embed folders (ADR 0005). Every bundle
/// there runs with the app's trust: an extra one is unreviewed code, and a missing
/// one means a provider the app configures is absent from the signed package.
@Suite("Embedded bundles")
struct EmbeddedBundlesTests {
    /// What makes the OS load a bundle: an extension point, a NetworkExtension
    /// provider class, or a login item that `SMAppService` registers.
    enum Kind: Equatable {
        case extensionPoint(String)
        case provider(String)
        case loginItem
    }
    
    struct Embedded {
        let name: String
        let bundleID: String?
        let info: [String: Any]
    }
    
    /// Exact set per platform, keyed by the bundle-ID suffix under the host root
    /// (ADR 0002 D1).
    static var expected: [String: Kind] {
#if os(macOS)
        [
            ".networkfilter": .provider("com.apple.networkextension.filter-data"),
            ".transparentproxy": .provider("com.apple.networkextension.app-proxy"),
            ".dnsproxy": .provider("com.apple.networkextension.dns-proxy"),
            ".urlfilter": .extensionPoint("com.apple.networkextension.url-filter-control"),
            ".safari": .extensionPoint("com.apple.Safari.web-extension"),
            ".mail": .extensionPoint("com.apple.email.extension"),
            ".agent": .loginItem
        ]
#elseif os(iOS)
        [
            ".urlfilter": .extensionPoint("com.apple.networkextension.url-filter-control"),
            ".packettunnel": .extensionPoint("com.apple.networkextension.packet-tunnel"),
            ".safari": .extensionPoint("com.apple.Safari.web-extension")
        ]
#elseif os(tvOS)
        [".packettunnel": .extensionPoint("com.apple.networkextension.packet-tunnel")]
#endif
    }
    
    @Test
    func `The host embeds exactly the bundles of its platform`() throws {
        let root = try #require(Bundle.main.bundleIdentifier)
        
        let found = try Self.embedded().map { $0.bundleID ?? $0.name }
        
        #expect(found.count == Set(found).count)
        #expect(Set(found) == Set(Self.expected.keys.map { root + $0 }))
    }
    
    @Test
    func `Each embedded bundle is loaded only through its own entry point`() throws {
        let root = try #require(Bundle.main.bundleIdentifier)
        
        for bundle in try Self.embedded() {
            let suffix = try #require(bundle.bundleID?.deletingPrefix(root))
            let kind = try #require(Self.expected[suffix], "unexpected bundle \(bundle.name)")
            
            #expect(Self.kind(of: bundle.info) == kind, "\(bundle.name)")
        }
    }
    
    /// A system extension serves its provider over a Mach service. The App Group
    /// prefix is what limits who may look it up (ADR 0002 D3).
    @Test
    func `NetworkExtension Mach services start with the App Group`() throws {
        let root = try #require(Bundle.main.bundleIdentifier)
        
        for bundle in try Self.embedded() {
            guard let settings = bundle.info["NetworkExtension"] as? [String: Any] else { continue }
            let service = try #require(settings["NEMachServiceName"] as? String)
            let suffix = try #require(bundle.bundleID?.deletingPrefix(root))
            
            #expect(service.hasSuffix("." + root + suffix), "\(bundle.name)")
            #expect(service.split(separator: ".").count == root.split(separator: ".").count + 2)
        }
    }
    
    // MARK: - Helpers
    
    private static func kind(of info: [String: Any]) -> Kind? {
        if let point = (info["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String {
            return .extensionPoint(point)
        }
        if let point = (info["EXAppExtensionAttributes"] as? [String: Any])?["EXExtensionPointIdentifier"] as? String {
            return .extensionPoint(point)
        }
        if let classes = (info["NetworkExtension"] as? [String: Any])?["NEProviderClasses"] as? [String: String] {
            return classes.count == 1 ? classes.keys.first.map(Kind.provider) : nil
        }
        if info["LSUIElement"] as? Bool == true {
            return .loginItem
        }
        return nil
    }
    
    /// Every entry in the embed folders, bundle or not, so a stray file also fails.
    private static func embedded() throws -> [Embedded] {
#if os(macOS)
        let folders = ["Contents/PlugIns", "Contents/Extensions", "Contents/Library/SystemExtensions", "Contents/Library/LoginItems"]
#else
        let folders = ["PlugIns", "Extensions"]
#endif
        let manager = FileManager.default
        var result: [Embedded] = []
        for folder in folders {
            let url = Bundle.main.bundleURL.appending(path: folder, directoryHint: .isDirectory)
            guard manager.fileExists(atPath: url.path(percentEncoded: false)) else { continue }
            for item in try manager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                // Xcode injects the hosted test bundle into PlugIns; no archive contains it.
                if item.pathExtension == "xctest" {
                    continue
                }
                let bundle = Bundle(url: item)
                result.append(Embedded(
                    name: item.lastPathComponent,
                    bundleID: bundle?.bundleIdentifier,
                    info: bundle?.infoDictionary ?? [:]
                ))
            }
        }
        return result
    }
}

private extension String {
    func deletingPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
