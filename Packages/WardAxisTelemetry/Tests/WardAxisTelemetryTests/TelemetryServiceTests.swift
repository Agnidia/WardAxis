//
//  TelemetryServiceTests.swift
//
//  Created on 15.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Synchronization
import Testing
@testable import WardAxisTelemetry

@Suite("Telemetry consent")
struct TelemetryServiceTests {
    @Test("Without a consent source every event is dropped")
    func defaultIsOptOut() {
        let sink = RecordingSink()
        let service = TelemetryService(sink: sink.record)
        service.track(.screenViewed("Home"))
        #expect(sink.events.isEmpty)
    }

    @Test("Consented events reach the sink in order")
    func consentedEventsAreForwarded() {
        let sink = RecordingSink()
        let service = TelemetryService(hasConsent: { true }, sink: sink.record)
        service.track(.tabSelected("home"))
        service.track(.actionTapped("refresh"))
        #expect(sink.events == [.tabSelected("home"), .actionTapped("refresh")])
    }

    @Test("Revoking consent stops the next event without rebuilding the service")
    func revocationTakesEffectImmediately() {
        let consent = Mutex(true)
        let sink = RecordingSink()
        let service = TelemetryService(hasConsent: { consent.withLock { $0 } }, sink: sink.record)
        service.track(.screenViewed("A"))
        consent.withLock { $0 = false }
        service.track(.screenViewed("B"))
        #expect(sink.events == [.screenViewed("A")])
    }
}

private final class RecordingSink: Sendable {
    private let storage = Mutex<[TelemetryEvent]>([])

    var events: [TelemetryEvent] {
        storage.withLock { $0 }
    }

    var record: @Sendable (TelemetryEvent) -> Void {
        { event in self.storage.withLock { $0.append(event) } }
    }
}
