//
//  LogLevelTests.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
@testable import WardAxisTelemetry

@Suite("Log.Level Tests")
struct LogLevelTests {
    // MARK: - Raw Values
    
    @Test
    func `single levels have correct raw values`() {
        #expect(Log.Level.error.rawValue == 1)
        #expect(Log.Level.info.rawValue == 2)
        #expect(Log.Level.debug.rawValue == 4)
        #expect(Log.Level.warning.rawValue == 8)
    }
    
    // MARK: - Presets
    
    @Test
    func `base includes only error`() {
        #expect(Log.Level.base.contains(.error))
        #expect(!Log.Level.base.contains(.info))
        #expect(!Log.Level.base.contains(.debug))
        #expect(!Log.Level.base.contains(.warning))
    }
    
    @Test
    func `all includes all four levels`() {
        #expect(Log.Level.all.contains(.error))
        #expect(Log.Level.all.contains(.info))
        #expect(Log.Level.all.contains(.debug))
        #expect(Log.Level.all.contains(.warning))
    }
    
    @Test
    func `base equals error`() {
        #expect(Log.Level.base == .error)
    }
    
    // MARK: - name(_:)
    
    @Test
    func `name returns correct string for single levels`() {
        #expect(Log.Level.name(.error) == "error")
        #expect(Log.Level.name(.info) == "info")
        #expect(Log.Level.name(.debug) == "debug")
        #expect(Log.Level.name(.warning) == "warning")
    }
    
    @Test
    func `name returns comma-separated for combined levels`() {
        let combined: Log.Level = [.error, .info]
        let name = Log.Level.name(combined)
        #expect(name.contains("error"))
        #expect(name.contains("info"))
        #expect(!name.contains("debug"))
    }
    
    @Test
    func `name returns all four for .all`() {
        let name = Log.Level.name(.all)
        #expect(name.contains("error"))
        #expect(name.contains("info"))
        #expect(name.contains("debug"))
        #expect(name.contains("warning"))
    }
    
    @Test
    func `name returns empty for empty level`() {
        let empty = Log.Level(rawValue: 0)
        #expect(Log.Level.name(empty).isEmpty)
    }
    
    // MARK: - OptionSet Behavior
    
    @Test
    func `union combines levels`() {
        let combined = Log.Level.error.union(.info)
        #expect(combined.contains(.error))
        #expect(combined.contains(.info))
        #expect(!combined.contains(.debug))
    }
    
    @Test
    func `intersection finds common levels`() {
        let a: Log.Level = [.error, .info]
        let b: Log.Level = [.info, .debug]
        let common = a.intersection(b)
        #expect(common == .info)
    }
    
    // MARK: - Codable
    
    @Test
    func `Codable round-trip preserves value`() throws {
        let original = Log.Level.all
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Log.Level.self, from: data)
        #expect(decoded == original)
    }
    
    @Test
    func `Codable round-trip for single level`() throws {
        let original = Log.Level.warning
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Log.Level.self, from: data)
        #expect(decoded == original)
    }
    
    // MARK: - Hashable
    
    @Test
    func `same levels have same hash`() {
        let a = Log.Level.all
        let b: Log.Level = [.error, .info, .debug, .warning]
        #expect(a.hashValue == b.hashValue)
    }
}
