//
//  LogConfigurationTests.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
@testable import WardAxisTelemetry

@Suite("Log.Configuration Tests")
struct LogConfigurationTests {
    // MARK: - Presets

    @Test("release preset disables all categories")
    func releasePresetDisablesAll() {
        let config = Log.Configuration.preset(.release)
        for (_, enabled) in config.categoryStates {
            #expect(!enabled)
        }
    }

    @Test("test preset enables all categories")
    func presetEnablesAll() {
        let config = Log.Configuration.preset(.test)
        for category in Log.Category.allCases {
            #expect(config.categoryStates[category] == true, "Expected \(category) to be enabled")
        }
    }

    @Test("test preset has label [Tests]")
    func presetHasLabel() {
        let config = Log.Configuration.preset(.test)
        #expect(config.label == "[Tests]")
    }

    @Test("release preset has empty label")
    func releasePresetHasEmptyLabel() {
        let config = Log.Configuration.preset(.release)
        #expect(config.label.isEmpty)
    }

    // MARK: - consolePrefix

    @Test("consolePrefix combines emoji and label")
    func consolePrefixCombinesEmojiAndLabel() {
        let config = Log.Configuration(
            categoryStates: [:],
            label: "[Test]",
            consoleEmojis: [.error: "X"],
            saveToFileByDefault: false,
            fileLogLevel: .base,
            dateDisplayStyle: .none
        )
        #expect(config.consolePrefix(for: .error) == "X [Test]")
    }

    @Test("consolePrefix returns only emoji when no label")
    func consolePrefixOnlyEmoji() {
        let config = Log.Configuration(
            categoryStates: [:],
            label: "",
            consoleEmojis: [.info: "i"],
            saveToFileByDefault: false,
            fileLogLevel: .base,
            dateDisplayStyle: .none
        )
        #expect(config.consolePrefix(for: .info) == "i")
    }

    @Test("consolePrefix returns only label when no emoji")
    func consolePrefixOnlyLabel() {
        let config = Log.Configuration(
            categoryStates: [:],
            label: "[MyApp]",
            consoleEmojis: [:],
            saveToFileByDefault: false,
            fileLogLevel: .base,
            dateDisplayStyle: .none
        )
        #expect(config.consolePrefix(for: .debug) == "[MyApp]")
    }

    @Test("consolePrefix returns empty when no emoji and no label")
    func consolePrefixEmpty() {
        let config = Log.Configuration(
            categoryStates: [:],
            label: "",
            consoleEmojis: [:],
            saveToFileByDefault: false,
            fileLogLevel: .base,
            dateDisplayStyle: .none
        )
        #expect(config.consolePrefix(for: .warning).isEmpty)
    }

    // MARK: - File Logging Presets

    @Test("debug preset enables file logging with debug level")
    func debugPresetFileLogging() {
        let config = Log.Configuration.preset(.debug)
        #expect(config.saveToFileByDefault)
        #expect(config.fileLogLevel == .debug)
    }

    @Test("release preset enables file logging with error level only")
    func releasePresetFileLogging() {
        let config = Log.Configuration.preset(.release)
        #expect(config.saveToFileByDefault)
        #expect(config.fileLogLevel == .error)
    }

    @Test("test preset enables file logging with warning level")
    func presetFileLogging() {
        let config = Log.Configuration.preset(.test)
        #expect(config.saveToFileByDefault)
        #expect(config.fileLogLevel == .warning)
    }

    // MARK: - Date Display Style Presets

    @Test("debug preset uses time style")
    func debugPresetUsesTime() {
        let config = Log.Configuration.preset(.debug)
        #expect(config.dateDisplayStyle == .time)
    }

    @Test("release preset uses short style")
    func releasePresetUsesShort() {
        let config = Log.Configuration.preset(.release)
        #expect(config.dateDisplayStyle == .short)
    }

    @Test("test preset uses none style")
    func presetUsesNone() {
        let config = Log.Configuration.preset(.test)
        #expect(config.dateDisplayStyle == .none)
    }
}

// MARK: - DateDisplayStyle Tests

@Suite("Log.Configuration.DateDisplayStyle Tests")
struct DateDisplayStyleTests {
    @Test("time has HH:mm:ss.SSS format")
    func timeHasFormat() {
        #expect(Log.Configuration.DateDisplayStyle.time.dateFormat == "HH:mm:ss.SSS")
    }

    @Test("full has nil dateFormat")
    func fullHasNilFormat() {
        #expect(Log.Configuration.DateDisplayStyle.full.dateFormat == nil)
    }

    @Test("short has nil dateFormat")
    func shortHasNilFormat() {
        #expect(Log.Configuration.DateDisplayStyle.short.dateFormat == nil)
    }

    @Test("none has nil dateFormat")
    func noneHasNilFormat() {
        #expect(Log.Configuration.DateDisplayStyle.none.dateFormat == nil)
    }

    @Test("full dateStyle is .full")
    func fullDateStyle() {
        #expect(Log.Configuration.DateDisplayStyle.full.dateStyle == .full)
    }

    @Test("short dateStyle is .short")
    func shortDateStyle() {
        #expect(Log.Configuration.DateDisplayStyle.short.dateStyle == .short)
    }

    @Test("none dateStyle is .none")
    func noneDateStyle() {
        #expect(Log.Configuration.DateDisplayStyle.none.dateStyle == .none)
    }
}
