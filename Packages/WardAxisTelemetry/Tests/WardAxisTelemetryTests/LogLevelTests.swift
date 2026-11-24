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

    @Test("single levels have correct raw values")
    func singleLevelRawValues() {
        #expect(Log.Level.error.rawValue == 1)
        #expect(Log.Level.info.rawValue == 2)
        #expect(Log.Level.debug.rawValue == 4)
        #expect(Log.Level.warning.rawValue == 8)
    }

    // MARK: - Presets

    @Test("base includes only error")
    func baseIncludesOnlyError() {
        #expect(Log.Level.base.contains(.error))
        #expect(!Log.Level.base.contains(.info))
        #expect(!Log.Level.base.contains(.debug))
        #expect(!Log.Level.base.contains(.warning))
    }

    @Test("all includes all four levels")
    func allIncludesAllLevels() {
        #expect(Log.Level.all.contains(.error))
        #expect(Log.Level.all.contains(.info))
        #expect(Log.Level.all.contains(.debug))
        #expect(Log.Level.all.contains(.warning))
    }

    @Test("base equals error")
    func baseEqualsError() {
        #expect(Log.Level.base == .error)
    }

    // MARK: - name(_:)

    @Test("name returns correct string for single levels")
    func nameReturnsSingleLevelString() {
        #expect(Log.Level.name(.error) == "error")
        #expect(Log.Level.name(.info) == "info")
        #expect(Log.Level.name(.debug) == "debug")
        #expect(Log.Level.name(.warning) == "warning")
    }

    @Test("name returns comma-separated for combined levels")
    func nameReturnsCombinedString() {
        let combined: Log.Level = [.error, .info]
        let name = Log.Level.name(combined)
        #expect(name.contains("error"))
        #expect(name.contains("info"))
        #expect(!name.contains("debug"))
    }

    @Test("name returns all four for .all")
    func nameReturnsAllFour() {
        let name = Log.Level.name(.all)
        #expect(name.contains("error"))
        #expect(name.contains("info"))
        #expect(name.contains("debug"))
        #expect(name.contains("warning"))
    }

    @Test("name returns empty for empty level")
    func nameReturnsEmptyForEmpty() {
        let empty = Log.Level(rawValue: 0)
        #expect(Log.Level.name(empty).isEmpty)
    }

    // MARK: - OptionSet Behavior

    @Test("union combines levels")
    func unionCombinesLevels() {
        let combined = Log.Level.error.union(.info)
        #expect(combined.contains(.error))
        #expect(combined.contains(.info))
        #expect(!combined.contains(.debug))
    }

    @Test("intersection finds common levels")
    func intersectionFindsCommon() {
        let a: Log.Level = [.error, .info]
        let b: Log.Level = [.info, .debug]
        let common = a.intersection(b)
        #expect(common == .info)
    }

    // MARK: - Codable

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() throws {
        let original = Log.Level.all
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Log.Level.self, from: data)
        #expect(decoded == original)
    }

    @Test("Codable round-trip for single level")
    func codableRoundTripSingle() throws {
        let original = Log.Level.warning
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Log.Level.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Hashable

    @Test("same levels have same hash")
    func hashableConsistency() {
        let a = Log.Level.all
        let b: Log.Level = [.error, .info, .debug, .warning]
        #expect(a.hashValue == b.hashValue)
    }
}
