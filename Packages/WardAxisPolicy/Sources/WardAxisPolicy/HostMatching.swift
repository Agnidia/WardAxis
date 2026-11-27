//
//  HostMatching.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisCore

/// The host name of one flow in the canonical form of a policy host name
/// (``WardAxisCore/FieldRules/isHostName(_:)``): ASCII, lowercase, punycode
/// labels, no trailing dot. ASCII only, so `==` is byte equality (ADR 0017 D1).
public struct FlowHost: Sendable, Hashable {
    public let name: String
    
    /// Normalizes a host name as a provider or the network reported it.
    /// `nil` when the name has no canonical form or is an IP literal; see ``observed(reportedName:)``.
    public init?(normalizing reported: String) {
        guard case .name(let name) = Self.canonicalize(reported) else {
            return nil
        }
        self.name = name
    }
    
    /// The observed host of a flow whose provider reported a name (ADR 0017 D3).
    /// An IP literal is `.known(nil)`, so network rules decide it. A name with
    /// no canonical form is `unknown` and never escapes a deny.
    public static func observed(reportedName: String) -> Observed<FlowHost?> {
        switch canonicalize(reportedName) {
        case .name(let name): .known(FlowHost(canonical: name))
        case .address: .known(nil)
        case .malformed: .unknown
        }
    }
    
    /// Whether a policy host pattern (``WardAxisCore/FieldRules/isHostPattern(_:)``)
    /// covers this host, label-aware and byte-exact (ADR 0017 D2).
    /// An unvalidated pattern cannot widen the match: a canonical host has no
    /// uppercase, `*` or trailing dot for it to hit.
    public func matches(_ pattern: String) -> Bool {
        let host = name.utf8
        guard pattern.hasPrefix("*.") else {
            return host.elementsEqual(pattern.utf8)
        }
        // Keep the dot in the suffix, so the match ends on a label boundary.
        let suffix = pattern.utf8.dropFirst()
        return host.count > suffix.count && host.suffix(suffix.count).elementsEqual(suffix)
    }
    
    // MARK: - Private
    
    private enum Canonical {
        case name(String)
        case address
        case malformed
    }
    
    /// Code points that UTS 46 transitional and nontransitional processing map
    /// differently, so the connecting stack may resolve another name (ADR 0017 D1).
    private static let deviations: Set<Unicode.Scalar> = ["\u{00DF}", "\u{03C2}", "\u{200C}", "\u{200D}"]
    
    private init(canonical name: String) {
        self.name = name
    }
    
    private static func canonicalize(_ reported: String) -> Canonical {
        // Bound before any mapping (ADR 0017 H5).
        guard reported.utf8.count <= PolicyLimits.maximumReportedHostLength else {
            return .malformed
        }
        var name: String
        if reported.utf8.allSatisfy({ $0 < 0x80 }) {
            // Folding A–Z only adds no character, so ASCII never depends on Foundation's mapping.
            name = lowercasedASCII(reported)
        } else {
            guard let encoded = idnaEncoded(reported) else {
                return .malformed
            }
            name = encoded
        }
        // One trailing dot is the same fully qualified name; a second stays and is refused.
        if name.utf8.last == UInt8(ascii: ".") {
            name.removeLast()
        }
        if FieldRules.isHostName(name) {
            return hasValidALabels(name) ? .name(name) : .malformed
        }
        // Brackets enclose an IPv6 literal only (RFC 3986 §3.2.2).
        let isBracketed = name.hasPrefix("[") && name.hasSuffix("]")
        if isBracketed ? FieldRules.isCanonicalIPv6(String(name.dropFirst().dropLast())) : FieldRules.isCanonicalIPv4(name) || FieldRules.isCanonicalIPv6(name) {
            return .address
        }
        // Short, octal and hex IPv4 forms land here: a deny still applies to them.
        return .malformed
    }
    
    /// UTS 46 nontransitional mapping to punycode, lowercase. `nil` when Foundation
    /// cannot map the input: it returns that part percent-encoded.
    private static func idnaEncoded(_ value: String) -> String? {
        var components = URLComponents()
        components.host = value
        guard let encoded = components.encodedHost, encoded.utf8.allSatisfy({ $0 < 0x80 && $0 != UInt8(ascii: "%") }) else {
            return nil
        }
        return lowercasedASCII(encoded)
    }
    
    /// Every `xn--` label must decode and map back to the same bytes, the UTS 46
    /// round trip, whichever path produced it. Foundation passes ASCII through
    /// unchecked, so without this `xn--zz` would be a name and `ü.xn--zz` would not.
    private static func hasValidALabels(_ name: String) -> Bool {
        name.split(separator: ".").allSatisfy { label in
            guard label.hasPrefix("xn--") else {
                return true
            }
            guard let decoded = Punycode.decode(label.dropFirst(4)),
                  !decoded.unicodeScalars.contains(where: deviations.contains)
            else {
                return false
            }
            return idnaEncoded(decoded) == String(label)
        }
    }
    
    private static func lowercasedASCII(_ value: String) -> String {
        let uppercase = UInt8(ascii: "A")...UInt8(ascii: "Z")
        return String(decoding: value.utf8.map { uppercase.contains($0) ? $0 | 0x20 : $0 }, as: UTF8.self)
    }
}

/// RFC 3492 decoding, used only to check A-labels. Input is one label of at
/// most 63 bytes, so every arithmetic step is also checked for overflow.
private enum Punycode {
    private static let base = 36
    private static let tMin = 1
    private static let tMax = 26
    private static let skew = 38
    private static let damp = 700
    
    static func decode(_ input: Substring) -> String? {
        let bytes = Array(input.utf8)
        let delimiter = bytes.lastIndex(of: UInt8(ascii: "-"))
        var output: [Unicode.Scalar] = []
        if let delimiter {
            for byte in bytes[..<delimiter] {
                guard byte < 0x80 else {
                    return nil
                }
                output.append(Unicode.Scalar(byte))
            }
        }
        var position = delimiter.map { $0 + 1 } ?? 0
        guard position < bytes.count else {
            // An A-label with no encoded part only restates ASCII; IDNA never emits one.
            return nil
        }
        var codePoint = 0x80
        var index = 0
        var bias = 72
        while position < bytes.count {
            let oldIndex = index
            var weight = 1
            var k = base
            while true {
                guard position < bytes.count, let digit = digitValue(bytes[position]) else {
                    return nil
                }
                position += 1
                let (product, productOverflow) = digit.multipliedReportingOverflow(by: weight)
                let (sum, sumOverflow) = index.addingReportingOverflow(product)
                guard !productOverflow, !sumOverflow else {
                    return nil
                }
                index = sum
                let threshold = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias)
                if digit < threshold {
                    break
                }
                let (nextWeight, weightOverflow) = weight.multipliedReportingOverflow(by: base - threshold)
                guard !weightOverflow else {
                    return nil
                }
                weight = nextWeight
                k += base
            }
            let count = output.count + 1
            bias = adapt(index - oldIndex, count: count, isFirst: oldIndex == 0)
            let (next, overflow) = codePoint.addingReportingOverflow(index / count)
            guard !overflow, let scalar = Unicode.Scalar(UInt32(clamping: next)), next <= 0x10FFFF else {
                return nil
            }
            codePoint = next
            index %= count
            output.insert(scalar, at: index)
            index += 1
        }
        var result = String.UnicodeScalarView()
        result.append(contentsOf: output)
        return String(result)
    }
    
    private static func digitValue(_ byte: UInt8) -> Int? {
        switch byte {
        case UInt8(ascii: "a")...UInt8(ascii: "z"): Int(byte - UInt8(ascii: "a"))
        case UInt8(ascii: "0")...UInt8(ascii: "9"): Int(byte - UInt8(ascii: "0")) + 26
        default: nil
        }
    }
    
    private static func adapt(_ delta: Int, count: Int, isFirst: Bool) -> Int {
        var delta = isFirst ? delta / damp : delta / 2
        delta += delta / count
        var k = 0
        while delta > ((base - tMin) * tMax) / 2 {
            delta /= base - tMin
            k += base
        }
        return k + (base - tMin + 1) * delta / (delta + skew)
    }
}

public extension PolicyMatch {
    /// The host criterion against one flow. A rule without the criterion matches.
    ///
    /// | Flow host | Result |
    /// |---|---|
    /// | Known, a pattern matches | `match` |
    /// | Known, no pattern matches | `noMatch` |
    /// | `.known(nil)`: the flow has no host name | `noMatch`; network rules apply instead |
    /// | `unknown` | `unknown` |
    func evaluateHost(_ host: Observed<FlowHost?>) -> MatchResult {
        guard let destinationHosts else {
            return .match
        }
        return switch host {
        case .known(.some(let host)):
            destinationHosts.contains(where: host.matches) ? .match : .noMatch
        case .known(nil):
            .noMatch
        case .unknown:
            .unknown
        }
    }
}

public extension PolicyRule {
    /// Whether the host criterion lets this rule apply to a flow. The other
    /// criteria and the resolution order belong to the engine (ADR 0015 D3).
    ///
    /// An unknown or malformed host fails closed by action, as an unknown
    /// identity does (ADR 0016 D3): a `deny` rule applies and an `allow` rule
    /// does not. A disabled rule never applies.
    func hostApplies(to host: Observed<FlowHost?>) -> Bool {
        guard enabled else {
            return false
        }
        
        return switch match.evaluateHost(host) {
        case .match: true
        case .noMatch: false
        case .unknown: action == .deny
        }
    }
}
