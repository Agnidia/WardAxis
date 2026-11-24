//
//  LogEntryParserTests.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisTelemetry
@testable import WardAxis

@Suite("LogEntryParser")
struct LogEntryParserTests {
    let parser = LogEntryParser()

    // MARK: - Well-formed line

    @Test("well-formed line with timestamp, category, level, message produces .parsed with all fields")
    func wellFormedLineWithTimestamp() {
        let line = "[12:34:56.789] [application] [info] App started successfully"
        let entry = parser.parse(line)

        #expect(entry.rawLine == line)

        guard case let .parsed(parsed) = entry.kind else {
            Issue.record("Expected .parsed but got .raw for line: \(line)")
            return
        }

        #expect(parsed.level == .info)
        #expect(parsed.category == .application)
        #expect(parsed.message == "App started successfully")
        #expect(parsed.info == nil)
    }

    @Test("well-formed line without timestamp segment produces .parsed with nil timestamp")
    func wellFormedLineWithoutTimestamp() {
        let line = "[ui] [debug] Tab switched"
        let entry = parser.parse(line)

        #expect(entry.rawLine == line)

        guard case let .parsed(parsed) = entry.kind else {
            Issue.record("Expected .parsed but got .raw for line: \(line)")
            return
        }

        #expect(parsed.timestamp == nil)
        #expect(parsed.level == .debug)
        #expect(parsed.category == .ui)
        #expect(parsed.message == "Tab switched")
    }

    @Test("line with unknown category token produces .raw preserving original text")
    func unknownCategoryProducesRaw() {
        let line = "[unknowncategory] [error] Something failed"
        let entry = parser.parse(line)

        #expect(entry.rawLine == line)

        guard case let .raw(rawText) = entry.kind else {
            Issue.record("Expected .raw but got .parsed for line: \(line)")
            return
        }

        #expect(rawText == line)
    }

    @Test("line with unknown level token produces .raw preserving original text")
    func unknownLevelProducesRaw() {
        let line = "[application] [verbose] Some verbose message"
        let entry = parser.parse(line)

        #expect(entry.rawLine == line)

        guard case let .raw(rawText) = entry.kind else {
            Issue.record("Expected .raw but got .parsed for line: \(line)")
            return
        }

        #expect(rawText == line)
    }

    @Test("completely malformed line produces .raw with original text preserved verbatim")
    func completelyMalformedLineProducesRaw() {
        let line = "this is not a valid log line at all!!"
        let entry = parser.parse(line)

        #expect(entry.rawLine == line)

        guard case let .raw(rawText) = entry.kind else {
            Issue.record("Expected .raw but got .parsed for malformed line")
            return
        }

        #expect(rawText == line)
    }

    @Test("line with info segment produces .parsed with non-nil info field")
    func lineWithInfoSegmentParsesInfoField() {
        let line = "[management] [warning] Request failed | reason=timeout, retries=3"
        let entry = parser.parse(line)

        #expect(entry.rawLine == line)

        guard case let .parsed(parsed) = entry.kind else {
            Issue.record("Expected .parsed but got .raw for line: \(line)")
            return
        }

        #expect(parsed.level == .warning)
        #expect(parsed.category == .management)
        #expect(parsed.message == "Request failed")
        #expect(parsed.info == "reason=timeout, retries=3")
    }

    // MARK: - Multi-line input

    @Test("parseAll on multi-line input returns entries in file order")
    func parseAllPreservesOrder() {
        let source = """
        [application] [info] First message
        [ui] [debug] Second message
        [management] [error] Third message
        """
        let entries = parser.parseAll(source)

        #expect(entries.count == 3)

        if case let .parsed(first) = entries[0].kind {
            #expect(first.message == "First message")
            #expect(first.level == .info)
        } else {
            Issue.record("Entry 0 expected .parsed")
        }

        if case let .parsed(second) = entries[1].kind {
            #expect(second.message == "Second message")
            #expect(second.level == .debug)
        } else {
            Issue.record("Entry 1 expected .parsed")
        }

        if case let .parsed(third) = entries[2].kind {
            #expect(third.message == "Third message")
            #expect(third.level == .error)
        } else {
            Issue.record("Entry 2 expected .parsed")
        }
    }

    @Test("parseAll merges non-header lines as continuations of the prior entry")
    func parseAllMergesContinuations() {
        let source = """
        [application] [info] Valid line
        this is a continuation
        [ui] [error] UI failure
        """
        let entries = parser.parseAll(source)

        #expect(entries.count == 2)

        if case let .parsed(first) = entries[0].kind {
            #expect(first.category == .application)
            #expect(first.message.contains("Valid line"))
            #expect(first.message.contains("this is a continuation"))
        } else {
            Issue.record("Entry 0 expected .parsed")
        }

        if case let .parsed(second) = entries[1].kind {
            #expect(second.category == .ui)
            #expect(second.message == "UI failure")
        } else {
            Issue.record("Entry 1 expected .parsed")
        }
    }

    @Test("parseAll on empty string returns empty array")
    func parseAllEmptyStringReturnsEmpty() {
        let entries = parser.parseAll("")
        #expect(entries.isEmpty)
    }

    @Test("parse empty string returns .raw")
    func parseEmptyStringReturnsRaw() {
        let entry = parser.parse("")
        guard case .raw = entry.kind else {
            Issue.record("Expected .raw for empty string input")
            return
        }
        #expect(entry.rawLine == "")
    }

    @Test("all four level tokens are recognized by the parser")
    func allFourLevelsRecognized() {
        let cases: [(String, Log.Level)] = [
            ("[application] [error] msg", .error),
            ("[application] [warning] msg", .warning),
            ("[application] [info] msg", .info),
            ("[application] [debug] msg", .debug)
        ]

        for (line, expectedLevel) in cases {
            let entry = parser.parse(line)
            guard case let .parsed(parsed) = entry.kind else {
                Issue.record("Expected .parsed for line: \(line)")
                continue
            }
            #expect(parsed.level == expectedLevel, "Level mismatch for: \(line)")
        }
    }

    // MARK: - Multi-line continuation merging

    @Test("multi-line message (e.g. JSON dump) is merged into a single .parsed entry")
    func multiLineMessageMergedIntoSingleEntry() {
        let source = """
        [application] [info] Metrics: {
          "PORE" : 72,
          "FIRMNESS" : 76
        }
        [application] [debug] Next entry
        """

        let entries = parser.parseAll(source)

        #expect(entries.count == 2)

        guard case let .parsed(first) = entries[0].kind else {
            Issue.record("Expected first entry to be .parsed")
            return
        }
        #expect(first.level == .info)
        #expect(first.message.contains("Metrics: {"))
        #expect(first.message.contains("\"PORE\" : 72"))
        #expect(first.message.contains("\"FIRMNESS\" : 76"))
        #expect(first.message.contains("}"))

        guard case let .parsed(second) = entries[1].kind else {
            Issue.record("Expected second entry to be .parsed")
            return
        }
        #expect(second.message == "Next entry")
    }

    @Test("orphan continuation lines at file start are preserved as .raw")
    func orphanContinuationAtFileStart() {
        let source = """
        }
        [application] [info] Recovered entry
        """

        let entries = parser.parseAll(source)
        #expect(entries.count == 2)

        guard case let .raw(rawText) = entries[0].kind else {
            Issue.record("Expected first entry to be .raw")
            return
        }
        #expect(rawText == "}")
    }

    // MARK: - Date Range

    @Test("LogDateRange.contains returns true for nil timestamp")
    func dateRangeContainsNilTimestamp() {
        #expect(LogDateRange.tenMinutes.contains(nil))
        #expect(LogDateRange.all.contains(nil))
    }

    @Test("LogDateRange.all has nil lookback and contains anything")
    func dateRangeAllAlwaysContains() {
        let pastDate = Date(timeIntervalSinceNow: -1_000_000)
        #expect(LogDateRange.all.lookback == nil)
        #expect(LogDateRange.all.contains(pastDate))
    }

    @Test("LogDateRange.tenMinutes filters out timestamps older than 10 minutes")
    func dateRangeTenMinutesFilters() {
        let now = Date()
        let recent = now.addingTimeInterval(-300) // 5 minutes ago
        let old = now.addingTimeInterval(-900) // 15 minutes ago

        #expect(LogDateRange.tenMinutes.contains(recent, now: now))
        #expect(!LogDateRange.tenMinutes.contains(old, now: now))
    }
}
