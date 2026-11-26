//
//  LogMetadata.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Metadata for structured logging with auto-captured timestamp.
public struct LogMetadata: Sendable {
    public typealias InfoType = [String: any Sendable & Equatable]
    
    public let category: Log.Category
    /// Auto-captured at initialization.
    public let timestamp: Date
    /// Optional key-value metadata for additional context.
    public let info: InfoType?
    
    public init(category: Log.Category, info: InfoType? = nil) {
        self.category = category
        timestamp = Date()
        self.info = info
    }
}
