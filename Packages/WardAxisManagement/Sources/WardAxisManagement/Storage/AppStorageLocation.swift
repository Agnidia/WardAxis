//
//  AppStorageLocation.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Where this package keeps its local files: `<base>/<bundle identifier>/<name>`.
///
/// Without App Sandbox, `base` is shared by every app of the user. The bundle
/// folder keeps one app's files from being read, replaced or deleted by
/// another's, so an identifier that is missing or could leave `base` gets no
/// directory at all rather than a shared fallback.
enum AppStorageLocation {
    /// Application Support, or Caches on tvOS. tvOS gives an app no persistent
    /// local storage outside Caches, and the system may purge it while the app
    /// is not running; each caller states what a purge costs it.
    static var liveBase: URL {
#if os(tvOS)
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
#else
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
#endif
    }
    
    /// `<base>/<bundleIdentifier>/<name>`, or `nil` when `bundleIdentifier` is
    /// missing or not one safe path component.
    static func directory(_ name: String, in base: URL, bundleIdentifier: String?) -> URL? {
        guard let bundleIdentifier, isSinglePathComponent(bundleIdentifier) else {
            return nil
        }
        return base.appending(path: bundleIdentifier, directoryHint: .isDirectory)
            .appending(path: name, directoryHint: .isDirectory)
    }
    
    /// Deletes the item at `url`. A missing item is success, so a delete that
    /// is repeated after a crash never fails.
    ///
    /// - Returns: `false` when there was nothing to delete.
    @discardableResult
    static func removeItemIfPresent(at url: URL) throws -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch CocoaError.fileNoSuchFile {
            return false
        }
    }
    
    /// The bundle identifier character set (letters, digits, hyphen, period) has
    /// no separator, and a letter or digit rules out `.` and `..`, so the
    /// identifier cannot move a path out of `base`.
    private static func isSinglePathComponent(_ identifier: String) -> Bool {
        identifier.contains { $0.isLetter || $0.isNumber }
            && identifier.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == ".") }
    }
}
