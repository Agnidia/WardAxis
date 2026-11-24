//
//  FileManager+Copy.swift
//
//  Created on 10.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisTelemetry

public extension FileManager {
    private static let logger = Log(category: .cache)
    
    /// Copies an item, replacing any item already at the destination.
    ///
    /// The result keeps the source's permissions and metadata, also when it replaces
    /// an existing item. A symbolic link at the destination is replaced itself, not its target.
    /// An existing destination is kept when the copy fails.
    ///
    /// - Throws: The underlying `FileManager` error if the copy or the replacement fails.
    func secureCopyItem(at srcURL: URL, to dstURL: URL) throws {
        guard let existing = destinationItemType(at: dstURL) else {
            try copyItem(at: srcURL, to: dstURL)
            return
        }
        
        try withStagingURL(for: dstURL) { stagedURL in
            try copyItem(at: srcURL, to: stagedURL)
            try replaceItem(at: dstURL, ofType: existing, withStagedItemAt: stagedURL)
        }
    }
    
    /// Non-throwing variant of ``secureCopyItem(at:to:)``; logs the failure.
    ///
    /// - Returns: `true` when the copy succeeded.
    @discardableResult
    func secureSafeCopyItem(at srcURL: URL, to dstURL: URL) -> Bool {
        do {
            try secureCopyItem(at: srcURL, to: dstURL)
            return true
        } catch {
            Self.logger.error("Cannot copy item: \(error)", privacy: .private)
            return false
        }
    }
    
    /// Moves an item, replacing any item already at the destination.
    ///
    /// Works across volumes. A symbolic link at the destination is replaced itself,
    /// not its target. When the move fails, the existing destination is kept
    /// and the source stays where it was.
    ///
    /// - Throws: The underlying `FileManager` error if the move or the replacement fails.
    func secureMoveItem(at srcURL: URL, to dstURL: URL) throws {
        guard let existing = destinationItemType(at: dstURL) else {
            try moveItem(at: srcURL, to: dstURL)
            return
        }
        
        try withStagingURL(for: dstURL) { stagedURL in
            try moveItem(at: srcURL, to: stagedURL)
            do {
                try replaceItem(at: dstURL, ofType: existing, withStagedItemAt: stagedURL)
            } catch {
                // The staging folder is deleted on return, so the source must go back first.
                try? moveItem(at: stagedURL, to: srcURL)
                throw error
            }
        }
    }
    
    /// Non-throwing variant of ``secureMoveItem(at:to:)``; logs the failure.
    ///
    /// - Returns: `true` when the move succeeded.
    @discardableResult
    func secureSafeMoveItem(at srcURL: URL, to dstURL: URL) -> Bool {
        do {
            try secureMoveItem(at: srcURL, to: dstURL)
            return true
        } catch {
            Self.logger.error("Cannot move item: \(error)", privacy: .private)
            return false
        }
    }
    
    /// Creates a directory and its intermediates when it does not exist yet.
    ///
    /// An existing directory is left untouched.
    ///
    /// - Throws: An error when the directory cannot be created, including when
    ///   a file that is not a directory is already at the path.
    func secureCreateDirectory(at url: URL) throws {
        try createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    /// Non-throwing variant of ``secureCreateDirectory(at:)``; logs the failure.
    ///
    /// - Returns: `true` when the directory exists after the call.
    @discardableResult
    func secureSafeCreateDirectory(at url: URL) -> Bool {
        do {
            try secureCreateDirectory(at: url)
            return true
        } catch {
            Self.logger.error("Cannot create folder: \(error)", privacy: .private)
            return false
        }
    }
}

private extension FileManager {
    /// `attributesOfItem` does not follow a final symbolic link, so a dangling
    /// link counts as an existing item; `fileExists(atPath:)` would report it missing.
    func destinationItemType(at url: URL) -> FileAttributeType? {
        guard let attributes = try? attributesOfItem(atPath: url.path) else { return nil }
        return attributes[.type] as? FileAttributeType ?? .typeUnknown
    }
    
    /// The staging folder is on the destination volume, so the final swap never
    /// crosses volumes and the old destination is only replaced once a full item exists.
    func withStagingURL(for dstURL: URL, _ body: (URL) throws -> Void) throws {
        let staging = try url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: dstURL, create: true)
        defer { try? removeItem(at: staging) }
        try body(staging.appending(path: dstURL.lastPathComponent))
    }
    
    func replaceItem(at dstURL: URL, ofType type: FileAttributeType, withStagedItemAt stagedURL: URL) throws {
        // replaceItemAt resolves a symbolic link and fails when its target is missing;
        // rename(2) swaps the link itself.
        guard type == .typeSymbolicLink else {
            _ = try replaceItemAt(dstURL, withItemAt: stagedURL, options: .usingNewMetadataOnly)
            return
        }
        guard rename(stagedURL.path, dstURL.path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
}
