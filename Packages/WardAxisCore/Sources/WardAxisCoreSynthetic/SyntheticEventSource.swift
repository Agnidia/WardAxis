//
//  SyntheticEventSource.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisCore

/// A deterministic stream of flow-decision events from a fixed catalog.
///
/// Every event is ``EventProvenance/synthetic``; the source cannot emit any
/// other provenance. The initializer validates the catalog, so the source never
/// produces what ``SchemaCodec`` would refuse and never fails midway through a batch.
public actor SyntheticEventSource: SecurityEventSourceProtocol {
    public static let defaultApplications = [
        ApplicationIdentity(signingIdentifier: "com.example.browser", teamIdentifier: "EXAMPLE001", isPlatformBinary: false, bundleIdentifier: "com.example.browser"),
        ApplicationIdentity(signingIdentifier: "com.example.mail", teamIdentifier: "EXAMPLE002", isPlatformBinary: false, bundleIdentifier: "com.example.mail"),
        ApplicationIdentity(signingIdentifier: "com.apple.curl", teamIdentifier: nil, isPlatformBinary: true, bundleIdentifier: nil)
    ]
    
    /// Reserved documentation names and addresses only (RFC 2606, RFC 5737, RFC 3849).
    public static let defaultHosts = ["example.com", "www.example.org", "api.example.net", "192.0.2.10", "2001:db8::1"]
    
    private var generator: SeededGenerator
    private var remaining: Int
    private var nextOccurrence: Date
    private let applications: [ApplicationIdentity]
    private let hosts: [String]
    
    /// - Parameters:
    ///   - start: The first event's time, truncated to whole seconds; each next event is one second later.
    ///   - totalCount: How many events the source emits before it is exhausted.
    /// - Throws: The first catalog entry that an event could not carry.
    public init(
        seed: UInt64,
        start: Date,
        totalCount: Int,
        applications: [ApplicationIdentity] = defaultApplications,
        hosts: [String] = defaultHosts
    ) throws(SchemaViolation) {
        let probeTime = Date(timeIntervalSince1970: 0)
        for host in hosts {
            try Self.event(id: UUID(), at: probeTime, application: nil, host: host, port: 443, transport: .tcp, isDenied: false).validate()
        }
        for application in applications {
            try Self.event(id: UUID(), at: probeTime, application: application, host: "example.com", port: 443, transport: .tcp, isDenied: false).validate()
        }
        generator = SeededGenerator(seed: seed)
        remaining = max(0, totalCount)
        nextOccurrence = Date(timeIntervalSince1970: start.timeIntervalSince1970.rounded(.down))
        self.applications = applications
        self.hosts = hosts
    }
    
    public func nextBatch(maximumCount: Int) -> [SecurityEvent] {
        let count = min(remaining, max(0, min(maximumCount, SchemaLimits.maximumBatchSize)))
        remaining -= count
        return (0..<count).map { _ in makeEvent() }
    }
    
    private func makeEvent() -> SecurityEvent {
        let isDenied = generator.nextBool()
        let identifier = generator.nextUUID()
        let application = applications.isEmpty ? nil : applications[generator.next(below: applications.count)]
        let host = hosts.isEmpty ? "example.com" : hosts[generator.next(below: hosts.count)]
        let port = [53, 80, 443][generator.next(below: 3)]
        let transport: TransportProtocol = generator.nextBool() ? .tcp : .udp
        let event = Self.event(id: identifier, at: nextOccurrence, application: application, host: host, port: port, transport: transport, isDenied: isDenied)
        nextOccurrence.addTimeInterval(1)
        return event
    }
    
    private static func event(
        id: UUID,
        at time: Date,
        application: ApplicationIdentity?,
        host: String,
        port: Int,
        transport: TransportProtocol,
        isDenied: Bool
    ) -> SecurityEvent {
        SecurityEvent(
            identifier: id,
            occurredAt: time,
            provenance: .synthetic,
            kind: .flowDecision,
            application: application,
            flow: FlowSummary(remoteHost: host, remotePort: port, transport: transport, action: isDenied ? .deny : .allow, ruleIdentifier: isDenied ? "synthetic-deny" : nil),
            policy: nil
        )
    }
}
