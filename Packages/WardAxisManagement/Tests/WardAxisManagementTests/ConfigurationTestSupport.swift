//
//  ConfigurationTestSupport.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Synchronization
import Testing
import WardAxisManagementTestSupport
@testable import WardAxisManagement

// MARK: - Harness

/// A ``ConfigurationService`` over scripted doubles, with identity jitter so
/// every delay equals its backoff upper bound.
@MainActor
struct ConfigurationHarness {
    static let enrollment = EnrollmentID("device-1")
    static let apiConfiguration = APIConfiguration(baseURL: URL(string: "https://api.example.com")!)
    nonisolated static let identity = ClientIdentity(testCredential: URLCredential(user: "device", password: "unused", persistence: .none))
    
    let service: ConfigurationService
    let transport = ScriptedStreamTransport()
    let clock = ManualClock()
    let cache: InMemoryConfigurationCache
    let identityProvider: StaticClientIdentityProvider
    
    init(
        identity: Result<ClientIdentity?, ClientIdentityError> = .success(Self.identity),
        cache: InMemoryConfigurationCache = InMemoryConfigurationCache(),
        apiConfiguration: APIConfiguration? = Self.apiConfiguration
    ) {
        self.cache = cache
        identityProvider = StaticClientIdentityProvider(identity)
        service = ConfigurationService(
            apiConfiguration: apiConfiguration,
            identityProvider: identityProvider,
            transport: transport,
            cache: cache,
            clock: clock,
            jitter: { $0 }
        )
    }
    
    /// Moves to the foreground and enrolls, and returns the first connection.
    func start() async -> ScriptedStreamTransport.Connection {
        service.sceneDidChange(isForeground: true)
        service.enrollmentDidChange(to: .enrolled(Self.enrollment))
        return await transport.connection(1)
    }
    
    /// Waits for the next backoff sleep, checks its length, and lets it pass.
    func passBackoff(number: Int, expected: Duration, sourceLocation: SourceLocation = #_sourceLocation) async {
        await clock.sleepRequested(count: number)
        #expect(clock.requestedSleeps.last == expected, sourceLocation: sourceLocation)
        clock.advance(by: expected)
    }
}

enum ConfigFrames {
    static let defaultValues = #"{"maxItems":20,"theme":"dark"}"#
    
    static func snapshot(_ version: Int64, values: String = defaultValues) -> String {
        #"{"type":"snapshot","version":\#(version),"values":\#(values)}"#
    }
    
    static func delta(_ version: Int64, changed: String = "{}", removed: [String] = []) -> String {
        let names = removed.map { #""\#($0)""# }.joined(separator: ",")
        return #"{"type":"delta","version":\#(version),"changed":\#(changed),"removed":[\#(names)]}"#
    }
    
    static func heartbeat(_ version: Int64) -> String {
        #"{"type":"heartbeat","version":\#(version)}"#
    }
    
    static let defaultConfiguration = ManagedConfiguration(
        version: 41,
        values: ["maxItems": .integer(20), "theme": .string("dark")]
    )
}

/// Payloads that a looser pre-scan let through to `JSONDecoder` with 300 levels
/// of nesting. Each wraps `body`, the part after `{` that holds the deep value.
enum HostilePayloads {
    static let deep = String(repeating: "[", count: 300) + String(repeating: "]", count: 300)
    
    static func all(envelope: String) -> [(name: String, data: Data)] {
        let plain = #"{\#(envelope),"values":{"k":\#(deep)}}"#
        let escapeTrick = #"{\#(envelope),"x":"\uAAA\","values":{"k":\#(deep)}}"#
        // U+5B22 encodes as 22 5B in UTF-16LE: its first byte is a quote, which fools a byte scan.
        let quoteByte = #"{\#(envelope),"x":"\#u{5B22}","values":{"k":\#(deep)}}"#
        var withNUL = Data(#"{\#(envelope),"#.utf8)
        withNUL.append(0)
        withNUL.append(Data(#""values":{}}"#.utf8))
        return [
            ("UTF-16LE", plain.data(using: .utf16LittleEndian)!),
            ("UTF-16LE with U+5B22", quoteByte.data(using: .utf16LittleEndian)!),
            ("UTF-16BE", plain.data(using: .utf16BigEndian)!),
            ("UTF-32LE", plain.data(using: .utf32LittleEndian)!),
            ("unchecked \\u escape", Data(escapeTrick.utf8)),
            ("NUL byte", withNUL)
        ]
    }
}

/// Lets other main-actor work run, for checks that something did not happen.
/// Yields until `condition` holds; the suite's time limit bounds a condition that never does.
@MainActor
func waitUntil(_ condition: @MainActor () -> Bool) async {
    while !condition() {
        await Task.yield()
    }
}

/// Holds async work until the test opens it.
final class Gate: Sendable {
    private struct State {
        var isOpen = false
        var waiters: [CheckedContinuation<Void, Never>] = []
    }
    
    private let state = Mutex(State())
    
    func open() {
        let waiters = state.withLock { state in
            state.isOpen = true
            defer { state.waiters = [] }
            return state.waiters
        }
        waiters.forEach { $0.resume() }
    }
    
    func wait() async {
        await withCheckedContinuation { continuation in
            let passes = state.withLock { state in
                guard !state.isOpen else { return true }
                state.waiters.append(continuation)
                return false
            }
            if passes {
                continuation.resume()
            }
        }
    }
}

@MainActor
func settle() async {
    for _ in 0..<1000 {
        await Task.yield()
    }
}

// MARK: - Manual clock

/// A `Clock` that moves only on ``advance(by:)``. Records every requested sleep.
final class ManualClock: Clock {
    struct Instant: InstantProtocol {
        let offset: Duration
        
        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }
        
        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }
        
        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }
    
    private struct Sleeper {
        let id: Int
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }
    
    private struct State {
        var now = Instant(offset: .zero)
        var nextID = 0
        var sleepers: [Sleeper] = []
        /// Sleeps cancelled before they registered.
        var cancelledIDs: Set<Int> = []
        var requested: [Duration] = []
        var requestWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
        
        mutating func takeSatisfiedRequestWaiters() -> [CheckedContinuation<Void, Never>] {
            let count = requested.count
            let ready = requestWaiters.filter { $0.count <= count }.map(\.continuation)
            requestWaiters.removeAll { $0.count <= count }
            return ready
        }
    }
    
    private let state = Mutex(State())
    
    var now: Instant {
        state.withLock { $0.now }
    }
    
    var minimumResolution: Duration {
        .zero
    }
    
    var pendingSleepCount: Int {
        state.withLock { $0.sleepers.count }
    }
    
    var requestedSleeps: [Duration] {
        state.withLock { $0.requested }
    }
    
    func sleep(until deadline: Instant, tolerance _: Duration?) async throws {
        let id = state.withLock { state in
            state.nextID += 1
            return state.nextID
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let (outcome, waiters) = state.withLock { state -> (Result<Void, any Error>?, [CheckedContinuation<Void, Never>]) in
                    state.requested.append(state.now.duration(to: deadline))
                    let waiters = state.takeSatisfiedRequestWaiters()
                    if state.cancelledIDs.remove(id) != nil {
                        return (.failure(CancellationError()), waiters)
                    }
                    if deadline <= state.now {
                        return (.success(()), waiters)
                    }
                    state.sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
                    return (nil, waiters)
                }
                waiters.forEach { $0.resume() }
                if let outcome {
                    continuation.resume(with: outcome)
                }
            }
        } onCancel: {
            let continuation = state.withLock { state -> CheckedContinuation<Void, any Error>? in
                guard let index = state.sleepers.firstIndex(where: { $0.id == id }) else {
                    state.cancelledIDs.insert(id)
                    return nil
                }
                return state.sleepers.remove(at: index).continuation
            }
            continuation?.resume(throwing: CancellationError())
        }
    }
    
    func advance(by duration: Duration) {
        let due = state.withLock { state in
            state.now = state.now.advanced(by: duration)
            let now = state.now
            let due = state.sleepers.filter { $0.deadline <= now }.map(\.continuation)
            state.sleepers.removeAll { $0.deadline <= now }
            return due
        }
        due.forEach { $0.resume() }
    }
    
    /// Returns once at least `count` sleeps have been requested in total.
    func sleepRequested(count: Int) async {
        await withCheckedContinuation { continuation in
            let passes = state.withLock { state in
                guard state.requested.count < count else { return true }
                state.requestWaiters.append((count, continuation))
                return false
            }
            if passes {
                continuation.resume()
            }
        }
    }
}
