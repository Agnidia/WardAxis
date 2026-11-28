//
//  TransportMatchingTests.swift
//
//  Created on 28.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisCore
import WardAxisCoreSynthetic
import WardAxisPolicy
import WardAxisPolicyTestSupport

private func port(_ value: UInt16) -> Observed<FlowPort?> {
    .known(FlowPort(value))
}

private func ports(_ ranges: [(Int, Int)]) -> [PortRange] {
    ranges.map { PortRange(first: $0.0, last: $0.1) }
}

private func rule(
    _ action: PolicyAction,
    transport: TransportProtocol? = nil,
    ports ranges: [(Int, Int)]? = nil,
    enabled: Bool = true
) -> PolicyRule {
    .fixture(action, match: PolicyMatch(transport: transport, destinationPorts: ranges.map(ports)), enabled: enabled)
}

@Suite("Transport protocol and port matching")
struct TransportMatchingTests {
    // MARK: - Acceptance

    @Test
    func `A UDP 53 rule does not match a TCP 53 flow`() {
        let match = PolicyMatch(transport: .udp, destinationPorts: ports([(53, 53)]))
        #expect(match.evaluateTransport(.known(.tcp)) == .noMatch)
        #expect(match.evaluatePort(port(53)) == .match)
        for action in [PolicyAction.deny, .allow] {
            #expect(!rule(action, transport: .udp, ports: [(53, 53)]).transportApplies(to: .known(.tcp), port: port(53)))
            #expect(rule(action, transport: .udp, ports: [(53, 53)]).transportApplies(to: .known(.udp), port: port(53)))
        }
    }

    // MARK: - Boundaries

    @Test(arguments: [(1, 1), (53, 53), (1024, 49_151), (65_535, 65_535), (1, 65_535), (443, 444)])
    func `A range contains its first and last port and nothing next to them`(first: Int, last: Int) {
        let match = PolicyMatch(destinationPorts: ports([(first, last)]))
        #expect(match.evaluatePort(port(UInt16(first))) == .match)
        #expect(match.evaluatePort(port(UInt16(last))) == .match)
        if first > 0 {
            #expect(match.evaluatePort(port(UInt16(first - 1))) == .noMatch)
        }
        if last < Int(UInt16.max) {
            #expect(match.evaluatePort(port(UInt16(last + 1))) == .noMatch)
        }
    }

    @Test
    func `Port 0 never matches a valid range`() {
        #expect(PolicyMatch(destinationPorts: ports([(1, 65_535)])).evaluatePort(port(0)) == .noMatch)
    }

    @Test
    func `One matching range of the list is enough`() {
        let match = PolicyMatch(destinationPorts: ports([(80, 80), (443, 443), (8000, 8999)]))
        #expect(match.evaluatePort(port(443)) == .match)
        #expect(match.evaluatePort(port(8500)) == .match)
        #expect(match.evaluatePort(port(444)) == .noMatch)
    }

    // MARK: - Criteria

    @Test
    func `A ports-only rule matches TCP and UDP alike`() {
        for transport in [TransportProtocol.tcp, .udp] {
            #expect(rule(.deny, ports: [(53, 53)]).transportApplies(to: .known(transport), port: port(53)))
            #expect(!rule(.deny, ports: [(53, 53)]).transportApplies(to: .known(transport), port: port(54)))
        }
    }

    @Test
    func `A transport-only rule matches every port of that transport`() {
        for value: UInt16 in [0, 1, 53, 65_535] {
            #expect(rule(.deny, transport: .udp).transportApplies(to: .known(.udp), port: port(value)))
            #expect(!rule(.deny, transport: .udp).transportApplies(to: .known(.tcp), port: port(value)))
        }
        #expect(rule(.deny, transport: .udp).transportApplies(to: .known(.udp), port: .known(nil)))
    }

    @Test
    func `A rule without either criterion matches every flow`() {
        let match = PolicyMatch(destinationHosts: ["example.test"])
        for transport: Observed<TransportProtocol?> in [.known(.tcp), .known(nil), .unknown] {
            #expect(match.evaluateTransport(transport) == .match)
        }
        for observed in [port(53), .known(nil), .unknown] {
            #expect(match.evaluatePort(observed) == .match)
        }
    }

    // MARK: - Absent and unknown fields

    @Test
    func `A flow that is neither TCP nor UDP, or has no port, is no match`() {
        #expect(PolicyMatch(transport: .udp).evaluateTransport(.known(nil)) == .noMatch)
        #expect(PolicyMatch(destinationPorts: ports([(1, 65_535)])).evaluatePort(.known(nil)) == .noMatch)
        for action in [PolicyAction.deny, .allow] {
            #expect(!rule(action, transport: .udp).transportApplies(to: .known(nil), port: .known(nil)))
            #expect(!rule(action, ports: [(1, 65_535)]).transportApplies(to: .known(nil), port: .known(nil)))
        }
    }

    @Test
    func `An unknown transport or port applies a deny rule and never an allow rule`() {
        #expect(PolicyMatch(transport: .tcp).evaluateTransport(.unknown) == .unknown)
        #expect(PolicyMatch(destinationPorts: ports([(443, 443)])).evaluatePort(.unknown) == .unknown)
        #expect(rule(.deny, transport: .udp, ports: [(443, 443)]).transportApplies(to: .unknown, port: port(443)))
        #expect(!rule(.allow, transport: .tcp, ports: [(443, 443)]).transportApplies(to: .unknown, port: port(443)))
        #expect(rule(.deny, transport: .tcp, ports: [(443, 443)]).transportApplies(to: .known(.tcp), port: .unknown))
        #expect(!rule(.allow, transport: .tcp, ports: [(443, 443)]).transportApplies(to: .known(.tcp), port: .unknown))
    }

    @Test
    func `A known contradiction decides over an unknown field`() {
        for action in [PolicyAction.deny, .allow] {
            // Transport contradicts; the unknown port must not let a deny apply.
            #expect(!rule(action, transport: .udp, ports: [(53, 53)]).transportApplies(to: .known(.tcp), port: .unknown))
            // Port contradicts; the unknown transport must not let a deny apply.
            #expect(!rule(action, transport: .udp, ports: [(53, 53)]).transportApplies(to: .unknown, port: port(54)))
        }
        #expect(rule(.deny, transport: .udp, ports: [(53, 53)]).transportApplies(to: .unknown, port: .unknown))
        #expect(!rule(.allow, transport: .udp, ports: [(53, 53)]).transportApplies(to: .unknown, port: .unknown))
    }

    @Test
    func `A disabled rule never applies`() {
        for action in [PolicyAction.deny, .allow] {
            let disabled = rule(action, transport: .udp, ports: [(53, 53)], enabled: false)
            #expect(!disabled.transportApplies(to: .known(.udp), port: port(53)))
            #expect(!disabled.transportApplies(to: .unknown, port: .unknown))
        }
    }

    // MARK: - Ranges that bypassed validation

    @Test(arguments: [(5, 1), (0, 70_000), (-1, 53), (0, 0), (65_536, 65_536), (Int.min, Int.max)])
    func `A range that bypassed validation fails closed by action`(first: Int, last: Int) {
        let match = PolicyMatch(destinationPorts: ports([(first, last)]))
        for value: UInt16 in [0, 1, 3, 53, 65_535] {
            #expect(match.evaluatePort(port(value)) == .unknown)
            #expect(rule(.deny, ports: [(first, last)]).transportApplies(to: .known(.tcp), port: port(value)))
            #expect(!rule(.allow, ports: [(first, last)]).transportApplies(to: .known(.tcp), port: port(value)))
        }
    }

    @Test
    func `A valid range that matches still decides next to one that bypassed validation`() {
        let match = PolicyMatch(destinationPorts: ports([(0, 70_000), (443, 443)]))
        #expect(match.evaluatePort(port(443)) == .match)
        #expect(match.evaluatePort(port(80)) == .unknown)
        #expect(rule(.allow, ports: [(0, 70_000), (443, 443)]).transportApplies(to: .known(.tcp), port: port(443)))
    }

    @Test
    func `A decoded policy matches like one built in code`() throws {
        let json = #"{"transport":"udp","destinationPorts":[{"first":53,"last":53},{"first":5353,"last":5353}]}"#
        let decoded = try JSONDecoder().decode(PolicyMatch.self, from: Data(json.utf8))
        #expect(decoded.evaluateTransport(.known(.tcp)) == .noMatch)
        #expect(decoded.evaluateTransport(.known(.udp)) == .match)
        #expect(decoded.evaluatePort(port(5353)) == .match)
        #expect(decoded.evaluatePort(port(5354)) == .noMatch)
    }

    // MARK: - Reported ports

    @Test(arguments: [("0", 0), ("1", 1), ("53", 53), ("443", 443), ("65535", 65_535)])
    func `A canonical decimal port parses`(reported: String, value: UInt16) {
        #expect(FlowPort(reported: reported) == FlowPort(value))
        #expect(FlowPort.observed(reported: reported) == .known(FlowPort(value)))
    }

    @Test(arguments: [
        "", "+53", "-1", "053", "00", " 53", "53 ", "5 3", "65536", "99999", "100000", "0x35", "5.3",
        "\u{0665}\u{0663}", "\u{FF15}\u{FF13}", "53\u{0}", "https"
    ])
    func `Anything that is not one canonical port is unknown`(reported: String) {
        #expect(FlowPort(reported: reported) == nil)
        #expect(FlowPort.observed(reported: reported) == .unknown)
    }

    @Test(arguments: [6, 64, 1 << 20])
    func `Input above the bound is unknown before any parse`(length: Int) {
        #expect(FlowPort.observed(reported: String(repeating: "1", count: length)) == .unknown)
    }

    // MARK: - Properties

    private static let seeds: [UInt64] = [1, 0x5EED, 0xDEADBEEF, 0x0123456789ABCDEF]
    private static let caseCount = 500

    @Test(arguments: seeds)
    func `Range containment equals the closed-range reference`(seed: UInt64) {
        var random = SeededGenerator(seed: seed)
        for index in 0..<Self.caseCount {
            let first = Int.random(in: 1...65_535, using: &random)
            let last = Int.random(in: first...65_535, using: &random)
            let value = UInt16.random(in: 0...UInt16.max, using: &random)
            let expected: MatchResult = (first...last).contains(Int(value)) ? .match : .noMatch
            let match = PolicyMatch(destinationPorts: ports([(first, last)]))
            #expect(match.evaluatePort(port(value)) == expected, "seed \(seed), case \(index), \(first)...\(last), \(value)")
        }
    }

    @Test(arguments: seeds)
    func `Every port parses back from its decimal text`(seed: UInt64) {
        var random = SeededGenerator(seed: seed)
        for index in 0..<Self.caseCount {
            let value = UInt16.random(in: 0...UInt16.max, using: &random)
            #expect(FlowPort(reported: String(value)) == FlowPort(value), "seed \(seed), case \(index)")
            #expect(FlowPort(reported: "0" + String(value)) == nil, "seed \(seed), case \(index)")
        }
    }
}
