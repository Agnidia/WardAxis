//
//  LogFormattingTests.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
@testable import WardAxisTelemetry

@Suite("Log Formatting Tests", .serialized)
struct LogFormattingTests {
    // MARK: - formatTimestamp
    
    @Test
    func `formatTimestamp returns empty for .none style`() {
        let config = Log.Configuration(
            categoryStates: [:],
            label: "",
            consoleEmojis: [:],
            saveToFileByDefault: false,
            fileLogLevel: .base,
            dateDisplayStyle: .none
        )
        let result = Log.formatTimestamp(Date(), configuration: config)
        #expect(result.isEmpty)
    }
    
    @Test
    func `formatTimestamp returns non-empty for .time style`() {
        let config = Log.Configuration(
            categoryStates: [:],
            label: "",
            consoleEmojis: [:],
            saveToFileByDefault: false,
            fileLogLevel: .base,
            dateDisplayStyle: .time
        )
        let result = Log.formatTimestamp(Date(), configuration: config)
        #expect(!result.isEmpty)
    }
    
    @Test
    func `formatTimestamp returns non-empty for .short style`() {
        let config = Log.Configuration(
            categoryStates: [:],
            label: "",
            consoleEmojis: [:],
            saveToFileByDefault: false,
            fileLogLevel: .base,
            dateDisplayStyle: .short
        )
        let result = Log.formatTimestamp(Date(), configuration: config)
        #expect(!result.isEmpty)
    }
    
    @Test
    func `formatTimestamp returns non-empty for .full style`() {
        let config = Log.Configuration(
            categoryStates: [:],
            label: "",
            consoleEmojis: [:],
            saveToFileByDefault: false,
            fileLogLevel: .base,
            dateDisplayStyle: .full
        )
        let result = Log.formatTimestamp(Date(), configuration: config)
        #expect(!result.isEmpty)
    }
    
    @Test
    func `formatTimestamp with .time style contains colons`() {
        let config = Log.Configuration(
            categoryStates: [:],
            label: "",
            consoleEmojis: [:],
            saveToFileByDefault: false,
            fileLogLevel: .base,
            dateDisplayStyle: .time
        )
        let result = Log.formatTimestamp(Date(), configuration: config)
        #expect(result.contains(":"))
    }
    
    @Test
    func `formatTimestamp with .time style contains period (milliseconds)`() {
        let config = Log.Configuration(
            categoryStates: [:],
            label: "",
            consoleEmojis: [:],
            saveToFileByDefault: false,
            fileLogLevel: .base,
            dateDisplayStyle: .time
        )
        let result = Log.formatTimestamp(Date(), configuration: config)
        #expect(result.contains("."))
    }
    
    // MARK: - isEnabled / configure
    
    @Test
    func `isEnabled respects test configuration`() {
        let original = Log.configuration
        
        Log.configure(for: .test)
        for category in Log.Category.allCases {
            #expect(Log.isEnabled(category))
        }
        
        Log.configuration = original
    }
    
    @Test
    func `isEnabled respects release configuration`() {
        let original = Log.configuration
        
        Log.configure(for: .release)
        for category in Log.Category.allCases {
            #expect(!Log.isEnabled(category))
        }
        
        Log.configuration = original
    }
    
    @Test
    func `configure with custom configuration applies it`() {
        let original = Log.configuration
        
        let custom = Log.Configuration(
            categoryStates: [.ui: true, .management: false],
            label: "Custom",
            consoleEmojis: [:],
            saveToFileByDefault: false,
            fileLogLevel: .all,
            dateDisplayStyle: .none
        )
        Log.configure(custom)
        
        #expect(Log.isEnabled(.ui))
        #expect(!Log.isEnabled(.management))
        #expect(Log.configuration.label == "Custom")
        
        Log.configuration = original
    }
    
    // MARK: - Category prefix
    
    @Test(
        arguments: Log.Category.allCases
    )
    func `all categories have non-empty prefix`(category: Log.Category) {
        #expect(!category.prefix.isEmpty)
    }
    
    @Test
    func `known categories have expected emoji prefixes`() {
        #expect(Log.Category.application.prefix == "🗳️")
        #expect(Log.Category.ui.prefix == "🪟")
        #expect(Log.Category.cache.prefix == "💾")
        #expect(Log.Category.storage.prefix == "🗄️")
        #expect(Log.Category.management.prefix == "🔌")
        #expect(Log.Category.pki.prefix == "🔐")
    }
    
    // MARK: - LogMetadata
    
    @Test
    func `LogMetadata auto-captures timestamp`() {
        let before = Date()
        let metadata = LogMetadata(category: .ui)
        let after = Date()
        
        #expect(metadata.timestamp >= before)
        #expect(metadata.timestamp <= after)
        #expect(metadata.category == .ui)
        #expect(metadata.info == nil)
    }
    
    @Test
    func `LogMetadata stores info when provided`() {
        let metadata = LogMetadata(category: .management, info: ["host": "example.com"])
        #expect(metadata.info != nil)
        #expect(metadata.info?.count == 1)
    }
}
