//
//  ConfigMessageCodingTests.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import WardAxisAPIClient
import Foundation
import Testing

@Suite("ConfigMessage coding")
struct ConfigMessageCodingTests {
    private typealias Message = Components.Schemas.ConfigMessage

    // Frames are written with sorted keys so that a byte comparison with the
    // re-encoded output proves the round trip, discriminator tag included.

    @Test("A snapshot frame decodes to .snapshot and re-encodes byte for byte")
    func snapshotRoundTrip() throws {
        let frame = #"{"type":"snapshot","values":{"maxItems":20,"theme":"dark"},"version":41}"#
        let message = try decode(frame)
        guard case let .snapshot(snapshot) = message else {
            Issue.record("Expected .snapshot, decoded \(message)")
            return
        }
        #expect(snapshot._type == .snapshot)
        #expect(snapshot.version == 41)
        #expect(try encode(message) == frame)
    }

    @Test("A delta frame decodes to .delta and re-encodes byte for byte")
    func deltaRoundTrip() throws {
        let frame = #"{"changed":{"maxItems":25},"removed":["theme"],"type":"delta","version":42}"#
        let message = try decode(frame)
        guard case let .delta(delta) = message else {
            Issue.record("Expected .delta, decoded \(message)")
            return
        }
        #expect(delta._type == .delta)
        #expect(delta.version == 42)
        #expect(delta.removed == ["theme"])
        #expect(try encode(message) == frame)
    }

    @Test("A heartbeat frame decodes to .heartbeat and re-encodes byte for byte")
    func heartbeatRoundTrip() throws {
        let frame = #"{"type":"heartbeat","version":42}"#
        let message = try decode(frame)
        guard case let .heartbeat(heartbeat) = message else {
            Issue.record("Expected .heartbeat, decoded \(message)")
            return
        }
        #expect(heartbeat._type == .heartbeat)
        #expect(heartbeat.version == 42)
        #expect(try encode(message) == frame)
    }

    /// A Double holds integers exactly only up to 2^53, so 2^53 + 1 is the
    /// smallest value that exposes a lossy floating-point decode path.
    @Test(
        "A version above 2^53 stays exact through decode and re-encode",
        arguments: [
            (#"{"type":"heartbeat","version":9007199254740993}"#, Int64(9_007_199_254_740_993)),
            (#"{"type":"heartbeat","version":9223372036854775807}"#, Int64.max)
        ]
    )
    func versionAboveDoublePrecision(frame: String, expected: Int64) throws {
        let message = try decode(frame)
        guard case let .heartbeat(heartbeat) = message else {
            Issue.record("Expected .heartbeat, decoded \(message)")
            return
        }
        #expect(heartbeat.version == expected)
        #expect(try encode(message) == frame)
    }

    private func decode(_ frame: String) throws -> Message {
        try JSONDecoder().decode(Message.self, from: Data(frame.utf8))
    }

    private func encode(_ message: Message) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try String(decoding: encoder.encode(message), as: UTF8.self)
    }
}
