//
//  SecureItemVaultTests.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Synchronization
import Testing
import WardAxisManagementTestSupport
@testable import WardAxisManagement

@Suite("SecureItemVault erase-pending marker")
struct SecureItemVaultTests {
    private static let deleteFailure = SecureItemStoreError.osStatus(-25_244)
    
    private static func makeCredential(_ nonce: String) -> TestSecret {
        TestSecret(secret: "a", nonce: nonce, expiresAt: .distantFuture, identifier: nil)
    }
    
    // MARK: - Erase
    
    @Test
    func `An erase sets the marker before its delete and clears it once the delete succeeds`() async throws {
        let store = InMemorySecureItemStore<TestSecret>(value: Self.makeCredential("stored"))
        let marker = MockErasePendingMarker()
        let vault = SecureItemVault<TestSecret>(store: store, marker: marker)
        
        try await vault.erase(generation: 1)
        
        #expect(marker.operations == [.set, .clear])
        #expect(!marker.isSet)
        #expect(store.value == nil)
    }
    
    @Test
    func `A failed erase leaves the marker set, and a later try does not set it again`() async throws {
        let store = InMemorySecureItemStore<TestSecret>(value: Self.makeCredential("stored"), deleteError: Self.deleteFailure)
        let marker = MockErasePendingMarker()
        let vault = SecureItemVault<TestSecret>(store: store, marker: marker)
        
        await #expect(throws: Self.deleteFailure) { try await vault.erase(generation: 1) }
        await #expect(throws: Self.deleteFailure) { try await vault.erase(generation: 1) }
        
        #expect(marker.operations == [.set])
        #expect(marker.isSet)
        #expect(store.value != nil)
    }
    
    @Test
    func `An erase fenced off by a newer stored item never touches the marker, even when deletes fail`() async throws {
        let store = InMemorySecureItemStore<TestSecret>(deleteError: Self.deleteFailure)
        let marker = MockErasePendingMarker()
        let vault = SecureItemVault<TestSecret>(store: store, marker: marker)
        try await vault.persist(Self.makeCredential("newer"), generation: 2)
        
        try await vault.erase(generation: 1)
        
        #expect(marker.operations.isEmpty)
        #expect(!marker.isSet)
        #expect(store.value?.nonce == "newer")
        #expect(!store.operations.contains(.delete))
    }
    
    // MARK: - Persist
    
    @Test
    func `A stored save clears a set marker after the save, and a failed or fenced save keeps it`() async throws {
        let store = InMemorySecureItemStore<TestSecret>(saveError: .osStatus(-34_018))
        let marker = MockErasePendingMarker(isSet: true)
        let vault = SecureItemVault<TestSecret>(store: store, marker: marker)
        
        await #expect(throws: SecureItemStoreError.osStatus(-34_018)) {
            try await vault.persist(Self.makeCredential("failed"), generation: 2)
        }
        #expect(marker.isSet)
        
        store.failSaves(with: nil)
        store.failDeletes(with: Self.deleteFailure, times: 1)
        await #expect(throws: Self.deleteFailure) { try await vault.erase(generation: 3) }
        #expect(try await vault.persist(Self.makeCredential("fenced"), generation: 3) == false)
        #expect(marker.isSet)
        #expect(marker.operations.isEmpty)
        
        #expect(try await vault.persist(Self.makeCredential("new"), generation: 4) == true)
        #expect(!marker.isSet)
        #expect(marker.operations == [.clear])
        #expect(store.value?.nonce == "new")
    }
    
    @Test
    func `A save with no erase pending writes nothing to the marker`() async throws {
        let marker = MockErasePendingMarker()
        let vault = SecureItemVault<TestSecret>(store: InMemorySecureItemStore<TestSecret>(), marker: marker)
        
        try await vault.persist(Self.makeCredential("new"), generation: 1)
        
        #expect(marker.operations.isEmpty)
    }
    
    // MARK: - Launch
    
    @Test
    func `Resuming with no marker does nothing and reports that no erase was pending`() async throws {
        let store = InMemorySecureItemStore<TestSecret>(value: Self.makeCredential("stored"))
        let marker = MockErasePendingMarker()
        let vault = SecureItemVault<TestSecret>(store: store, marker: marker)
        
        #expect(try await vault.resumePendingErase() == false)
        #expect(store.operations.isEmpty)
        #expect(marker.operations.isEmpty)
    }
    
    @Test
    func `Resuming with the marker set deletes the item without a load and clears the marker`() async throws {
        let store = InMemorySecureItemStore<TestSecret>(value: Self.makeCredential("ended"))
        let marker = MockErasePendingMarker(isSet: true)
        let vault = SecureItemVault<TestSecret>(store: store, marker: marker)
        
        #expect(try await vault.resumePendingErase() == true)
        
        #expect(store.operations == [.delete])
        #expect(store.value == nil)
        #expect(!marker.isSet)
    }
    
    @Test
    func `A failed resume rethrows and keeps the marker set`() async throws {
        let store = InMemorySecureItemStore<TestSecret>(value: Self.makeCredential("ended"), deleteError: Self.deleteFailure)
        let marker = MockErasePendingMarker(isSet: true)
        let vault = SecureItemVault<TestSecret>(store: store, marker: marker)
        
        await #expect(throws: Self.deleteFailure) { try await vault.resumePendingErase() }
        
        #expect(store.operations == [.delete])
        #expect(marker.isSet)
        #expect(marker.operations.isEmpty)
    }
    
    @Test
    func `Restore with the marker set reads as no item and never loads`() async throws {
        let store = InMemorySecureItemStore<TestSecret>(value: Self.makeCredential("ended"))
        let vault = SecureItemVault<TestSecret>(store: store, marker: MockErasePendingMarker(isSet: true))
        
        #expect(try await vault.restore() == nil)
        #expect(store.operations.isEmpty)
        #expect(store.value != nil)
    }
    
    // MARK: - File marker
    
    @Test
    func `The file marker is an empty file: set creates it, clear removes it`() throws {
        let directory = Self.makeMarkerDirectory()
        defer { Self.removeMarkerDirectory(directory) }
        let marker = FileErasePendingMarker(directory: directory)
        let file = directory.appending(path: FileErasePendingMarker.fileName)
        #expect(!marker.isSet)
        
        try marker.set()
        #expect(marker.isSet)
        #expect(try Data(contentsOf: file).isEmpty)
        
        try marker.clear()
        #expect(!marker.isSet)
        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    }
    
    @Test
    func `Setting twice and clearing twice, or clearing a marker never set, do not fail`() throws {
        let directory = Self.makeMarkerDirectory()
        defer { Self.removeMarkerDirectory(directory) }
        let marker = FileErasePendingMarker(directory: directory)
        
        try marker.removeFile()
        #expect(!marker.isSet)
        
        try marker.createFile()
        try marker.createFile()
        #expect(marker.isSet)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false)) == [
            FileErasePendingMarker.fileName
        ])
        
        try marker.removeFile()
        try marker.removeFile()
        #expect(!marker.isSet)
    }
    
    @Test
    func `Set creates a missing directory and reports a blocked directory`() throws {
        let root = Self.makeMarkerDirectory()
        defer { Self.removeMarkerDirectory(root) }
        let nested = FileErasePendingMarker(directory: root.appending(path: "a/b", directoryHint: .isDirectory))
        try nested.set()
        #expect(nested.isSet)
        
        let blocker = root.appending(path: "blocker")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data().write(to: blocker)
        let blocked = FileErasePendingMarker(directory: blocker.appending(path: "Auth", directoryHint: .isDirectory))
        #expect(throws: (any Error).self) { try blocked.createFile() }
        #expect(throws: SecureItemStoreError.markerUnavailable) { try blocked.set() }
        #expect(!blocked.isSet)
    }
    
    @Test
    func `After a failed erase, a new marker and a new vault over the same directory skip the load and delete first`() async throws {
        let directory = Self.makeMarkerDirectory()
        defer { Self.removeMarkerDirectory(directory) }
        let store = InMemorySecureItemStore<TestSecret>(value: Self.makeCredential("ended"), deleteError: Self.deleteFailure)
        let first = SecureItemVault<TestSecret>(store: store, marker: FileErasePendingMarker(directory: directory))
        await #expect(throws: Self.deleteFailure) { try await first.erase(generation: 1) }
        
        let relaunched = SecureItemVault<TestSecret>(store: store, marker: FileErasePendingMarker(directory: directory))
        #expect(try await relaunched.restore() == nil)
        #expect(store.operations == [.delete])
        
        store.failDeletes(with: nil)
        #expect(try await relaunched.resumePendingErase() == true)
        #expect(store.operations == [.delete, .delete])
        #expect(store.value == nil)
        #expect(!FileErasePendingMarker(directory: directory).isSet)
    }
    
    @Test
    func `An erase fenced off by a newer item never creates the marker file`() async throws {
        let directory = Self.makeMarkerDirectory()
        defer { Self.removeMarkerDirectory(directory) }
        let store = InMemorySecureItemStore<TestSecret>(deleteError: Self.deleteFailure)
        let vault = SecureItemVault<TestSecret>(store: store, marker: FileErasePendingMarker(directory: directory))
        try await vault.persist(Self.makeCredential("newer"), generation: 2)
        
        try await vault.erase(generation: 1)
        
        #expect(!FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)))
        #expect(store.value?.nonce == "newer")
    }
    
    @Test
    func `A stored save after a failed erase removes the marker file`() async throws {
        let directory = Self.makeMarkerDirectory()
        defer { Self.removeMarkerDirectory(directory) }
        let marker = FileErasePendingMarker(directory: directory)
        let store = InMemorySecureItemStore<TestSecret>(value: Self.makeCredential("ended"))
        store.failDeletes(with: Self.deleteFailure, times: 1)
        let vault = SecureItemVault<TestSecret>(store: store, marker: marker)
        await #expect(throws: Self.deleteFailure) { try await vault.erase(generation: 1) }
        #expect(marker.isSet)
        
        #expect(try await vault.persist(Self.makeCredential("new"), generation: 2) == true)
        
        #expect(!marker.isSet)
        #expect(store.value?.nonce == "new")
    }
    
    // MARK: - Live path
    
    @Test
    func `The live marker sits in a folder named by the bundle identifier, then Vault`() throws {
        let base = Self.makeMarkerDirectory().deletingLastPathComponent()
        defer { Self.removeMarkerDirectory(base.appending(path: "Vault")) }
        let expected = base.appending(path: "com.example.app-1/Vault", directoryHint: .isDirectory)
        #expect(FileErasePendingMarker.directory(in: base, bundleIdentifier: "com.example.app-1") == expected)
        
        let marker = try #require(
            FileErasePendingMarker.live(in: base, bundleIdentifier: "com.example.app-1") as? FileErasePendingMarker
        )
        #expect(marker.directory == expected)
        
        try marker.set()
        let file = expected.appending(path: FileErasePendingMarker.fileName)
        #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    }
    
    @Test(
        arguments: [nil, "", ".", "..", "a/b", "../app", "app\u{0}x", "ap p"] as [String?]
    )
    func `A missing or unusable bundle identifier gives a volatile marker and writes nothing`(bundleIdentifier: String?) throws {
        let base = Self.makeMarkerDirectory().deletingLastPathComponent()
        defer { Self.removeMarkerDirectory(base.appending(path: "Vault")) }
        
        let marker = FileErasePendingMarker.live(in: base, bundleIdentifier: bundleIdentifier)
        #expect(marker is VolatileErasePendingMarker)
        
        try marker.set()
        #expect(marker.isSet)
        #expect(!FileManager.default.fileExists(atPath: base.path(percentEncoded: false)))
    }
    
    @Test
    func `live() scopes the marker by the main bundle's identifier`() throws {
        let marker = FileErasePendingMarker.live()
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            #expect(marker is VolatileErasePendingMarker)
            return
        }
        let fileMarker = try #require(marker as? FileErasePendingMarker)
        #expect(fileMarker.directory.pathComponents.suffix(2) == [bundleIdentifier, FileErasePendingMarker.directoryName])
    }
    
    // MARK: - Flush
    
    @Test
    func `The first create finds each new directory on the path, and a later create finds none`() throws {
        let directory = Self.makeMarkerDirectory()
        defer { Self.removeMarkerDirectory(directory) }
        let nested = directory.appending(path: "a/b", directoryHint: .isDirectory)
        let root = directory.deletingLastPathComponent()
        #expect(FileErasePendingMarker.missingDirectories(upTo: nested).map(\.standardizedFileURL) == [
            nested, nested.deletingLastPathComponent(), directory, root
        ].map(\.standardizedFileURL))
        
        // Each parent flush throws on failure, so a clean return means every
        // directory on the new path, and the existing one above it, was flushed.
        try FileErasePendingMarker(directory: nested).createFile()
        
        #expect(FileErasePendingMarker.missingDirectories(upTo: nested).isEmpty)
        try FileErasePendingMarker.flush(root.deletingLastPathComponent(), isDirectory: true)
    }
    
    @Test
    func `A parent flush refused by a link still writes the marker, then reports the failure`() throws {
        let directory = Self.makeMarkerDirectory()
        defer { Self.removeMarkerDirectory(directory) }
        let root = directory.deletingLastPathComponent()
        let realBase = root.appending(path: "real", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: realBase, withIntermediateDirectories: true)
        let linkedBase = root.appending(path: "base", directoryHint: .notDirectory)
        try FileManager.default.createSymbolicLink(at: linkedBase, withDestinationURL: realBase)
        let marker = try #require(
            FileErasePendingMarker.live(in: linkedBase, bundleIdentifier: "com.example.app") as? FileErasePendingMarker
        )
        
        #expect(throws: POSIXError.self) { try marker.createFile() }
        
        #expect(marker.isSet)
        let written = FileErasePendingMarker.directory(in: realBase, bundleIdentifier: "com.example.app")
            .appending(path: FileErasePendingMarker.fileName)
        #expect(try Self.fileType(at: written) == .typeRegular)
    }
    
    @Test
    func `A link at the marker path is never followed: the flush refuses it and a set replaces it`() throws {
        let directory = Self.makeMarkerDirectory()
        defer { Self.removeMarkerDirectory(directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let marker = FileErasePendingMarker(directory: directory)
        let file = directory.appending(path: FileErasePendingMarker.fileName)
        let target = directory.deletingLastPathComponent().appending(path: "target")
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: target)
        
        #expect(throws: POSIXError(.ELOOP)) { try FileErasePendingMarker.flush(file, isDirectory: false) }
        let root = directory.deletingLastPathComponent()
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "linked", directoryHint: .notDirectory),
            withDestinationURL: directory
        )
        // The trailing slash of a directory URL must not let the link resolve.
        let linkedDirectory = root.appending(path: "linked", directoryHint: .isDirectory)
        #expect(linkedDirectory.path(percentEncoded: false).hasSuffix("/"))
        // With O_DIRECTORY the kernel reports the link as not a directory.
        let refusal = #expect(throws: POSIXError.self) {
            try FileErasePendingMarker.flush(linkedDirectory, isDirectory: true)
        }
        #expect(refusal?.code == .ENOTDIR || refusal?.code == .ELOOP)
        
        try marker.createFile()
        #expect(!FileManager.default.fileExists(atPath: target.path(percentEncoded: false)))
        #expect(try Self.fileType(at: file) == .typeRegular)
        
        try Data("kept".utf8).write(to: target)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: target)
        try marker.removeFile()
        #expect(try Data(contentsOf: target) == Data("kept".utf8))
    }
    
    @Test
    func `A FIFO at the marker path neither blocks the flush nor passes it, and a set replaces it`() throws {
        let directory = Self.makeMarkerDirectory()
        defer { Self.removeMarkerDirectory(directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: FileErasePendingMarker.fileName)
        try #require(mkfifo(file.path(percentEncoded: false), 0o600) == 0)
        
        let flush = try #require(
            Self.withinTimeLimit(unblocking: file) { try FileErasePendingMarker.flush(file, isDirectory: false) },
            "The flush blocked on the FIFO"
        )
        #expect(throws: POSIXError(.ESPIPE)) { try flush.get() }
        
        let marker = FileErasePendingMarker(directory: directory)
        let create = try #require(
            Self.withinTimeLimit(unblocking: file) { try marker.createFile() },
            "Creating the marker blocked on the FIFO"
        )
        try create.get()
        #expect(marker.isSet)
        #expect(try Self.fileType(at: file) == .typeRegular)
    }
    
    // MARK: - Volatile marker
    
    @Test
    func `The volatile marker round-trips in memory`() {
        let marker = VolatileErasePendingMarker()
        #expect(!marker.isSet)
        marker.set()
        #expect(marker.isSet)
        marker.clear()
        #expect(!marker.isSet)
    }
    
    /// A fresh directory path under a throwaway root, so no test reads or writes
    /// the app's own marker. The directory does not exist yet.
    private static func makeMarkerDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "CredentialVaultTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "Auth", directoryHint: .isDirectory)
    }
    
    private static func removeMarkerDirectory(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory.deletingLastPathComponent())
    }
    
    private static func fileType(at url: URL) throws -> FileAttributeType? {
        try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))[.type] as? FileAttributeType
    }
    
    /// Runs `body` on its own thread and returns `nil` after 5 seconds, so an
    /// open that blocks on `fifo` fails the test instead of hanging the suite.
    private static func withinTimeLimit(
        unblocking fifo: URL,
        _ body: @escaping @Sendable () throws -> Void
    ) -> Result<Void, any Error>? {
        let outcome = Outcome()
        let done = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            let result = Result { try body() }
            outcome.value.withLock { $0 = result }
            done.signal()
        }
        guard done.wait(timeout: .now() + 5) == .timedOut else {
            return outcome.value.withLock { $0 }
        }
        // A reader blocked in open returns once a writer opens the FIFO, so the
        // thread can end before the suite does.
        let writer = open(fifo.path(percentEncoded: false), O_WRONLY | O_NONBLOCK)
        if writer >= 0 {
            close(writer)
        }
        _ = done.wait(timeout: .now() + 5)
        return nil
    }
    
    private final class Outcome: Sendable {
        let value = Mutex<Result<Void, any Error>?>(nil)
    }
    
    @Test
    func `A failed marker and failed delete fence restores until a retry succeeds`() async throws {
        let marker = MockErasePendingMarker(setError: .markerUnavailable)
        let store = InMemorySecureItemStore<TestSecret>(value: Self.makeCredential("old"), deleteError: Self.deleteFailure)
        let vault = SecureItemVault(store: store, marker: marker)
        await #expect(throws: Self.deleteFailure) { try await vault.erase(generation: 1) }
        #expect(!marker.isSet)
        #expect(try await vault.restore() == nil)
        #expect(try await vault.persist(Self.makeCredential("late"), generation: 1) == false)
        store.failDeletes(with: nil)
        #expect(try await vault.resumePendingErase())
        #expect(store.value == nil)
    }
    
    @Test
    func `Deletion succeeds even when the marker cannot be created`() async throws {
        let marker = MockErasePendingMarker(setError: .markerUnavailable)
        let store = InMemorySecureItemStore<TestSecret>(value: Self.makeCredential("old"))
        let vault = SecureItemVault(store: store, marker: marker)
        try await vault.erase(generation: 1)
        #expect(store.value == nil)
        #expect(try await vault.restore() == nil)
    }
    
    @Test
    func `A marker cleanup failure is reported and prevents a restore`() async throws {
        let marker = MockErasePendingMarker(isSet: true, clearError: .markerUnavailable)
        let store = InMemorySecureItemStore<TestSecret>(value: Self.makeCredential("old"))
        let vault = SecureItemVault(store: store, marker: marker)
        await #expect(throws: SecureItemStoreError.markerUnavailable) { try await vault.resumePendingErase() }
        #expect(store.value == nil)
        #expect(marker.isSet)
        #expect(try await vault.restore() == nil)
    }
    
    @Test
    func `A real marker creation failure reaches the caller`() throws {
        let directory = Self.makeMarkerDirectory()
        defer { Self.removeMarkerDirectory(directory) }
        try FileManager.default.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: directory)
        let marker = FileErasePendingMarker(directory: directory)
        #expect(throws: SecureItemStoreError.markerUnavailable) { try marker.set() }
    }
    
    @Test
    func `A same-generation retry completes failed persist cleanup without another save`() async throws {
        let value = Self.makeCredential("new")
        let store = InMemorySecureItemStore<TestSecret>()
        let marker = MockErasePendingMarker(isSet: true, clearError: .markerUnavailable)
        let vault = SecureItemVault(store: store, marker: marker)
        await #expect(throws: SecureItemStoreError.markerUnavailable) { try await vault.persist(value, generation: 2) }
        #expect(try await vault.restore() == nil)
        #expect(try await vault.persist(Self.makeCredential("stale"), generation: 1) == false)
        await #expect(throws: SecureItemStoreError.markerUnavailable) { try await vault.persist(value, generation: 2) }
        marker.failClears(with: nil)
        #expect(try await vault.persist(value, generation: 2))
        #expect(try await vault.restore() == value)
        #expect(try await vault.persist(value, generation: 2) == false)
        #expect(store.operations.filter { $0 == .save }.count == 1)
        #expect(!store.operations.contains(.delete))
        #expect(marker.operations == [.clear])
    }
    
    @Test
    func `A cleanup retry cannot substitute another value at the same generation`() async throws {
        let value = Self.makeCredential("saved")
        let store = InMemorySecureItemStore<TestSecret>()
        let marker = MockErasePendingMarker(isSet: true, clearError: .markerUnavailable)
        let vault = SecureItemVault(store: store, marker: marker)
        await #expect(throws: SecureItemStoreError.markerUnavailable) { try await vault.persist(value, generation: 2) }
        marker.failClears(with: nil)
        #expect(try await vault.persist(Self.makeCredential("other"), generation: 2) == false)
        #expect(marker.isSet)
        #expect(try await vault.restore() == nil)
        #expect(try await vault.persist(value, generation: 2))
        #expect(store.value == value)
        #expect(store.operations.filter { $0 == .save }.count == 1)
    }
    
    @Test
    func `A newer persist replaces the pending cleanup generation`() async throws {
        let first = Self.makeCredential("first")
        let latest = Self.makeCredential("latest")
        let store = InMemorySecureItemStore<TestSecret>()
        let marker = MockErasePendingMarker(isSet: true, clearError: .markerUnavailable)
        let vault = SecureItemVault(store: store, marker: marker)
        await #expect(throws: SecureItemStoreError.markerUnavailable) { try await vault.persist(first, generation: 2) }
        await #expect(throws: SecureItemStoreError.markerUnavailable) { try await vault.persist(latest, generation: 3) }
        marker.failClears(with: nil)
        #expect(try await vault.persist(first, generation: 2) == false)
        #expect(try await vault.persist(latest, generation: 3))
        #expect(try await vault.restore() == latest)
        #expect(store.operations.filter { $0 == .save }.count == 2)
    }
    
    @Test(arguments: [false, true])
    func `An erase attempt cancels pending persist cleanup even if deletion fails`(resuming: Bool) async throws {
        let value = Self.makeCredential("saved")
        let store = InMemorySecureItemStore<TestSecret>(deleteError: Self.deleteFailure)
        let marker = MockErasePendingMarker(isSet: true, clearError: .markerUnavailable)
        let vault = SecureItemVault(store: store, marker: marker)
        await #expect(throws: SecureItemStoreError.markerUnavailable) { try await vault.persist(value, generation: 2) }
        if resuming {
            await #expect(throws: Self.deleteFailure) { try await vault.resumePendingErase() }
        } else {
            await #expect(throws: Self.deleteFailure) { try await vault.erase(generation: 2) }
        }
        marker.failClears(with: nil)
        #expect(try await vault.persist(value, generation: 2) == false)
        #expect(try await vault.restore() == nil)
        store.failDeletes(with: nil)
        #expect(try await vault.resumePendingErase())
        #expect(store.value == nil)
    }
}
