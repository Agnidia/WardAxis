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

    @Test("Enrolling opens exactly one connection with the identity, no credential header and no query")
    func enrollmentConnectsOnce() async throws {
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

    @Test("Unenrollment closes the socket, schedules nothing, deletes the cache and clears the state")
    func unenrollmentTearsDown() async {
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

    @Test("A save still in flight at unenrollment cannot bring the cache back")
    func saveInFlightThenUnenroll() async {
        let gate = Gate()
        let cache = InMemoryConfigurationCache(saveHook: { _ in await gate.wait() })
        let harness = ConfigurationHarness(cache: cache)
        let connection = await harness.start()
        connection.send(frame: ConfigFrames.snapshot(41))
        await waitUntil { harness.service.configuration != nil }

        harness.service.enrollmentDidChange(to: .unenrolled)
        gate.open()
        await harness.service.cacheWorkFinished()

        #expect(cache.saveCount == 1)
        #expect(cache.deleteCount == 1)
        #expect(cache.stored == nil)
    }

    @Test("A launch that settles unenrolled deletes a leftover cache and opens nothing")
    func unenrolledLaunchDeletesLeftoverCache() async {
        let cache = InMemoryConfigurationCache(stored: ConfigFrames.defaultConfiguration)
        let harness = ConfigurationHarness(cache: cache)

        harness.service.sceneDidChange(isForeground: true)
        harness.service.enrollmentDidChange(to: .unenrolled)
        await harness.service.cacheWorkFinished()

        #expect(cache.stored == nil)
        #expect(harness.service.configuration == nil)
        #expect(harness.transport.openCount == 0)
    }

    @Test("A different enrollment tears down the old one before connecting")
    func reenrollmentIsUnenrollThenEnroll() async {
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

    @Test("No client identity means no connection attempt and no retry")
    func missingIdentityOpensNothing() async {
        let harness = ConfigurationHarness(identity: .success(nil))

        harness.service.sceneDidChange(isForeground: true)
        harness.service.enrollmentDidChange(to: .enrolled(ConfigurationHarness.enrollment))
        await harness.service.connectionLoopFinished()

        #expect(harness.transport.openCount == 0)
        #expect(harness.clock.requestedSleeps.isEmpty)
    }

    @Test("An unreadable identity backs off, then connects once the Keychain answers")
    func unreadableIdentityBacksOff() async {
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

    @Test("No usable server URL means no connection attempt and no identity read")
    func nilServerURLOpensNothing() async {
        let harness = ConfigurationHarness(apiConfiguration: nil)

        harness.service.sceneDidChange(isForeground: true)
        harness.service.enrollmentDidChange(to: .enrolled(ConfigurationHarness.enrollment))
        await harness.service.connectionLoopFinished()

        #expect(harness.transport.openCount == 0)
        #expect(harness.identityProvider.readCount == 0)
    }

    // MARK: - Scene lifecycle

    @Test("The background closes the socket and leaves no reconnect scheduled")
    func backgroundPauses() async {
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

    @Test("The foreground connects at once while enrolled")
    func foregroundResumesWithoutDelay() async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        harness.service.sceneDidChange(isForeground: false)
        await first.terminated()

        harness.service.sceneDidChange(isForeground: true)
        let second = await harness.transport.connection(2)

        #expect(harness.clock.requestedSleeps.isEmpty)
        #expect(!second.isTerminated)
    }

    @Test("Repeated inputs with the same value change nothing")
    func inputsAreIdempotent() async {
        let harness = ConfigurationHarness()
        _ = await harness.start()

        harness.service.sceneDidChange(isForeground: true)
        harness.service.enrollmentDidChange(to: .enrolled(ConfigurationHarness.enrollment))
        await settle()

        #expect(harness.transport.openCount == 1)
    }

    // MARK: - Frames

    @Test("Deltas that follow in order are applied and cached")
    func deltaOrdering() async {
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

    @Test("A delta that skips a version is not applied and forces a reconnect for a snapshot")
    func versionGap() async {
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

    @Test("A heartbeat ahead of the state forces a reconnect; an equal one changes nothing")
    func heartbeatGap() async {
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

    @Test("A frame that does not decode is skipped and the connection stays open")
    func undecodableFrameIsSkipped() async {
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

    @Test("A delta before any snapshot forces a reconnect")
    func deltaBeforeSnapshot() async {
        let harness = ConfigurationHarness()
        let first = await harness.start()

        first.send(frame: ConfigFrames.delta(1, changed: #"{"maxItems":25}"#))
        await first.terminated()
        await harness.passBackoff(number: 1, expected: .seconds(1))
        _ = await harness.transport.connection(2)

        #expect(harness.service.configuration == nil)
    }

    // MARK: - Close routing

    @Test("A refused identity stops the loop, flags it, and the foreground does not retry it", arguments: [
        ConfigurationStreamClose.closeCode(1008),
        .clientCertificateRejected,
        .handshakeRejected(statusCode: 401),
        .handshakeRejected(statusCode: 403)
    ])
    func rejectedIdentityStops(close: ConfigurationStreamClose) async {
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

    @Test("A new enrollment clears the rejection and connects with the new identity")
    func reenrollmentClearsRejection() async {
        let harness = ConfigurationHarness()
        let first = await harness.start()
        first.close(.clientCertificateRejected)
        await harness.service.connectionLoopFinished()

        harness.service.enrollmentDidChange(to: .enrolled(EnrollmentID("device-2")))
        _ = await harness.transport.connection(2)
        #expect(!harness.service.isIdentityRejected)
        #expect(harness.clock.requestedSleeps.isEmpty)
    }





    @Test("A try-again-later close backs off")
    func tryAgainLaterBacksOff() async {
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

    @Test("A handshake refused for another reason backs off and retries", arguments: [400, 404, 503])
    func refusedHandshakeBacksOff(status: Int) async {
        let harness = ConfigurationHarness()
        let first = await harness.start()

        first.close(.handshakeRejected(statusCode: status))
        await harness.passBackoff(number: 1, expected: .seconds(1))
        _ = await harness.transport.connection(2)

        #expect(!harness.service.isIdentityRejected)
    }

    @Test("A server-error or going-away close reconnects and the next snapshot replaces the state", arguments: [1011, 1001])
    func serverCloseReconnects(code: Int) async {
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

    @Test("Failed attempts escalate the delay and a heartbeat after the snapshot resets it")
    func healthyConnectionResetsBackoff() async {
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

    @Test("A snapshot followed straight by a close does not reset the delay")
    func snapshotAloneDoesNotResetBackoff() async {
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

    @Test("A heartbeat before 25 s of uptime does not reset the delay")
    func earlyHeartbeatDoesNotReset() async {
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

    @Test("A delta that would grow the configuration past the byte limit is a gap and is not applied")
    func mergedByteLimit() async {
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



    @Test("A frame nested past the depth limit is skipped and the connection stays open")
    func overDeepFrameIsSkipped() async {
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

    @Test("A cold launch applies the cache before connecting and recovers with backoff")
    func cacheFallback() async {
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
}
