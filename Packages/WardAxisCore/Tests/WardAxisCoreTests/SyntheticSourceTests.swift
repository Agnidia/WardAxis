//
//  SyntheticSourceTests.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisCore
import WardAxisCoreSynthetic

@Suite("Synthetic sources")
struct SyntheticSourceTests {
    private static let start = Date(timeIntervalSince1970: 1_795_687_200.75)
    
    @Test
    func `The same seed gives the same events`() async throws {
        let first = try SyntheticEventSource(seed: 42, start: Self.start, totalCount: 50)
        let second = try SyntheticEventSource(seed: 42, start: Self.start, totalCount: 50)
        let other = try SyntheticEventSource(seed: 43, start: Self.start, totalCount: 50)
        
        let events = await first.nextBatch(maximumCount: 50)
        
        #expect(await second.nextBatch(maximumCount: 50) == events)
        #expect(await other.nextBatch(maximumCount: 50) != events)
    }
    
    @Test
    func `Every synthetic event is labeled synthetic and survives the codec`() async throws {
        let source = try SyntheticEventSource(seed: 7, start: Self.start, totalCount: 200)
        
        let events = await source.nextBatch(maximumCount: 200)
        
        #expect(events.count == 200)
        #expect(events.allSatisfy { $0.provenance == .synthetic })
        #expect(Set(events.map(\.identifier)).count == events.count)
        for event in events {
            #expect(try SchemaCodec.decode(SecurityEvent.self, from: SchemaCodec.encode(event)) == event)
        }
    }
    
    @Test
    func `Batches stay within the limit, a non-positive count consumes nothing, and an empty batch means exhausted`() async throws {
        let source = try SyntheticEventSource(seed: 1, start: Self.start, totalCount: SchemaLimits.maximumBatchSize + 10)
        
        #expect(await source.nextBatch(maximumCount: .max).count == SchemaLimits.maximumBatchSize)
        #expect(await source.nextBatch(maximumCount: 0).isEmpty)
        #expect(await source.nextBatch(maximumCount: -1).isEmpty)
        #expect(await source.nextBatch(maximumCount: 100).count == 10)
        #expect(await source.nextBatch(maximumCount: 100).isEmpty)
    }
    
    @Test
    func `A catalog entry that the schema refuses fails the initializer, not a later batch`() {
        #expect(throws: SchemaViolation(path: "$.body.flow.remoteHost", reason: .malformedHost)) {
            try SyntheticEventSource(seed: 1, start: Self.start, totalCount: 1, hosts: ["Not A Host"])
        }
        let forged = ApplicationIdentity(signingIdentifier: "com.apple.curl", teamIdentifier: "EXAMPLE001", isPlatformBinary: true, bundleIdentifier: nil)
        #expect(throws: SchemaViolation(path: "$.body.application.teamIdentifier", reason: .contradictory)) {
            try SyntheticEventSource(seed: 1, start: Self.start, totalCount: 1, applications: [forged])
        }
    }
    
    @Test
    func `The seeded stream depends only on SplitMix64`() async throws {
        let source = try SyntheticEventSource(seed: 42, start: Self.start, totalCount: 1)
        var generator = SeededGenerator(seed: 42)
        let isDenied = generator.nextBool()
        let identifier = generator.nextUUID()
        let application = SyntheticEventSource.defaultApplications[generator.next(below: SyntheticEventSource.defaultApplications.count)]
        let host = SyntheticEventSource.defaultHosts[generator.next(below: SyntheticEventSource.defaultHosts.count)]
        
        let event = try #require(await source.nextBatch(maximumCount: 1).first)
        
        #expect(event.identifier == identifier)
        #expect(event.application == application)
        #expect(event.flow?.remoteHost == host)
        #expect(event.flow?.action == (isDenied ? .deny : .allow))
    }
    
    @Test
    func `A reused PID does not inherit the identity of the exited process`() async {
        let browser = SyntheticEventSource.defaultApplications[0]
        let resolver = SyntheticIdentityResolver(identities: [ProcessReference(pid: 501, pidVersion: 1): browser])
        
        #expect(await resolver.identity(of: ProcessReference(pid: 501, pidVersion: 1)) == browser)
        #expect(await resolver.identity(of: ProcessReference(pid: 501, pidVersion: 2)) == nil)
    }
}
