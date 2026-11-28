//
//  TransportMatching.swift
//
//  Created on 28.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisCore

/// The remote port of one flow. `UInt16` holds every port and nothing else,
/// so a provider value can never be out of range (ADR 0020 D1).
public struct FlowPort: Sendable, Hashable {
    public let value: UInt16

    public init(_ value: UInt16) {
        self.value = value
    }

    /// Canonical decimal only: ASCII digits, no sign, no space, no leading zero
    /// except `"0"`. A component that reads `053` as octal or skips a leading
    /// `+` must never see a different port than the policy does (ADR 0020 P4).
    public init?(reported: String) {
        let digits = reported.utf8
        // Bound before any parse (ADR 0020 P4).
        guard (1...PolicyLimits.maximumReportedPortLength).contains(digits.count),
              digits.allSatisfy(ASCII.digits.contains),
              digits.count == 1 || digits.first != UInt8(ascii: "0"),
              let value = UInt16(reported)
        else {
            return nil
        }
        self.value = value
    }

    /// The observed port of a flow whose provider reported one as text. Text
    /// that is not one canonical port is `unknown`, so it never escapes a deny.
    /// A provider reports `.known(nil)` for a flow that has no port, such as ICMP.
    public static func observed(reported: String) -> Observed<FlowPort?> {
        FlowPort(reported: reported).map { .known($0) } ?? .unknown
    }
}

extension PortRange {
    /// Inclusive at both ends (ADR 0020 P1). Callers check ``isValid`` first:
    /// a range that bypassed validation could hold any `Int`.
    func contains(_ port: FlowPort) -> Bool {
        first <= Int(port.value) && Int(port.value) <= last
    }
}

public extension PolicyMatch {
    /// The transport criterion against one flow. A rule without the criterion matches.
    ///
    /// | Flow transport | Result |
    /// |---|---|
    /// | Known, the rule's transport | `match` |
    /// | Known, the other transport | `noMatch` |
    /// | `.known(nil)`: neither TCP nor UDP, such as ICMP | `noMatch` |
    /// | `unknown`: the provider cannot tell, such as an iOS URL filter | `unknown` |
    func evaluateTransport(_ transport: Observed<TransportProtocol?>) -> MatchResult {
        guard let expected = self.transport else {
            return .match
        }
        return transport.evaluate { $0 == expected ? .match : .noMatch }
    }

    /// The port criterion against one flow. A rule without the criterion matches.
    /// The criterion is independent of ``transport``: a ports-only rule covers
    /// TCP and UDP alike.
    ///
    /// | Flow port | Result |
    /// |---|---|
    /// | Known, a valid range contains it | `match` |
    /// | Known, no valid range contains it, one range bypassed validation | `unknown` |
    /// | Known, no range contains it | `noMatch` |
    /// | `.known(nil)`: the flow has no port, such as ICMP | `noMatch` |
    /// | `unknown` | `unknown` |
    func evaluatePort(_ port: Observed<FlowPort?>) -> MatchResult {
        guard let destinationPorts else {
            return .match
        }
        return port.evaluate { port in
            var result = MatchResult.noMatch
            for range in destinationPorts {
                // An inverted or out-of-range entry could widen an allow or narrow a deny, so it fails closed by action (P3).
                guard range.isValid else {
                    result = .unknown
                    continue
                }
                if range.contains(port) {
                    return .match
                }
            }
            return result
        }
    }
}

public extension PolicyRule {
    /// Whether the transport and port criteria together let this rule apply to
    /// a flow. Both must hold, so `UDP 53` never applies to a TCP flow to port
    /// 53 (ADR 0020 P2). An unknown field fails closed by action (ADR 0016 D3):
    /// a `deny` rule applies and an `allow` rule does not. A disabled rule never applies.
    func transportApplies(to transport: Observed<TransportProtocol?>, port: Observed<FlowPort?>) -> Bool {
        applies(match.evaluateTransport(transport).and(match.evaluatePort(port)))
    }
}
