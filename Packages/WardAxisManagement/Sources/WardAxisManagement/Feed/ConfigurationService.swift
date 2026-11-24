//
//  ConfigurationService.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Observation
import WardAxisTelemetry

/// The configuration service over the `/config/stream` WebSocket.
///
/// All state is main-actor, and one `connectionTask` runs the whole loop: wait
/// the backoff, read the identity, open, apply frames, route the close, repeat.
/// Each teardown bumps `epoch`; work that resumes after an `await` under an older
/// epoch is dropped.
///
/// Cache operations run in one chain (`cacheTask`), so an unenrollment delete can
/// never be overtaken by an earlier save, and the cold-launch load finishes
/// before the first connection attempt.
@MainActor @Observable
public final class ConfigurationService: ConfigurationServiceProtocol {
    public private(set) var configuration: ManagedConfiguration?
    public private(set) var isIdentityRejected = false

    @ObservationIgnored private var enrollment: EnrollmentState = .restoring
    @ObservationIgnored private var isForeground = false

    /// Changes on every teardown. A loop started under an older value stops.
    @ObservationIgnored private var epoch: UInt64 = 0

    /// Changes on every enrollment end, so a cache load for an ended enrollment is dropped.
    @ObservationIgnored private var enrollmentGeneration: UInt64 = 0

    /// Reconnects since a connection last proved healthy: a heartbeat after its
    /// snapshot, at least ``minimumHealthyUptime`` after it opened. Neither a
    /// snapshot nor an early heartbeat resets it, so a server that closes soon
    /// after either still escalates the delay.
    @ObservationIgnored private var attempt = 0
    static let minimumHealthyUptime: Duration = .seconds(25)

    @ObservationIgnored private var hasLoadedCache = false
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    /// The most recent loop, kept after a teardown so tests can await its end.
    @ObservationIgnored private var latestConnectionTask: Task<Void, Never>?
    @ObservationIgnored private var cacheTask: Task<Void, Never>?

    // Existentials: each dependency is a protocol seam with a test double.
    private let apiConfiguration: APIConfiguration?
    private let identityProvider: any ClientIdentityProvider
    private let transport: any ConfigurationStreamTransport
    private let cache: any ConfigurationCacheProtocol
    private let clock: any Clock<Duration>
    private let backoff: ReconnectBackoff
    private let decoder = ConfigurationFrameDecoder()
    private let logger = Log(category: .management)

    /// - Parameter apiConfiguration: The server base URL; `nil` keeps the service idle.
    public init(
        apiConfiguration: APIConfiguration?,
        identityProvider: any ClientIdentityProvider,
        transport: any ConfigurationStreamTransport,
        cache: any ConfigurationCacheProtocol,
        clock: any Clock<Duration> = ContinuousClock(),
        jitter: @escaping @Sendable (Duration) -> Duration = ReconnectBackoff.fullJitter
    ) {
        self.apiConfiguration = apiConfiguration
        self.identityProvider = identityProvider
        self.transport = transport
        self.cache = cache
        self.clock = clock
        backoff = ReconnectBackoff(jitter: jitter)
    }

    /// The production service for `bundle`'s `APIBaseURL`.
    public static func live(bundle: Bundle, identityProvider: any ClientIdentityProvider) -> ConfigurationService {
        let rawValue = bundle.object(forInfoDictionaryKey: APIConfiguration.infoPlistKey) as? String
        let apiConfiguration = try? APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: APIConfiguration.requiresHTTPS)
        return ConfigurationService(
            apiConfiguration: apiConfiguration,
            identityProvider: identityProvider,
            transport: URLSessionWebSocketTransport(),
            cache: FileConfigurationCache.live()
        )
    }

    // MARK: - ConfigurationServiceProtocol

    public func enrollmentDidChange(to state: EnrollmentState) {
        guard state != enrollment else { return }
        let previous = enrollment
        enrollment = state
        switch state {
        case .restoring:
            stopConnection()
        case .unenrolled:
            endEnrollment()
        case .enrolled:
            if case .enrolled = previous {
                endEnrollment()
            }
            isIdentityRejected = false
            loadCacheIfNeeded()
            reconcile()
        }
    }

    public func sceneDidChange(isForeground: Bool) {
        guard isForeground != self.isForeground else { return }
        self.isForeground = isForeground
        if isForeground {
            reconcile()
        } else {
            stopConnection()
        }
    }

    // MARK: - Test seams

    /// Returns once the connection loop has stopped by itself or was torn down.
    public func connectionLoopFinished() async {
        await latestConnectionTask?.value
    }

    /// Returns once every queued cache operation has run.
    public func cacheWorkFinished() async {
        while let task = cacheTask {
            await task.value
            if cacheTask == task {
                return
            }
        }
    }

    // MARK: - Lifecycle

    private func reconcile() {
        guard case .enrolled = enrollment, isForeground, !isIdentityRejected, connectionTask == nil else { return }
        startConnection()
    }

    private func stopConnection() {
        epoch &+= 1
        connectionTask?.cancel()
        connectionTask = nil
    }

    private func endEnrollment() {
        stopConnection()
        enrollmentGeneration &+= 1
        attempt = 0
        hasLoadedCache = false
        isIdentityRejected = false
        configuration = nil
        enqueueCacheOperation("delete") { try await $0.delete() }
    }

    // MARK: - Connection loop

    private enum ConnectionStep {
        case connect(URLRequest, ClientIdentity)
        case retry(after: Duration)
        case stop
    }

    private enum ConnectionEnd {
        case closed(ConfigurationStreamClose)
        case gap
        case stopped
    }

    private func startConnection() {
        let loopEpoch = epoch
        let transport = transport
        let clock = clock
        connectionTask = Task { [weak self] in
            defer { self?.connectionLoopDidEnd(epoch: loopEpoch) }
            var delay: Duration?
            while true {
                if let delay {
                    // try, never try?: a cancelled sleep must end the loop.
                    do {
                        try await clock.sleep(for: delay)
                    } catch {
                        return
                    }
                }
                guard let step = await self?.prepareConnection(epoch: loopEpoch) else { return }
                let request: URLRequest
                let identity: ClientIdentity
                switch step {
                case .stop:
                    return
                case let .retry(after):
                    delay = after
                    continue
                case let .connect(connectRequest, connectIdentity):
                    request = connectRequest
                    identity = connectIdentity
                }
                let stream = transport.open(request, identity: identity)
                let uptime = Self.stopwatch(clock)
                // A gap or a teardown cancels this reader and drains the stream: that
                // runs the transport's termination handler, which closes the socket.
                // Dropping the stream would not, since the transport still holds it.
                let consumer = Task { [weak self] () -> ConnectionEnd in
                    var end: ConnectionEnd?
                    var hasSnapshot = false
                    for await event in stream {
                        guard end == nil else { continue }
                        guard let self, isCurrent(loopEpoch) else {
                            end = .stopped
                            withUnsafeCurrentTask { $0?.cancel() }
                            continue
                        }
                        end = handle(event, hasSnapshot: &hasSnapshot, uptime: uptime)
                        if case .gap? = end {
                            withUnsafeCurrentTask { $0?.cancel() }
                        }
                    }
                    return end ?? .stopped
                }
                let end = await withTaskCancellationHandler {
                    await consumer.value
                } onCancel: {
                    consumer.cancel()
                }
                guard let next = self?.delay(after: end, epoch: loopEpoch) else {
                    return
                }
                delay = next
            }
        }
        latestConnectionTask = connectionTask
    }

    private func connectionLoopDidEnd(epoch loopEpoch: UInt64) {
        if epoch == loopEpoch {
            connectionTask = nil
        }
    }

    private func prepareConnection(epoch loopEpoch: UInt64) async -> ConnectionStep {
        await cacheTask?.value
        guard isCurrent(loopEpoch) else { return .stop }
        guard let request = ConfigurationStreamRequest.make(configuration: apiConfiguration) else {
            logger.info("Configuration feed idle: no usable https server URL", privacy: .public)
            return .stop
        }
        let identity: ClientIdentity?
        do {
            identity = try await identityProvider.currentIdentity()
        } catch {
            guard isCurrent(loopEpoch) else { return .stop }
            logger.info("Client identity unreadable (\(Self.logName(of: error))); backing off", privacy: .public)
            return .retry(after: nextBackoffDelay())
        }
        guard isCurrent(loopEpoch) else { return .stop }
        guard let identity else {
            logger.info("Configuration feed idle: no client identity", privacy: .public)
            return .stop
        }
        return .connect(request, identity)
    }

    /// How `event` ends the connection, or `nil` while it stays open.
    private func handle(
        _ event: ConfigurationStreamEvent,
        hasSnapshot: inout Bool,
        uptime: () -> Duration
    ) -> ConnectionEnd? {
        switch event {
        case .opened:
            logger.info("Configuration feed connected", privacy: .public)
            return nil
        case let .message(data):
            return apply(data, hasSnapshot: &hasSnapshot, uptime: uptime) ? nil : .gap
        case let .closed(close):
            return .closed(close)
        }
    }

    /// The delay before the next attempt, or `nil` to stop.
    private func delay(after end: ConnectionEnd, epoch loopEpoch: UInt64) -> Duration? {
        guard isCurrent(loopEpoch) else { return nil }
        let close: ConfigurationStreamClose
        switch end {
        case .stopped:
            return nil
        case .gap:
            logger.info("Configuration version gap; reconnecting for a snapshot", privacy: .public)
            return nextBackoffDelay()
        case let .closed(reason):
            close = reason
        }
        switch ConfigurationCloseRoute.route(for: close) {
        case .reconnect:
            logger.info("Configuration feed closed (\(Self.logName(of: close))); reconnecting", privacy: .public)
        case .backOff:
            logger.info("Configuration feed closed (\(Self.logName(of: close))); backing off", privacy: .public)
        case .identityRejected:
            logger.warning("Configuration feed refused the client identity (\(Self.logName(of: close))); staying idle", privacy: .public)
            isIdentityRejected = true
            return nil
        }
        return nextBackoffDelay()
    }

    private func isCurrent(_ loopEpoch: UInt64) -> Bool {
        epoch == loopEpoch && !Task.isCancelled
    }

    private func nextBackoffDelay() -> Duration {
        defer { attempt += 1 }
        return backoff.delay(forAttempt: attempt)
    }

    // MARK: - Frames

    /// Applies one frame. Returns `false` on a version gap, which needs a new
    /// connection for a fresh snapshot.
    private func apply(_ data: Data, hasSnapshot: inout Bool, uptime: () -> Duration) -> Bool {
        guard let frame = decoder.decode(data) else {
            logger.info("Skipped an undecodable configuration frame of \(data.count) bytes", privacy: .public)
            return true
        }
        switch frame {
        case let .snapshot(snapshot):
            hasSnapshot = true
            adopt(snapshot)
        case let .delta(version, changed, removed):
            guard hasSnapshot, let current = configuration, current.version < .max, version == current.version + 1 else {
                logger.info("Configuration delta \(version) is out of order", privacy: .public)
                return false
            }
            var entries = current.values
            entries.merge(changed) { _, new in new }
            for name in removed {
                entries[name] = nil
            }
            guard entries.count <= ConfigurationLimits.maximumEntryCount, ConfigurationLimits.fitsByteLimit(entries) else {
                logger.warning("Configuration delta \(version) exceeds the size limits", privacy: .public)
                return false
            }
            adopt(ManagedConfiguration(version: version, values: entries))
        case let .heartbeat(version):
            guard hasSnapshot, let current = configuration else { break }
            if version > current.version {
                logger.info("Configuration heartbeat \(version) is ahead of \(current.version)", privacy: .public)
                return false
            }
            if uptime() >= Self.minimumHealthyUptime {
                attempt = 0
            }
        }
        return true
    }

    private func adopt(_ next: ManagedConfiguration) {
        configuration = next
        enqueueCacheOperation("save") { try await $0.save(next) }
    }

    // MARK: - Cache

    private func loadCacheIfNeeded() {
        guard !hasLoadedCache else { return }
        hasLoadedCache = true
        let loadGeneration = enrollmentGeneration
        let previous = cacheTask
        let cache = cache
        cacheTask = Task { [weak self] in
            await previous?.value
            let cached = await cache.load()
            guard let self, let cached, enrollmentGeneration == loadGeneration, configuration == nil else { return }
            configuration = cached
            logger.info("Applied cached configuration version \(cached.version)", privacy: .public)
        }
    }

    private func enqueueCacheOperation(
        _ name: String,
        _ operation: @escaping @Sendable (any ConfigurationCacheProtocol) async throws -> Void
    ) {
        let previous = cacheTask
        let cache = cache
        let logger = logger
        cacheTask = Task {
            await previous?.value
            do {
                try await operation(cache)
            } catch {
                logger.error("Configuration cache \(name) failed: \(FileConfigurationCache.logName(of: error))", privacy: .public)
            }
        }
    }

    // MARK: - Helpers

    /// Time elapsed on `clock` since this call. Generic so the existential's
    /// instants can be compared.
    private static func stopwatch(_ clock: some Clock<Duration>) -> @Sendable () -> Duration {
        let start = clock.now
        return { start.duration(to: clock.now) }
    }

    private static func logName(of close: ConfigurationStreamClose) -> String {
        switch close {
        case let .closeCode(code): "close code \(code)"
        case let .handshakeRejected(status): "handshake status \(status)"
        case .clientCertificateRejected: "client certificate rejected"
        case .connectionFailed: "connection failed"
        }
    }

    /// The case name and OS status only, never a payload.
    private static func logName(of error: ClientIdentityError) -> String {
        switch error {
        case let .osStatus(status): "OSStatus \(status)"
        }
    }
}
