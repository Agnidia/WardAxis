//
//  GoldenFrameFixtureTests.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisAPIClient
import WardAxisAPIFixtures

/// The golden frames against the generated `ConfigMessage`: each one decodes to its case
/// and version and re-encodes to the same bytes. The server and the app run the same
/// frames through their own encoder and decoder.
@Suite("Golden ConfigMessage frames")
struct GoldenFrameFixtureTests {
    private typealias Message = Components.Schemas.ConfigMessage
    
    @Test
    func `The product ships exactly the snapshot, delta and heartbeat frames`() throws {
        #expect(GoldenConfigFrame.allCases.map(\.rawValue) == ["snapshot", "delta", "heartbeat"])
        for frame in GoldenConfigFrame.allCases {
            #expect(try !frame.data().isEmpty, "\(frame)")
        }
    }
    
    @Test(arguments: GoldenConfigFrame.allCases)
    func `Each frame is in canonical form: one line, ASCII only, no slash`(frame: GoldenConfigFrame) throws {
        let bytes = try frame.data()
        #expect(bytes.allSatisfy { $0 >= 0x20 && $0 < 0x7F }, "control or non-ASCII byte")
        #expect(!bytes.contains(UInt8(ascii: "/")))
        #expect(!bytes.contains(UInt8(ascii: " ")), "whitespace outside a string")
    }
    
    @Test(arguments: GoldenConfigFrame.allCases)
    func `Each frame decodes to its own case and version`(frame: GoldenConfigFrame) throws {
        let message = try JSONDecoder().decode(Message.self, from: frame.data())
        switch (frame, message) {
        case (.snapshot, .snapshot(let snapshot)):
            #expect(snapshot._type == .snapshot)
            #expect(snapshot.version == frame.expectedVersion)
        case (.delta, .delta(let delta)):
            #expect(delta._type == .delta)
            #expect(delta.version == frame.expectedVersion)
            #expect(delta.removed == ["kind.null"])
        case (.heartbeat, .heartbeat(let heartbeat)):
            #expect(heartbeat._type == .heartbeat)
            #expect(heartbeat.version == frame.expectedVersion)
        default:
            Issue.record("\(frame) decoded as \(message)")
        }
    }
    
    @Test(arguments: GoldenConfigFrame.allCases)
    func `Each frame re-encodes byte for byte with sorted keys`(frame: GoldenConfigFrame) throws {
        let bytes = try frame.data()
        let message = try JSONDecoder().decode(Message.self, from: bytes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(try String(decoding: encoder.encode(message), as: UTF8.self) == String(decoding: bytes, as: UTF8.self))
    }
    
    @Test
    func `The snapshot carries one value of every JSON kind, each decoded as that kind`() throws {
        guard case .snapshot(let snapshot) = try JSONDecoder().decode(Message.self, from: GoldenConfigFrame.snapshot.data()) else {
            Issue.record("The snapshot frame is not a snapshot")
            return
        }
        let values = snapshot.values.additionalProperties.value
        #expect(values.keys.sorted() == ["kind.array", "kind.bool", "kind.integer", "kind.null", "kind.number", "kind.object", "kind.string"])
        #expect(values["kind.null"].map { $0 == nil } == true)
        #expect(values["kind.bool"].flatMap { $0 as? Bool } == true)
        #expect(values["kind.integer"].flatMap { $0 as? Int } == 42)
        #expect(values["kind.number"].flatMap { $0 as? Double } == 1.5)
        #expect(values["kind.string"].flatMap { $0 as? String } == "dark")
        #expect(values["kind.array"].flatMap { $0 as? [any Sendable?] }?.count == 3)
        #expect(values["kind.object"].flatMap { $0 as? [String: any Sendable?] }?.keys.sorted() == ["nested"])
    }
}
