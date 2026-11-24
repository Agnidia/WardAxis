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

    @Test("formatTimestamp returns empty for .none style")
    func formatTimestampReturnsEmptyForNone() {
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

    @Test("formatTimestamp returns non-empty for .time style")
    func formatTimestampReturnsNonEmptyForTime() {
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

    @Test("formatTimestamp returns non-empty for .short style")
    func formatTimestampReturnsNonEmptyForShort() {
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

    @Test("formatTimestamp returns non-empty for .full style")
    func formatTimestampReturnsNonEmptyForFull() {
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

    @Test("formatTimestamp with .time style contains colons")
    func formatTimestampTimeContainsColons() {
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

    @Test("formatTimestamp with .time style contains period (milliseconds)")
    func formatTimestampTimeContainsPeriod() {
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

    @Test("isEnabled respects test configuration")
    func isEnabledRespectsTestConfig() {
        let original = Log.configuration

        Log.configure(for: .test)
        for category in Log.Category.allCases {
            #expect(Log.isEnabled(category))
        }

        Log.configuration = original
    }

    @Test("isEnabled respects release configuration")
    func isEnabledRespectsReleaseConfig() {
        let original = Log.configuration

        Log.configure(for: .release)
        for category in Log.Category.allCases {
            #expect(!Log.isEnabled(category))
        }

        Log.configuration = original
    }

    @Test("configure with custom configuration applies it")
    func configureWithCustomConfig() {
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
        "all categories have non-empty prefix",
        arguments: Log.Category.allCases
    )
    func categoryPrefixNonEmpty(category: Log.Category) {
        #expect(!category.prefix.isEmpty)
    }

    @Test("known categories have expected emoji prefixes")
    func knownCategoryPrefixes() {
        #expect(Log.Category.application.prefix == "🗳️")
        #expect(Log.Category.ui.prefix == "🪟")
        #expect(Log.Category.cache.prefix == "💾")
        #expect(Log.Category.storage.prefix == "🗄️")
        #expect(Log.Category.management.prefix == "🔌")
        #expect(Log.Category.pki.prefix == "🔐")
    }

    // MARK: - LogMetadata

    @Test("LogMetadata auto-captures timestamp")
    func logMetadataAutoTimestamp() {
        let before = Date()
        let metadata = LogMetadata(category: .ui)
        let after = Date()

        #expect(metadata.timestamp >= before)
        #expect(metadata.timestamp <= after)
        #expect(metadata.category == .ui)
        #expect(metadata.info == nil)
    }

    @Test("LogMetadata stores info when provided")
    func logMetadataWithInfo() {
        let metadata = LogMetadata(category: .management, info: ["host": "example.com"])
        #expect(metadata.info != nil)
        #expect(metadata.info?.count == 1)
    }
}
