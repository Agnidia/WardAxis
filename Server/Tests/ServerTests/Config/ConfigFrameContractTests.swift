//
//  ConfigFrameContractTests.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import WardAxisAPIFixtures
import WardAxisAPIServer
import Foundation
import ServerCore
import Testing

/// The server's frames against the golden `ConfigMessage` fixtures that the contract
/// package and the app test too. A change to the generated types or to the encoder that
/// alters a byte on the wire fails here.
@Suite("Config frames against the golden fixtures")
struct ConfigFrameContractTests {
    @Test("Each golden frame decodes with the server's generated types, and the encoder writes it back byte for byte", arguments: GoldenConfigFrame.allCases)
    func encoderReproducesGoldenFrame(frame: GoldenConfigFrame) throws {
        let bytes = try frame.data()
        let message = try JSONDecoder().decode(ConfigMessage.self, from: bytes)
        let decodedKind: String
        let encoded: String
        switch message {
        case let .snapshot(snapshot):
            decodedKind = "snapshot"
            encoded = try ConfigFrameEncoder.snapshot(ConfigSnapshotRecord(version: snapshot.version, values: snapshot.values))
        case let .delta(delta):
            decodedKind = "delta"
            let deltaFrame = try ConfigFrameEncoder.delta(ConfigChange(version: delta.version, changed: delta.changed, removed: delta.removed))
            #expect(deltaFrame.version == frame.expectedVersion)
            encoded = deltaFrame.text
        case let .heartbeat(heartbeat):
            decodedKind = "heartbeat"
            encoded = try ConfigFrameEncoder.heartbeat(version: heartbeat.version)
        }
        #expect(decodedKind == frame.rawValue)
        #expect(message.version == frame.expectedVersion)
        #expect(encoded == String(decoding: bytes, as: UTF8.self))
    }

    @Test("A store at the golden snapshot, then the golden change, yields the golden snapshot and delta frames")
    func storeRecordsYieldGoldenFrames() async throws {
        guard case let .snapshot(golden) = try JSONDecoder().decode(ConfigMessage.self, from: GoldenConfigFrame.snapshot.data()) else {
            Issue.record("The snapshot fixture is not a snapshot")
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let valuesJSON = try String(decoding: encoder.encode(golden.values), as: UTF8.self)
        let store = try InMemoryConfigStore(version: GoldenConfigFrame.snapshot.expectedVersion, valuesJSON: valuesJSON)

        let snapshot = try await store.snapshot()
        #expect(try ConfigFrameEncoder.snapshot(snapshot) == String(decoding: GoldenConfigFrame.snapshot.data(), as: UTF8.self))

        let version = try store.commit(changedJSON: #"{"kind.integer":43}"#, removed: ["kind.null"])
        #expect(version == GoldenConfigFrame.delta.expectedVersion)
        let change = try #require(store.change(at: version))
        #expect(try ConfigFrameEncoder.delta(change).text == String(decoding: GoldenConfigFrame.delta.data(), as: UTF8.self))
    }
}
