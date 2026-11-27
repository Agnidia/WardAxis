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
    
    @Test
    func `release preset disables all categories`() {
        let config = Log.Configuration.preset(.release)
        for (_, enabled) in config.categoryStates {
            #expect(!enabled)
        }
    }
    
    @Test
    func `preset enables all categories`() {
        let config = Log.Configuration.preset(.test)
        for category in Log.Category.allCases {
            #expect(config.categoryStates[category] == true, "Expected \(category) to be enabled")
        }
    }
    
    @Test
    func `preset has label [Tests]`() {
        let config = Log.Configuration.preset(.test)
        #expect(config.label == "[Tests]")
    }
    
    @Test
    func `release preset has empty label`() {
        let config = Log.Configuration.preset(.release)
        #expect(config.label.isEmpty)
    }
    
    // MARK: - consolePrefix
    
    @Test
    func `consolePrefix combines emoji and label`() {
        let config = Log.Configuration.testing(label: "[Test]", consoleEmojis: [.error: "X"])
        #expect(config.consolePrefix(for: .error) == "X [Test]")
    }
    
    @Test
    func `consolePrefix returns only emoji when no label`() {
        let config = Log.Configuration.testing(consoleEmojis: [.info: "i"])
        #expect(config.consolePrefix(for: .info) == "i")
    }
    
    @Test
    func `consolePrefix returns only label when no emoji`() {
        let config = Log.Configuration.testing(label: "[MyApp]")
        #expect(config.consolePrefix(for: .debug) == "[MyApp]")
    }
    
    @Test
    func `consolePrefix returns empty when no emoji and no label`() {
        let config = Log.Configuration.testing()
        #expect(config.consolePrefix(for: .warning).isEmpty)
    }
    
    // MARK: - File Logging Presets
    
    @Test
    func `debug preset enables file logging with debug level`() {
        let config = Log.Configuration.preset(.debug)
        #expect(config.saveToFileByDefault)
        #expect(config.fileLogLevel == .debug)
    }
    
    @Test
    func `release preset enables file logging with error level only`() {
        let config = Log.Configuration.preset(.release)
        #expect(config.saveToFileByDefault)
        #expect(config.fileLogLevel == .error)
    }
    
    @Test
    func `preset enables file logging with warning level`() {
        let config = Log.Configuration.preset(.test)
        #expect(config.saveToFileByDefault)
        #expect(config.fileLogLevel == .warning)
    }
    
    // MARK: - Date Display Style Presets
    
    @Test
    func `debug preset uses time style`() {
        let config = Log.Configuration.preset(.debug)
        #expect(config.dateDisplayStyle == .time)
    }
    
    @Test
    func `release preset uses short style`() {
        let config = Log.Configuration.preset(.release)
        #expect(config.dateDisplayStyle == .short)
    }
    
    @Test
    func `preset uses none style`() {
        let config = Log.Configuration.preset(.test)
        #expect(config.dateDisplayStyle == .none)
    }
}

// MARK: - DateDisplayStyle Tests

@Suite("Log.Configuration.DateDisplayStyle Tests")
struct DateDisplayStyleTests {
    @Test
    func `time has HH:mm:ss.SSS format`() {
        #expect(Log.Configuration.DateDisplayStyle.time.dateFormat == "HH:mm:ss.SSS")
    }
    
    @Test
    func `full has nil dateFormat`() {
        #expect(Log.Configuration.DateDisplayStyle.full.dateFormat == nil)
    }
    
    @Test
    func `short has nil dateFormat`() {
        #expect(Log.Configuration.DateDisplayStyle.short.dateFormat == nil)
    }
    
    @Test
    func `none has nil dateFormat`() {
        #expect(Log.Configuration.DateDisplayStyle.none.dateFormat == nil)
    }
    
    @Test
    func `full dateStyle is .full`() {
        #expect(Log.Configuration.DateDisplayStyle.full.dateStyle == .full)
    }
    
    @Test
    func `short dateStyle is .short`() {
        #expect(Log.Configuration.DateDisplayStyle.short.dateStyle == .short)
    }
    
    @Test
    func `none dateStyle is .none`() {
        #expect(Log.Configuration.DateDisplayStyle.none.dateStyle == .none)
    }
}
