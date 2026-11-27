//
//  ConfigurationLimits.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisAPIContract
import WardAxisCore

/// Bounds on what the feed and the cache accept.
///
/// Encoding and decoding `ConfigurationValue` recurse once per nesting level,
/// and the cache does it on a cooperative-pool thread with a small stack, so a
/// deeply nested value from the server would crash the app. Payloads past these
/// bounds are refused before any JSON decoding starts. The cache file holds
/// what one frame carried, so it shares the stream's bounds (ADR 0019).
enum ConfigurationLimits {
    /// Deepest array or object nesting in a whole document, envelope included.
    static let maximumNestingDepth = ConfigStreamLimits.maximumNestingDepth
    
    /// Most settings one configuration may hold.
    static let maximumEntryCount = ConfigStreamLimits.maximumEntryCount
    
    /// Largest frame or cache file, in bytes.
    static let maximumMessageSize = ConfigStreamLimits.maximumFrameBytes
    
    /// `true` when `data` fits the size bound and passes the strict
    /// pre-scan of ``BoundedJSON`` at ``maximumNestingDepth``.
    static func isWithinBounds(_ data: Data) -> Bool {
        BoundedJSON.isWithinBounds(data, maximumSize: maximumMessageSize, maximumDepth: maximumNestingDepth)
    }
    
    /// `true` when `values` encodes to at most ``maximumMessageSize`` bytes, so a
    /// run of deltas cannot grow the configuration past what a snapshot may carry.
    static func fitsByteLimit(_ values: [String: ConfigurationValue]) -> Bool {
        guard let data = try? JSONEncoder().encode(values) else {
            return false
        }
        return data.count <= maximumMessageSize
    }
}
