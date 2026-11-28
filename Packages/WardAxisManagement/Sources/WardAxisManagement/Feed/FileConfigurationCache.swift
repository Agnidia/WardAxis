//
//  FileConfigurationCache.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisTelemetry

/// A ``ConfigurationCacheProtocol`` kept as one JSON file.
///
/// The file holds the schema version, the configuration version and the values;
/// the type has no field that could carry a token. It is written atomically
/// with the `completeUntilFirstUserAuthentication` class, so a prewarmed launch
/// before the user opens the app can still read it, and its directory is
/// excluded from backup because the server can always resend it.
public struct FileConfigurationCache: ConfigurationCacheProtocol {
    static let directoryName = "Configuration"
    static let fileName = "configuration.json"
    static let schemaVersion = 1
    
    let directory: URL
    let fileURL: URL
    private let logger = Log(category: .cache)
    
    /// - Parameter directory: Tests pass a throwaway directory.
    public init(directory: URL) {
        self.directory = directory
        fileURL = directory.appending(path: Self.fileName, directoryHint: .notDirectory)
    }
    
    /// The cache for the main bundle: `<Application Support>/<bundle identifier>/Configuration`,
    /// or under Caches on tvOS. A purge there only costs a fresh snapshot from the server.
    public static func live() -> any ConfigurationCacheProtocol {
        live(in: AppStorageLocation.liveBase, bundleIdentifier: Bundle.main.bundleIdentifier)
    }
    
    /// The cache under `base/<bundleIdentifier>`. A missing or unsafe identifier
    /// gets ``NoConfigurationCache`` rather than a shared fallback folder (see ``AppStorageLocation``).
    public static func live(in base: URL, bundleIdentifier: String?) -> any ConfigurationCacheProtocol {
        guard let directory = AppStorageLocation.directory(directoryName, in: base, bundleIdentifier: bundleIdentifier) else {
            return NoConfigurationCache()
        }
        return Self(directory: directory)
    }
    
    // MARK: - ConfigurationCacheProtocol
    
    @concurrent
    public func load() async -> ManagedConfiguration? {
        let data: Data
        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }
            // One byte past the limit is enough to refuse the file without reading all of it.
            data = try handle.read(upToCount: ConfigurationLimits.maximumMessageSize + 1) ?? Data()
        } catch where Self.isMissingFile(error) {
            return nil
        } catch {
            // Before first unlock the file is unreadable but intact: keep it.
            logger.warning("Reading the configuration cache failed: \(Log.safeName(of: error))", privacy: .public)
            return nil
        }
        guard ConfigurationLimits.isWithinBounds(data),
              let file = try? JSONDecoder().decode(CacheFile.self, from: data),
              file.schema == Self.schemaVersion,
              ConfigurationLimits.fitsEntryCount(file.values.count)
        else {
            logger.warning("Configuration cache is unreadable; deleting it", privacy: .public)
            try? removeFile()
            return nil
        }
        return ManagedConfiguration(version: file.version, values: file.values)
    }
    
    @concurrent
    public func save(_ configuration: ManagedConfiguration) async throws {
        let file = CacheFile(schema: Self.schemaVersion, version: configuration.version, values: configuration.values)
        let data = try JSONEncoder().encode(file)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var excludedDirectory = directory
        try excludedDirectory.setResourceValues(resourceValues)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    
    @concurrent
    public func delete() async throws {
        try removeFile()
    }
    
    private func removeFile() throws {
        try AppStorageLocation.removeItemIfPresent(at: fileURL)
    }
    
    private static func isMissingFile(_ error: any Error) -> Bool {
        let error = error as NSError
        switch (error.domain, error.code) {
        case (NSCocoaErrorDomain, NSFileNoSuchFileError), (NSCocoaErrorDomain, NSFileReadNoSuchFileError), (NSPOSIXErrorDomain, Int(ENOENT)):
            return true
        default:
            return false
        }
    }
}

/// The on-disk shape. `schema` lets a later format be told apart and dropped.
private struct CacheFile: Codable {
    let schema: Int
    let version: Int64
    let values: [String: ConfigurationValue]
}
