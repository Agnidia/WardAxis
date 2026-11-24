//
//  ConfigurationCacheTests.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisManagementTestSupport
@testable import WardAxisManagement

@Suite("FileConfigurationCache")
struct ConfigurationCacheTests {
    private static let sample = ManagedConfiguration(
        version: 43,
        values: [
            "theme": .string("dark"),
            "maxItems": .integer(25),
            "ratio": .number(0.75),
            "beta": .bool(true),
            "legacy": .null,
            "tags": .array([.string("a"), .integer(1)]),
            "limits": .object(["daily": .integer(5)])
        ]
    )

    /// A cache in a fresh throwaway directory, removed by `cleanUp()`.
    private struct Sandbox {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "ConfigurationCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)

        var cache: FileConfigurationCache {
            FileConfigurationCache(directory: root.appending(path: FileConfigurationCache.directoryName, directoryHint: .isDirectory))
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: root)
        }
    }

    @Test("A saved configuration loads back unchanged")
    func roundTrip() async throws {
        let sandbox = Sandbox()
        defer { sandbox.cleanUp() }

        try await sandbox.cache.save(Self.sample)

        #expect(await sandbox.cache.load() == Self.sample)
    }

    @Test("A missing file loads as nil")
    func missingFileLoadsNil() async {
        let sandbox = Sandbox()
        defer { sandbox.cleanUp() }

        #expect(await sandbox.cache.load() == nil)
    }

    @Test("The file has the until-first-unlock protection class and its folder is excluded from backup")
    func protectionAndBackupExclusion() async throws {
        let sandbox = Sandbox()
        defer { sandbox.cleanUp() }
        let cache = sandbox.cache

        try await cache.save(Self.sample)

        let protection = try cache.fileURL.resourceValues(forKeys: [.fileProtectionKey]).fileProtection
        // Volumes without data protection (macOS, the simulator) report no class.
        if let protection {
            #expect(protection == .completeUntilFirstUserAuthentication)
        }
        let backup = try cache.directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(backup.isExcludedFromBackup == true)
    }

    @Test("The file holds only the schema, the version and the values: no token material")
    func fileHoldsNoToken() async throws {
        let sandbox = Sandbox()
        defer { sandbox.cleanUp() }
        let cache = sandbox.cache

        try await cache.save(Self.sample)

        let data = try Data(contentsOf: cache.fileURL)
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.localizedCaseInsensitiveContains("bearer"))
        #expect(!text.localizedCaseInsensitiveContains("token"))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["schema", "version", "values"])
    }

    @Test("A corrupt file is deleted and loads as nil", arguments: [
        "not json",
        #"{"schema":1,"version":"forty"}"#,
        #"{"schema":2,"version":43,"values":{}}"#
    ])
    func corruptFileIsDeleted(contents: String) async throws {
        let sandbox = Sandbox()
        defer { sandbox.cleanUp() }
        let cache = sandbox.cache
        try FileManager.default.createDirectory(at: cache.directory, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: cache.fileURL)

        #expect(await cache.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: cache.fileURL.path(percentEncoded: false)))
    }

    @Test("A cache file nested past the depth limit, or with too many entries, loads as absent and is deleted")
    func overLimitFileIsAbsent() async throws {
        let deep = String(repeating: "[", count: 31) + String(repeating: "]", count: 31)
        let pairs = (0...ConfigurationLimits.maximumEntryCount).map { #""k\#($0)":1"# }.joined(separator: ",")
        for contents in [
            #"{"schema":1,"version":1,"values":{"deep":\#(deep)}}"#,
            #"{"schema":1,"version":1,"values":{\#(pairs)}}"#
        ] {
            let sandbox = Sandbox()
            defer { sandbox.cleanUp() }
            let cache = sandbox.cache
            try FileManager.default.createDirectory(at: cache.directory, withIntermediateDirectories: true)
            try Data(contents.utf8).write(to: cache.fileURL)

            #expect(await cache.load() == nil)
            #expect(!FileManager.default.fileExists(atPath: cache.fileURL.path(percentEncoded: false)))
        }
    }

    @Test("A cache file in UTF-16 or UTF-32, with an unchecked \\u escape, a NUL byte, or over the size limit, loads as absent and is deleted")
    func hostileFileIsAbsent() async throws {
        let oversized = Data(#"{"schema":1,"version":1,"values":{"s":"\#(String(repeating: "x", count: ConfigurationLimits.maximumMessageSize))"}}"#.utf8)
        let payloads = HostilePayloads.all(envelope: #""schema":1,"version":1"#) + [("oversized", oversized)]
        for payload in payloads {
            let sandbox = Sandbox()
            defer { sandbox.cleanUp() }
            let cache = sandbox.cache
            try FileManager.default.createDirectory(at: cache.directory, withIntermediateDirectories: true)
            try payload.data.write(to: cache.fileURL)

            #expect(await cache.load() == nil, "\(payload.name)")
            #expect(!FileManager.default.fileExists(atPath: cache.fileURL.path(percentEncoded: false)), "\(payload.name)")
        }
    }

    @Test("Delete removes the file, and deleting a missing file succeeds")
    func deleteRemovesFile() async throws {
        let sandbox = Sandbox()
        defer { sandbox.cleanUp() }
        let cache = sandbox.cache
        try await cache.save(Self.sample)

        try await cache.delete()
        try await cache.delete()

        #expect(!FileManager.default.fileExists(atPath: cache.fileURL.path(percentEncoded: false)))
        #expect(await cache.load() == nil)
    }

    @Test("The live cache sits in a folder named by the bundle identifier")
    func liveLocation() throws {
        let base = URL(filePath: "/tmp/base", directoryHint: .isDirectory)

        let cache = try #require(FileConfigurationCache.live(in: base, bundleIdentifier: "com.agnidia.example") as? FileConfigurationCache)

        #expect(cache.fileURL.path(percentEncoded: false) == "/tmp/base/com.agnidia.example/Configuration/configuration.json")
    }

    @Test("A missing or unsafe bundle identifier gets a cache that keeps nothing", arguments: [nil, "", "..", "a/b", "com.app/../x"])
    func unsafeBundleIdentifier(identifier: String?) {
        let base = URL(filePath: "/tmp/base", directoryHint: .isDirectory)

        #expect(FileConfigurationCache.live(in: base, bundleIdentifier: identifier) is NoConfigurationCache)
    }
}
