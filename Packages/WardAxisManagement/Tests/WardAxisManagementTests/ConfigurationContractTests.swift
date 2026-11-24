//
//  ConfigurationContractTests.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisAPIFixtures
import WardAxisManagementTestSupport
@testable import WardAxisManagement

/// The app side of the contract: the golden frames that the contract package and the
/// server also test, and the operation IDs the request pipeline matches on.
@Suite("Configuration contract")
struct ConfigurationContractTests {
    /// A missing fixtures bundle traps in `Bundle.module`; run-e2e.sh checks the bundle after each build.
    @Test(arguments: GoldenConfigFrame.allCases)
    func `Every golden frame is in the fixtures bundle`(frame: GoldenConfigFrame) throws {
        let data = try frame.data()
        
        #expect(!data.isEmpty)
    }
    
    @Test
    func `The snapshot golden frame decodes with every value kind intact`() throws {
        let frame = try ConfigurationFrameDecoder().decode(GoldenConfigFrame.snapshot.data())
        
        #expect(frame == .snapshot(ManagedConfiguration(version: GoldenConfigFrame.snapshot.expectedVersion, values: [
            "kind.array": .array([.integer(1), .string("two"), .bool(true)]),
            "kind.bool": .bool(true),
            "kind.integer": .integer(42),
            "kind.null": .null,
            "kind.number": .number(1.5),
            "kind.object": .object(["nested": .string("value")]),
            "kind.string": .string("dark")
        ])))
    }
    
    @Test
    func `The delta golden frame decodes its changed and removed keys`() throws {
        let frame = try ConfigurationFrameDecoder().decode(GoldenConfigFrame.delta.data())
        
        #expect(frame == .delta(version: GoldenConfigFrame.delta.expectedVersion, changed: ["kind.integer": .integer(43)], removed: ["kind.null"]))
    }
    
    @Test
    func `The heartbeat golden frame keeps a version above 2^53 exact`() throws {
        let frame = try ConfigurationFrameDecoder().decode(GoldenConfigFrame.heartbeat.data())
        
        #expect(frame == .heartbeat(version: GoldenConfigFrame.heartbeat.expectedVersion))
    }
}
