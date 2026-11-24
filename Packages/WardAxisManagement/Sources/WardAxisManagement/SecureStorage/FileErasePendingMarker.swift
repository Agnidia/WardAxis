//
//  FileErasePendingMarker.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisTelemetry

/// An ``ErasePendingMarkerProtocol`` kept as one empty file: the flag is set
/// while the file exists.
///
/// Every `isSet` read is a fresh `stat`, with no cache. A file name is not
/// under the data-protection content key, so a launch before first unlock or a
/// prewarmed launch reads the true state.
public struct FileErasePendingMarker: ErasePendingMarkerProtocol {
    static let fileName = "erase-pending"
    static let directoryName = "Vault"
    
    /// The directory that holds the marker file. `set()` creates it when needed.
    let directory: URL
    private let fileURL: URL
    private let logger = Log(category: .storage)
    
    /// - Parameter directory: Tests pass a throwaway directory, so they never
    ///   touch the app's own marker.
    public init(directory: URL) {
        self.directory = directory
        fileURL = directory.appending(path: Self.fileName, directoryHint: .notDirectory)
    }
    
    /// The marker for the main bundle: `<Application Support>/<bundle identifier>/Vault`,
    /// or under Caches on tvOS.
    public static func live() -> any ErasePendingMarkerProtocol {
#if os(tvOS)
        // tvOS gives an app no persistent local storage outside Caches, and the
        // system may purge Caches while the app is not running. A purge only
        // brings back the pre-marker behaviour for that one erased item; a
        // volatile marker would lose the flag on every relaunch.
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
#else
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
#endif
        return live(in: base, bundleIdentifier: Bundle.main.bundleIdentifier)
    }
    
    /// The marker under `base`, in a folder named by `bundleIdentifier`.
    ///
    /// Without App Sandbox, `base` is shared by every app of the user. The bundle
    /// folder stops another app's marker from erasing this app's item, and
    /// stops this app's resume from clearing the other app's marker.
    ///
    /// - Returns: A ``VolatileErasePendingMarker`` when `bundleIdentifier` is
    ///   missing or cannot be one path component. A fixed fallback folder would
    ///   bring the shared path back. `KeychainTokenStore.live(bundle:)` reads the
    ///   same identifier and falls back to ``UnavailableTokenStore``, so no item
    ///   outlives the process and a persisted marker would guard nothing.
    public static func live(in base: URL, bundleIdentifier: String?) -> any ErasePendingMarkerProtocol {
        guard let bundleIdentifier, isSinglePathComponent(bundleIdentifier) else {
            return VolatileErasePendingMarker()
        }
        return Self(directory: directory(in: base, bundleIdentifier: bundleIdentifier))
    }
    
    /// `<base>/<bundleIdentifier>/Vault`.
    static func directory(in base: URL, bundleIdentifier: String) -> URL {
        base.appending(path: bundleIdentifier, directoryHint: .isDirectory)
            .appending(path: directoryName, directoryHint: .isDirectory)
    }
    
    /// The bundle identifier character set (letters, digits, hyphen, period) has
    /// no separator, and a letter or digit rules out `.` and `..`, so the
    /// identifier cannot move the marker out of `base`.
    private static func isSinglePathComponent(_ identifier: String) -> Bool {
        identifier.contains { $0.isLetter || $0.isNumber }
            && identifier.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == ".") }
    }
    
    public var isSet: Bool {
        FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false))
    }
    
    public func set() {
        do {
            try createFile()
        } catch {
            logger.error("Writing the erase-pending marker failed: \(Self.logName(of: error))", privacy: .public)
        }
    }
    
    public func clear() {
        do {
            try removeFile()
        } catch {
            logger.error("Removing the erase-pending marker failed: \(Self.logName(of: error))", privacy: .public)
        }
    }
    
    /// The throwing form of `set()`.
    ///
    /// The caller deletes the Keychain item next, so the file and every
    /// directory entry on its path that this call creates are flushed to storage
    /// first: a power loss during the delete still leaves the marker for the next
    /// launch.
    ///
    /// The class is `completeUntilFirstUserAuthentication`, the same as the
    /// Keychain item's `AfterFirstUnlock`. The file is empty, so the class guards
    /// no content; it is set explicitly so that a stricter default-data-protection
    /// entitlement cannot make the file unwritable while the item stays readable.
    ///
    /// The file stays in backups on purpose. A `ThisDeviceOnly` item can come back
    /// with a restore to the same device, and the marker must come back with it.
    /// On another device the item is absent, the resume delete finds nothing, and
    /// the marker clears.
    func createFile() throws {
        let created = Self.missingDirectories(upTo: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // A new directory's own entry lives in its parent. These run before the
        // write, because a later call finds the directories and skips them. A
        // failure still lets the write run: an unflushed marker guards every
        // launch short of a power loss, and no marker guards none.
        var parentFlushError: any Error?
        for newDirectory in created {
            do {
                try Self.flush(newDirectory.deletingLastPathComponent(), isDirectory: true)
            } catch {
                parentFlushError = parentFlushError ?? error
            }
        }
        try Data().write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try Self.flush(fileURL, isDirectory: false)
        try Self.flush(directory, isDirectory: true)
        if let parentFlushError {
            throw parentFlushError
        }
    }
    
    /// The throwing form of `clear()`. A missing file is success.
    func removeFile() throws {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch CocoaError.fileNoSuchFile {
            return
        }
        try Self.flush(directory, isDirectory: true)
    }
    
    /// `directory` and each ancestor that does not exist yet, deepest first.
    static func missingDirectories(upTo directory: URL) -> [URL] {
        var missing: [URL] = []
        var cursor = directory
        // The root always exists, so the walk ends there at the latest.
        while !FileManager.default.fileExists(atPath: cursor.path(percentEncoded: false)) {
            missing.append(cursor)
            cursor = cursor.deletingLastPathComponent()
        }
        return missing
    }
    
    /// Flushes `url` to storage through a descriptor that refuses a link or a
    /// FIFO in its place, so a planted object can neither redirect nor stall the
    /// sync.
    static func flush(_ url: URL, isDirectory: Bool) throws {
        var path = url.path(percentEncoded: false)
        // O_NOFOLLOW checks only the last component, and a trailing slash would
        // resolve a link there anyway.
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        // O_NONBLOCK: a FIFO otherwise blocks the open until a writer appears.
        let flags = O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW | (isDirectory ? O_DIRECTORY : 0)
        let descriptor = open(path, flags)
        guard descriptor >= 0 else {
            throw posixError()
        }
        defer { close(descriptor) }
        // A FIFO accepts the sync calls below and reports success, so the file is
        // refused here when it cannot seek (ESPIPE). Reading its type from the
        // descriptor's attributes would add a required-reason API.
        if !isDirectory, lseek(descriptor, 0, SEEK_CUR) == -1 {
            throw posixError()
        }
        // fsync alone leaves the data in the drive's write cache. Some file
        // systems refuse F_FULLFSYNC, so fsync is the fallback.
        if fcntl(descriptor, F_FULLFSYNC) == -1, fsync(descriptor) == -1 {
            throw posixError()
        }
    }
    
    private static func posixError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    
    /// The error domain and code only: a Cocoa file error's description holds
    /// the container path, which names the user on macOS.
    private static func logName(of error: any Error) -> String {
        let error = error as NSError
        return "\(error.domain) \(error.code)"
    }
}
