//
//  ConfigurationServiceTests.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisManagementTestSupport
@testable import WardAxisManagement

@Suite("ConfigurationService", .timeLimit(.minutes(1)))
@MainActor
struct ConfigurationServiceTests {
    // MARK: - Enrollment lifecycle
    
    @Test
    func `Enrolling opens exactly one connection with the identity, no credential header and no query`() async throws {
        let harness = ConfigurationHarness()
        harness.service.enrollmentDidChange(to: .unenrolled)
        
        let connection = await harness.start()
        connection.send(frame: ConfigFrames.snapshot(41))
        await waitUntil { harness.service.configuration == ConfigFrames.defaultConfiguration }
        await settle()
        
        let url = try #require(connection.request.url)
        #expect(url.absoluteString == "wss://api.example.com/config/stream")
        #expect(url.query == nil)
        #expect(connection.request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(harness.transport.openCount == 1)
        #expect(harness.identityProvider.readCount == 1)
    }
    
    @Test
    func `Unenrollment closes the socket, schedules nothing, deletes the cache and clears the state`() async {
        let harness = ConfigurationHarness()
        let connection = await harness.start()
        connection.send(frame: ConfigFrames.snapshot(41))
        await waitUntil { harness.service.configuration != nil }
        await harness.service.cacheWorkFinished()
        #expect(harness.cache.stored == ConfigFrames.defaultConfiguration)
        
        harness.service.enrollmentDidChange(to: .unenrolled)
        await connection.terminated()
        await harness.service.connectionLoopFinished()
        await harness.service.cacheWorkFinished()
        
        #expect(harness.service.configuration == nil)
        #expect(harness.cache.stored == nil)
        #expect(harness.cache.deleteCount == 1)
        #expect(harness.clock.pendingSleepCount == 0)
        #expect(harness.clock.requestedSleeps.isEmpty)
        #expect(harness.transport.openCount == 1)
    }
    
    @Test
    func `A save still in flight at unenrollment cannot bring the cache back`() async {
        let gate = Gate()
        let started = Gate()
        let cache = InMemoryConfigurationCache(saveHook: { _ in
            started.open()
            await gate.wait()
        })
        let harness = ConfigurationHarness(cache: cache)
        let connection = await harness.start()
        connection.send(frame: ConfigFrames.snapshot(41))
        await started.wait()
        
        harness.service.enrollmentDidChange(to: .unenrolled)
        gate.open()
        await harness.service.cacheWorkFinished()
        
        #expect(cache.saveCount == 1)
        #expect(cache.deleteCount == 1)
        #expect(cache.stored == nil)
    }
    
    @Test
    func `A launch that settles unenrolled deletes a leftover cache and opens nothing`() async {
        let cache = InMemoryConfigurationCache(stored: ConfigFrames.defaultConfiguration)
        let harness = ConfigurationHarness(cache: cache)
        
        harness.service.sceneDidChange(isForeground: true)
        harness.service.enrollmentDidChange(to: .unenrolled)
        await harness.service.cacheWorkFinished()
        
        #expect(cache.stored == nil)
        #expect(harness.service.configuration == nil)
        #expect(harness.transport.openCount == 0)
    }
    
    @Test
    func `A different enrollment tears down the old one before connecting`() async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        first.send(frame: ConfigFrames.snapshot(41))
        await waitUntil { harness.service.configuration != nil }
        
        harness.service.enrollmentDidChange(to: .enrolled(EnrollmentID("device-2")))
        #expect(harness.service.configuration == nil)
        await first.terminated()
        let second = await harness.transport.connection(2)
        await harness.service.cacheWorkFinished()
        
        #expect(harness.cache.deleteCount == 1)
        #expect(harness.clock.requestedSleeps.isEmpty)
        #expect(!second.isTerminated)
    }
    
    @Test
    func `No client identity means no connection attempt and no retry`() async {
        let harness = ConfigurationHarness(identity: .success(nil))
        
        harness.service.sceneDidChange(isForeground: true)
        harness.service.enrollmentDidChange(to: .enrolled(ConfigurationHarness.enrollment))
        await harness.service.connectionLoopFinished()
        
        #expect(harness.transport.openCount == 0)
        #expect(harness.clock.requestedSleeps.isEmpty)
    }
    
    @Test
    func `An unreadable identity backs off, then connects once the Keychain answers`() async {
        let harness = ConfigurationHarness(identity: .failure(.osStatus(errSecInteractionNotAllowed)))
        
        harness.service.sceneDidChange(isForeground: true)
        harness.service.enrollmentDidChange(to: .enrolled(ConfigurationHarness.enrollment))
        await harness.clock.sleepRequested(count: 1)
        #expect(harness.transport.openCount == 0)
        
        harness.identityProvider.replace(with: .success(ConfigurationHarness.identity))
        harness.clock.advance(by: .seconds(1))
        _ = await harness.transport.connection(1)
        #expect(harness.identityProvider.readCount == 2)
    }
    
    @Test
    func `No usable server URL means no connection attempt and no identity read`() async {
        let harness = ConfigurationHarness(apiConfiguration: nil)
        
        harness.service.sceneDidChange(isForeground: true)
        harness.service.enrollmentDidChange(to: .enrolled(ConfigurationHarness.enrollment))
        await harness.service.connectionLoopFinished()
        
        #expect(harness.transport.openCount == 0)
        #expect(harness.identityProvider.readCount == 0)
    }
    
    // MARK: - Scene lifecycle
    
    @Test
    func `The background closes the socket and leaves no reconnect scheduled`() async {
        let harness = ConfigurationHarness()
        let connection = await harness.start()
        connection.send(frame: ConfigFrames.snapshot(41))
        await waitUntil { harness.service.configuration != nil }
        
        harness.service.sceneDidChange(isForeground: false)
        await connection.terminated()
        await harness.service.connectionLoopFinished()
        
        #expect(harness.clock.pendingSleepCount == 0)
        #expect(harness.clock.requestedSleeps.isEmpty)
        #expect(harness.transport.openCount == 1)
        #expect(harness.service.configuration == ConfigFrames.defaultConfiguration)
    }
    
    @Test
    func `The foreground connects at once while enrolled`() async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        harness.service.sceneDidChange(isForeground: false)
        await first.terminated()
        
        harness.service.sceneDidChange(isForeground: true)
        let second = await harness.transport.connection(2)
        
        #expect(harness.clock.requestedSleeps.isEmpty)
        #expect(!second.isTerminated)
    }
    
    @Test
    func `Repeated inputs with the same value change nothing`() async {
        let harness = ConfigurationHarness()
        _ = await harness.start()
        
        harness.service.sceneDidChange(isForeground: true)
        harness.service.enrollmentDidChange(to: .enrolled(ConfigurationHarness.enrollment))
        await settle()
        
        #expect(harness.transport.openCount == 1)
    }
    
    // MARK: - Frames
    
    @Test
    func `Deltas that follow in order are applied and cached`() async {
        let harness = ConfigurationHarness()
        let connection = await harness.start()
        
        connection.send(frame: ConfigFrames.snapshot(41))
        connection.send(frame: ConfigFrames.delta(42, changed: #"{"maxItems":25}"#, removed: ["theme"]))
        connection.send(frame: ConfigFrames.delta(43, changed: #"{"beta":true}"#))
        await waitUntil { harness.service.configuration?.version == 43 }
        await harness.service.cacheWorkFinished()
        
        let expected = ManagedConfiguration(version: 43, values: ["maxItems": .integer(25), "beta": .bool(true)])
        #expect(harness.service.configuration == expected)
        #expect(harness.cache.stored == expected)
        #expect(!connection.isTerminated)
    }
    
    @Test
    func `A delta that skips a version is not applied and forces a reconnect for a snapshot`() async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        first.send(frame: ConfigFrames.snapshot(41))
        await waitUntil { harness.service.configuration?.version == 41 }
        
        first.send(frame: ConfigFrames.delta(43, changed: #"{"maxItems":30}"#))
        await first.terminated()
        #expect(harness.service.configuration == ConfigFrames.defaultConfiguration)
        
        await harness.passBackoff(number: 1, expected: .seconds(1))
        let second = await harness.transport.connection(2)
        second.send(frame: ConfigFrames.snapshot(43, values: #"{"maxItems":30}"#))
        await waitUntil { harness.service.configuration?.version == 43 }
        #expect(harness.service.configuration?.values == ["maxItems": .integer(30)])
    }
    
    @Test
    func `A heartbeat ahead of the state forces a reconnect; an equal one changes nothing`() async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        first.send(frame: ConfigFrames.snapshot(43))
        await waitUntil { harness.service.configuration?.version == 43 }
        
        first.send(frame: ConfigFrames.heartbeat(43))
        await settle()
        #expect(!first.isTerminated)
        
        first.send(frame: ConfigFrames.heartbeat(44))
        await first.terminated()
        await harness.passBackoff(number: 1, expected: .seconds(1))
        _ = await harness.transport.connection(2)
        #expect(harness.service.configuration?.version == 43)
    }
    
    @Test
    func `A frame that does not decode is skipped and the connection stays open`() async {
        let harness = ConfigurationHarness()
        let connection = await harness.start()
        connection.send(frame: ConfigFrames.snapshot(41))
        
        connection.send(frame: "not json")
        connection.send(frame: #"{"type":"rollback","version":40}"#)
        connection.send(frame: ConfigFrames.delta(42, changed: #"{"maxItems":25}"#))
        await waitUntil { harness.service.configuration?.version == 42 }
        
        #expect(!connection.isTerminated)
        #expect(harness.transport.openCount == 1)
    }
    
    @Test
    func `A delta before any snapshot forces a reconnect`() async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        
        first.send(frame: ConfigFrames.delta(1, changed: #"{"maxItems":25}"#))
        await first.terminated()
        await harness.passBackoff(number: 1, expected: .seconds(1))
        _ = await harness.transport.connection(2)
        
        #expect(harness.service.configuration == nil)
    }
    
    // MARK: - Close routing
    
    @Test(arguments: [
        ConfigurationStreamClose.closeCode(1008),
        .clientCertificateRejected,
        .handshakeRejected(statusCode: 401),
        .handshakeRejected(statusCode: 403)
    ])
    func `A refused identity stops the loop, flags it, and the foreground does not retry it`(close: ConfigurationStreamClose) async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        
        first.close(close)
        await harness.service.connectionLoopFinished()
        #expect(harness.service.isIdentityRejected)
        #expect(harness.clock.requestedSleeps.isEmpty)
        
        harness.service.sceneDidChange(isForeground: false)
        harness.service.sceneDidChange(isForeground: true)
        await settle()
        #expect(harness.transport.openCount == 1)
    }
    
    @Test
    func `A new enrollment clears the rejection and connects with the new identity`() async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        first.close(.clientCertificateRejected)
        await harness.service.connectionLoopFinished()
        
        harness.service.enrollmentDidChange(to: .enrolled(EnrollmentID("device-2")))
        _ = await harness.transport.connection(2)
        #expect(!harness.service.isIdentityRejected)
        #expect(harness.clock.requestedSleeps.isEmpty)
    }
    
    @Test
    func `A try-again-later close backs off`() async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        
        first.close(code: 1013)
        await harness.clock.sleepRequested(count: 1)
        #expect(harness.clock.requestedSleeps == [.seconds(1)])
        harness.clock.advance(by: .milliseconds(999))
        await settle()
        #expect(harness.transport.openCount == 1)
        
        harness.clock.advance(by: .milliseconds(1))
        _ = await harness.transport.connection(2)
    }
    
    @Test(arguments: [400, 404, 503])
    func `A handshake refused for another reason backs off and retries`(status: Int) async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        
        first.close(.handshakeRejected(statusCode: status))
        await harness.passBackoff(number: 1, expected: .seconds(1))
        _ = await harness.transport.connection(2)
        
        #expect(!harness.service.isIdentityRejected)
    }
    
    @Test(arguments: [1011, 1001])
    func `A server-error or going-away close reconnects and the next snapshot replaces the state`(code: Int) async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        first.send(frame: ConfigFrames.snapshot(41))
        await waitUntil { harness.service.configuration?.version == 41 }
        
        first.close(code: code)
        await harness.passBackoff(number: 1, expected: .seconds(1))
        let second = await harness.transport.connection(2)
        second.send(frame: ConfigFrames.snapshot(50, values: #"{"theme":"light"}"#))
        await waitUntil { harness.service.configuration?.version == 50 }
        
        #expect(harness.service.configuration?.values == ["theme": .string("light")])
    }
    
    @Test
    func `Failed attempts escalate the delay and a heartbeat after the snapshot resets it`() async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        
        first.close(code: 1013)
        await harness.passBackoff(number: 1, expected: .seconds(1))
        let second = await harness.transport.connection(2)
        second.close(code: 1013)
        await harness.passBackoff(number: 2, expected: .seconds(2))
        let third = await harness.transport.connection(3)
        third.send(frame: ConfigFrames.snapshot(41))
        await waitUntil { harness.service.configuration != nil }
        harness.clock.advance(by: .seconds(25))
        third.send(frame: ConfigFrames.heartbeat(41))
        await settle()
        third.close(code: 1011)
        await harness.passBackoff(number: 3, expected: .seconds(1))
        _ = await harness.transport.connection(4)
        
        #expect(harness.clock.requestedSleeps == [.seconds(1), .seconds(2), .seconds(1)])
    }
    
    @Test
    func `A snapshot followed straight by a close does not reset the delay`() async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        
        first.close(code: 1013)
        await harness.passBackoff(number: 1, expected: .seconds(1))
        let second = await harness.transport.connection(2)
        second.send(frame: ConfigFrames.snapshot(41))
        await waitUntil { harness.service.configuration != nil }
        second.close(code: 1011)
        await harness.passBackoff(number: 2, expected: .seconds(2))
        _ = await harness.transport.connection(3)
    }
    
    @Test
    func `A heartbeat before 25 s of uptime does not reset the delay`() async {
        let harness = ConfigurationHarness()
        var connection = await harness.start()
        for number in 1...3 {
            connection.send(frame: ConfigFrames.snapshot(41))
            connection.send(frame: ConfigFrames.heartbeat(41))
            await waitUntil { harness.service.configuration != nil }
            await settle()
            connection.close(code: 1013)
            await harness.passBackoff(number: number, expected: .seconds(1 << (number - 1)))
            connection = await harness.transport.connection(number + 1)
        }
    }
    
    @Test
    func `A delta that would grow the configuration past the byte limit is a gap and is not applied`() async {
        let harness = ConfigurationHarness()
        let connection = await harness.start()
        let half = String(repeating: "x", count: ConfigurationLimits.maximumMessageSize / 2 + 1)
        connection.send(frame: ConfigFrames.snapshot(41))
        connection.send(frame: ConfigFrames.delta(42, changed: #"{"a":"\#(half)"}"#))
        await waitUntil { harness.service.configuration?.version == 42 }
        
        connection.send(frame: ConfigFrames.delta(43, changed: #"{"b":"\#(half)"}"#))
        await connection.terminated()
        
        #expect(harness.service.configuration?.version == 42)
    }
    
    @Test
    func `A frame nested past the depth limit is skipped and the connection stays open`() async {
        let harness = ConfigurationHarness()
        let connection = await harness.start()
        connection.send(frame: ConfigFrames.snapshot(41))
        let tooDeep = String(repeating: "[", count: 31) + String(repeating: "]", count: 31)
        
        connection.send(frame: ConfigFrames.delta(42, changed: #"{"deep":\#(tooDeep)}"#))
        connection.send(frame: ConfigFrames.delta(42, changed: #"{"maxItems":25}"#))
        await waitUntil { harness.service.configuration?.version == 42 }
        
        #expect(harness.service.configuration?.values["deep"] == nil)
        #expect(!connection.isTerminated)
        #expect(harness.transport.openCount == 1)
    }
    
    // MARK: - Offline cache
    
    @Test
    func `A cold launch applies the cache before connecting and recovers with backoff`() async {
        let cached = ManagedConfiguration(version: 7, values: ["theme": .string("dark")])
        let harness = ConfigurationHarness(cache: InMemoryConfigurationCache(stored: cached))
        
        let first = await harness.start()
        #expect(harness.service.configuration == cached)
        #expect(harness.cache.loadCount == 1)
        
        first.close(.connectionFailed)
        await harness.passBackoff(number: 1, expected: .seconds(1))
        let second = await harness.transport.connection(2)
        #expect(harness.service.configuration == cached)
        second.send(frame: ConfigFrames.snapshot(8))
        await waitUntil { harness.service.configuration?.version == 8 }
    }
    
    @Test
    func `A stalled cache retains only the latest pending configuration`() async {
        let started = Gate()
        let release = Gate()
        let cache = InMemoryConfigurationCache(saveHook: { configuration in
            if configuration.version == 1 {
                started.open()
                await release.wait()
            }
        })
        let harness = ConfigurationHarness(cache: cache)
        let connection = await harness.start()
        connection.send(frame: ConfigFrames.snapshot(1))
        await started.wait()
        for version in 2...1000 {
            connection.send(frame: ConfigFrames.snapshot(Int64(version)))
        }
        await waitUntil { harness.service.configuration?.version == 1000 }
        release.open()
        await harness.service.cacheWorkFinished()
        #expect(cache.saveCount == 2)
        #expect(cache.stored?.version == 1000)
        harness.service.enrollmentDidChange(to: .unenrolled)
    }
    
    @Test
    func `Unenrollment discards a coalesced save after an active save finishes`() async {
        let started = Gate()
        let release = Gate()
        let cache = InMemoryConfigurationCache(saveHook: { _ in started.open()
            await release.wait()
        })
        let harness = ConfigurationHarness(cache: cache)
        let connection = await harness.start()
        connection.send(frame: ConfigFrames.snapshot(1))
        await started.wait()
        connection.send(frame: ConfigFrames.snapshot(2))
        await waitUntil { harness.service.configuration?.version == 2 }
        harness.service.enrollmentDidChange(to: .unenrolled)
        release.open()
        await harness.service.cacheWorkFinished()
        #expect(cache.saveCount == 1)
        #expect(cache.deleteCount == 1)
        #expect(cache.stored == nil)
    }
    
    @Test
    func `An ended stream without a close reconnects for a fresh snapshot after backoff`() async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        first.send(frame: ConfigFrames.snapshot(1))
        await waitUntil { harness.service.configuration?.version == 1 }
        first.finish()
        await harness.passBackoff(number: 1, expected: .seconds(1))
        let second = await harness.transport.connection(2)
        second.send(frame: ConfigFrames.snapshot(99))
        await waitUntil { harness.service.configuration?.version == 99 }
        harness.service.enrollmentDidChange(to: .unenrolled)
    }
}
