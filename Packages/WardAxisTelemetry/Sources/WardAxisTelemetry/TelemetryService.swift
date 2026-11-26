//
//  TelemetryService.swift
//
//  Created on 15.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// A product-usage event. Payloads name UI elements only: never matched content,
/// URLs, hostnames, file names or anything else the user produced or visited.
public enum TelemetryEvent: Sendable, Equatable {
    case screenViewed(String)
    case tabSelected(String)
    case actionTapped(String)
}

public protocol TelemetryServiceProtocol: Sendable {
    /// Records `event` if the user has opted in; otherwise drops it.
    func track(_ event: TelemetryEvent)
}

/// Opt-in usage telemetry (App Review 5.1.1, 5.1.2).
///
/// Consent is read on every event rather than captured at init, so revoking it
/// takes effect for the next event without rebuilding the service. Without a
/// consent source the service drops everything: opt-out is the default.
public final class TelemetryService: TelemetryServiceProtocol {
    private let hasConsent: @Sendable () -> Bool
    private let sink: @Sendable (TelemetryEvent) -> Void
    
    /// - Parameters:
    ///   - hasConsent: Whether the user currently allows telemetry.
    ///   - sink: Receives consented events. The default writes them to the debug log only.
    public init(
        hasConsent: @escaping @Sendable () -> Bool = { false },
        sink: (@Sendable (TelemetryEvent) -> Void)? = nil
    ) {
        self.hasConsent = hasConsent
        self.sink = sink ?? { event in
            Log(category: .application).debug("Telemetry event: \(String(describing: event))")
        }
    }
    
    public func track(_ event: TelemetryEvent) {
        guard hasConsent() else { return }
        sink(event)
    }
}
