//
//  NetworkMatching.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisCore

/// The remote address of one flow. Holds the address bits only, so two
/// spellings of one address are equal. An IPv4-mapped address (`::ffff:0:0/96`)
/// is IPv4, the family it reaches on the wire (ADR 0018 D1).
public struct FlowAddress: Sendable, Hashable {
    public enum Value: Sendable, Hashable {
        case ipv4(UInt32)
        case ipv6(UInt128)
    }

    public let value: Value

    public init(ipv4: UInt32) {
        value = .ipv4(ipv4)
    }

    public init(ipv6: UInt128) {
        value = Self.normalized(ipv6)
    }

    /// Network byte order, as in `in_addr` and `in6_addr`. `nil` unless 4 or 16 bytes.
    public init?(bytes: some Collection<UInt8>) {
        switch bytes.count {
        case 4: value = .ipv4(bigEndian(bytes))
        case 16: value = Self.normalized(bigEndian(bytes))
        default: return nil
        }
    }

    /// Parses an address as a provider reported it; see ``observed(reported:)``.
    public init?(reported: String) {
        guard let value = Self.parse(reported) else {
            return nil
        }
        self.value = value
    }

    /// The observed address of a flow whose provider reported one as text.
    /// Anything that is not an unambiguous address, a host name included, is
    /// `unknown`, so it never escapes a deny (ADR 0018 D3, N4). A provider
    /// passes a reported host to ``FlowHost/observed(reportedName:)`` first and
    /// reports `.known(nil)` here when the flow has no address yet.
    public static func observed(reported: String) -> Observed<FlowAddress?> {
        FlowAddress(reported: reported).map { .known($0) } ?? .unknown
    }

    /// The IPv4 address embedded in a NAT64 well-known-prefix address
    /// (`64:ff9b::/96`, RFC 6052). Whether the network translates it is not
    /// known here (ADR 0018 D2).
    var nat64EmbeddedIPv4: UInt32? {
        guard case .ipv6(let bits) = value, bits >> 32 == Self.nat64WellKnownPrefix else {
            return nil
        }
        return UInt32(truncatingIfNeeded: bits)
    }

    // MARK: - Private

    private static let ipv4MappedPrefix: UInt128 = 0xFFFF
    private static let nat64WellKnownPrefix: UInt128 = 0x0064FF9B << 64

    private static func normalized(_ bits: UInt128) -> Value {
        bits >> 32 == ipv4MappedPrefix ? .ipv4(UInt32(truncatingIfNeeded: bits)) : .ipv6(bits)
    }
    
    private static func parse(_ reported: String) -> Value? {
        // Bound before any parse (ADR 0018 N5).
        guard reported.utf8.count <= PolicyLimits.maximumReportedAddressLength else {
            return nil
        }
        if FieldRules.isCanonicalIPv4(reported) {
            return .ipv4(ipv4Bits(reported))
        }
        var text = Substring(reported)
        let isBracketed = text.hasPrefix("[")
        if isBracketed {
            guard text.hasSuffix("]") else {
                return nil
            }
            text = text.dropFirst().dropLast()
        }
        if let percent = text.firstIndex(of: "%") {
            var zone = text[text.index(after: percent)...]
            // In a URI the delimiter is percent-encoded, `%25` (RFC 6874); no interface name starts with digits.
            if isBracketed, zone.hasPrefix("25"), zone.count > 2 {
                zone = zone.dropFirst(2)
            }
            // The zone picks an interface, not an address; a rule cannot name one.
            guard isZone(zone) else {
                return nil
            }
            text = text[..<percent]
        }
        // ASCII only: a Unicode case map must not be what makes untrusted text parse.
        return ipv6Bits(ASCII.lowercased(text)).map(normalized)
    }

    private static func ipv4Bits(_ canonical: some StringProtocol) -> UInt32 {
        canonical.split(separator: ".").compactMap { UInt32($0) }.reduce(0) { $0 << 8 | $1 }
    }

    private static func isZone(_ zone: Substring) -> Bool {
        (1...PolicyLimits.maximumZoneLength).contains(zone.utf8.count) && zone.utf8.allSatisfy { byte in
            ASCII.lowercaseLetters.contains(byte) || ASCII.uppercaseLetters.contains(byte) || ASCII.digits.contains(byte)
                || byte == UInt8(ascii: ".") || byte == UInt8(ascii: "_") || byte == UInt8(ascii: "-")
        }
    }

    /// Any RFC 4291 §2.2 text form. A dotted IPv4 tail must be canonical, as
    /// a bare IPv4 address must, so `::ffff:010.0.0.1` cannot read as octal.
    private static func ipv6Bits(_ text: String) -> UInt128? {
        let halves = text.components(separatedBy: "::")
        guard halves.count <= 2 else {
            return nil
        }
        func parse(_ part: String, allowsIPv4Tail: Bool) -> [UInt16]? {
            guard !part.isEmpty else {
                return []
            }
            let fields = part.split(separator: ":", omittingEmptySubsequences: false)
            var groups: [UInt16] = []
            for (index, field) in fields.enumerated() {
                if field.contains(".") {
                    guard allowsIPv4Tail, index == fields.count - 1, FieldRules.isCanonicalIPv4(String(field)) else {
                        return nil
                    }
                    let bits = ipv4Bits(field)
                    groups += [UInt16(bits >> 16), UInt16(bits & 0xFFFF)]
                } else {
                    // `UInt16(_:radix:)` alone also takes a sign, so `+f` would parse.
                    guard (1...4).contains(field.utf8.count), field.utf8.allSatisfy(ASCII.isLowercaseHexDigit), let group = UInt16(field, radix: 16) else {
                        return nil
                    }
                    groups.append(group)
                }
            }
            return groups
        }
        let groups: [UInt16]
        if halves.count == 1 {
            guard let all = parse(halves[0], allowsIPv4Tail: true), all.count == 8 else {
                return nil
            }
            groups = all
        } else {
            guard let head = parse(halves[0], allowsIPv4Tail: false),
                  let tail = parse(halves[1], allowsIPv4Tail: true),
                  head.count + tail.count <= 7
            else {
                return nil
            }
            groups = head + Array(repeating: 0, count: 8 - head.count - tail.count) + tail
        }
        return groups.reduce(0) { $0 << 16 | UInt128($1) }
    }
}

/// A canonical policy network (``WardAxisCore/FieldRules/isCanonicalNetwork(_:)``)
/// in matching form.
public struct IPNetwork: Sendable, Hashable {
    private enum Base: Sendable, Hashable {
        case ipv4(UInt32, mask: UInt32)
        case ipv6(UInt128, mask: UInt128)
    }

    private let base: Base

    /// `nil` for a string that validation refuses (ADR 0018 N6).
    public init?(_ cidr: String) {
        guard let (bytes, prefixLength) = FieldRules.canonicalNetwork(cidr) else {
            return nil
        }
        // A shift by the full width is not zero in every language; `/0` is spelled out (N1).
        if bytes.count == 4 {
            let mask: UInt32 = prefixLength == 0 ? 0 : .max << (32 - prefixLength)
            base = .ipv4(bigEndian(bytes), mask: mask)
        } else {
            let mask: UInt128 = prefixLength == 0 ? 0 : .max << (128 - prefixLength)
            base = .ipv6(bigEndian(bytes), mask: mask)
        }
    }
    
    /// An IPv4 network against a NAT64 well-known-prefix address is `unknown`:
    /// the flow reaches the embedded IPv4 host only where the network translates
    /// it, so a deny applies and an allow does not. An IPv6 network compares
    /// all 128 bits and never covers IPv4, so `::/0` is IPv6 only (ADR 0018 D2).
    public func evaluate(_ address: FlowAddress) -> MatchResult {
        switch (base, address.value) {
        case (.ipv4(let network, let mask), .ipv4(let bits)):
            return bits & mask == network ? .match : .noMatch
        case (.ipv4(let network, let mask), .ipv6):
            guard let bits = address.nat64EmbeddedIPv4, bits & mask == network else {
                return .noMatch
            }
            return .unknown
        case (.ipv6(let network, let mask), .ipv6(let bits)):
            return bits & mask == network ? .match : .noMatch
        case (.ipv6, .ipv4):
            return .noMatch
        }
    }
}

public extension PolicyMatch {
    /// The network criterion against one flow. A rule without the criterion matches.
    ///
    /// | Flow address | Result |
    /// |---|---|
    /// | Known, a network contains it | `match` |
    /// | Known, only a NAT64 translation or a pattern that bypassed validation could match | `unknown` |
    /// | Known, no network contains it | `noMatch` |
    /// | `.known(nil)`: the flow has no address at this layer | `noMatch`; host rules apply instead |
    /// | `unknown` | `unknown` |
    func evaluateNetwork(_ address: Observed<FlowAddress?>) -> MatchResult {
        guard let compiledNetworks else {
            return .match
        }
        return address.evaluate { address in
            var result = MatchResult.noMatch
            for network in compiledNetworks {
                // An entry that bypassed validation could narrow a deny, so it fails closed by action (N6).
                switch network?.evaluate(address) ?? .unknown {
                case .match: return .match
                case .unknown: result = .unknown
                case .noMatch: break
                }
            }
            return result
        }
    }
}

public extension PolicyRule {
    /// Whether the network criterion lets this rule apply to a flow. An unknown
    /// address fails closed by action (ADR 0016 D3): a `deny` rule applies and
    /// an `allow` rule does not. A disabled rule never applies.
    func networkApplies(to address: Observed<FlowAddress?>) -> Bool {
        applies(match.evaluateNetwork(address))
    }
}

/// Address bytes in network byte order as one integer. Callers pass exactly
/// `T.bitWidth / 8` bytes; a longer run would shift the high bytes out.
private func bigEndian<T: FixedWidthInteger & UnsignedInteger>(_ bytes: some Collection<UInt8>) -> T {
    bytes.reduce(0) { $0 << 8 | T($1) }
}
