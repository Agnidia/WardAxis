//
//  FieldRules.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Lexical rules shared by the schemas. Each accepts ASCII only, so two
/// strings that look the same always compare the same.
public enum FieldRules {
    /// A policy or rule identifier: 1–128 of `A–Z a–z 0–9 . _ -`, starting alphanumeric.
    public static func isIdentifier(_ value: String) -> Bool {
        isToken(value, maximumLength: SchemaLimits.maximumIdentifierLength)
    }
    
    /// A code-signing or bundle identifier: 1–255 of `A–Z a–z 0–9 . _ -`, starting alphanumeric.
    static func isSigningIdentifier(_ value: String) -> Bool {
        isToken(value, maximumLength: SchemaLimits.maximumSigningIdentifierLength)
    }
    
    /// An Apple Developer Team ID: exactly ten of `A–Z 0–9`.
    static func isTeamIdentifier(_ value: String) -> Bool {
        value.utf8.count == SchemaLimits.teamIdentifierLength && value.utf8.allSatisfy { isUpperAlphanumeric($0) }
    }
    
    /// A canonical host name: lowercase LDH labels of 1–63 bytes, 253 bytes in
    /// all, no trailing dot. Internationalized names must arrive as punycode.
    /// Lowercase only, so a matcher never has to case-fold untrusted input.
    public static func isHostName(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard (1...SchemaLimits.maximumHostNameLength).contains(bytes.count) else {
            return false
        }
        let labels = bytes.split(separator: UInt8(ascii: "."), omittingEmptySubsequences: false)
        // An all-numeric last label reads as an IP address (`999.0.0.1`, `127.1`), never a name (RFC 3696 §2).
        guard let last = labels.last, !last.allSatisfy(ASCII.digits.contains), !isNumericAddress(labels) else {
            return false
        }
        return labels.allSatisfy { label in
            guard (1...SchemaLimits.maximumHostLabelLength).contains(label.count),
                  label.first != UInt8(ascii: "-"),
                  label.last != UInt8(ascii: "-")
            else {
                return false
            }
            return label.allSatisfy { isLowerAlphanumeric($0) || $0 == UInt8(ascii: "-") }
        }
    }
    
    /// A host name, or `*.` and a host name of at least two labels for any subdomain of it.
    /// The rule does not consult a public-suffix list, so `*.co.uk` passes (ADR 0011 D3).
    public static func isHostPattern(_ value: String) -> Bool {
        guard value.hasPrefix("*.") else {
            return isHostName(value)
        }
        let suffix = value.dropFirst(2)
        // `*.com` would match a whole top-level domain.
        return suffix.contains(".") && isHostName(String(suffix))
    }
    
    /// A host name or an IPv4 or IPv6 literal, as a flow reports its remote end.
    static func isRemoteHost(_ value: String) -> Bool {
        isHostName(value) || isCanonicalIPv4(value) || isCanonicalIPv6(value)
    }
    
    /// Four decimal octets with no leading zero. Refuses the short, octal and
    /// hex forms (`127.1`, `010.0.0.1`, `0x7f.0.0.1`) that system parsers accept,
    /// so one address has one spelling.
    public static func isCanonicalIPv4(_ value: String) -> Bool {
        let octets = value.utf8.split(separator: UInt8(ascii: "."), omittingEmptySubsequences: false)
        return octets.count == 4 && octets.allSatisfy { octet in
            guard (1...3).contains(octet.count),
                  octet.allSatisfy(ASCII.digits.contains),
                  octet.count == 1 || octet.first != UInt8(ascii: "0"),
                  let number = Int(String(decoding: octet, as: UTF8.self))
            else {
                return false
            }
            return number <= 255
        }
    }
    
    /// The RFC 5952 text form only: lowercase, no leading zeros, the longest run
    /// of two or more zero groups shortened to `::`. Refuses a zone (`%en0`),
    /// whose meaning depends on the device, and an embedded IPv4 tail.
    public static func isCanonicalIPv6(_ value: String) -> Bool {
        guard let groups = ipv6Groups(value) else {
            return false
        }
        return canonicalIPv6(groups) == value
    }
    
    public static func isPort(_ value: Int) -> Bool {
        SchemaLimits.validPorts.contains(value)
    }
    
    /// A network in CIDR form: a canonical IPv4 (``isCanonicalIPv4(_:)``) or IPv6
    /// (``isCanonicalIPv6(_:)``) address, `/`, and a decimal prefix length with no
    /// leading zero (0–32 or 0–128). Every bit after the prefix must be zero, so
    /// `192.0.2.1/24` is refused and one network has one spelling.
    public static func isCanonicalNetwork(_ value: String) -> Bool {
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              (1...3).contains(parts[1].utf8.count),
              parts[1].utf8.allSatisfy(ASCII.digits.contains),
              parts[1].utf8.count == 1 || parts[1].utf8.first != UInt8(ascii: "0"),
              let prefix = Int(parts[1])
        else {
            return false
        }
        let address = String(parts[0])
        if isCanonicalIPv4(address) {
            let octets = address.split(separator: ".").compactMap { UInt8($0) }
            return prefix <= 32 && hostBitsAreZero(octets, prefix: prefix)
        }
        guard isCanonicalIPv6(address), let groups = ipv6Groups(address) else {
            return false
        }
        let bytes = groups.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
        return prefix <= 128 && hostBitsAreZero(bytes, prefix: prefix)
    }
    
    // MARK: - Private
    
    private static func hostBitsAreZero(_ bytes: [UInt8], prefix: Int) -> Bool {
        for (index, byte) in bytes.enumerated() {
            let networkBits = min(max(prefix - index * 8, 0), 8)
            let hostMask: UInt8 = networkBits == 8 ? 0 : UInt8(0xFF) >> networkBits
            if byte & hostMask != 0 {
                return false
            }
        }
        return true
    }
    
    private static func isNumericAddress(_ labels: [ArraySlice<UInt8>]) -> Bool {
        guard (1...4).contains(labels.count) else { return false }
        return labels.allSatisfy { label in
            if label.starts(with: [UInt8(ascii: "0"), UInt8(ascii: "x")]) {
                let digits = label.dropFirst(2)
                return !digits.isEmpty && digits.allSatisfy { ASCII.digits.contains($0) || ASCII.lowercaseHexLetters.contains($0) }
            }
            return !label.isEmpty && label.allSatisfy(ASCII.digits.contains)
        }
    }
    
    private static func ipv6Groups(_ value: String) -> [UInt16]? {
        let bytes = Array(value.utf8)
        guard bytes.count <= 39, bytes.allSatisfy({ ASCII.digits.contains($0) || ASCII.lowercaseHexLetters.contains($0) || $0 == UInt8(ascii: ":") }) else {
            return nil
        }
        let halves = value.components(separatedBy: "::")
        guard halves.count <= 2 else {
            return nil
        }
        func parse(_ part: String) -> [UInt16]? {
            guard !part.isEmpty else {
                return []
            }
            var groups: [UInt16] = []
            for group in part.split(separator: ":", omittingEmptySubsequences: false) {
                guard (1...4).contains(group.count), let number = UInt16(group, radix: 16) else {
                    return nil
                }
                groups.append(number)
            }
            return groups
        }
        guard let head = parse(halves[0]) else {
            return nil
        }
        if halves.count == 1 {
            return head.count == 8 ? head : nil
        }
        guard let tail = parse(halves[1]), head.count + tail.count < 8 else {
            return nil
        }
        return head + Array(repeating: 0, count: 8 - head.count - tail.count) + tail
    }
    
    private static func canonicalIPv6(_ groups: [UInt16]) -> String {
        var bestStart = -1
        var bestLength = 1
        var index = 0
        while index < groups.count {
            guard groups[index] == 0 else {
                index += 1
                continue
            }
            let start = index
            while index < groups.count, groups[index] == 0 {
                index += 1
            }
            if index - start > bestLength {
                bestStart = start
                bestLength = index - start
            }
        }
        let text = groups.map { String($0, radix: 16) }
        guard bestStart >= 0 else {
            return text.joined(separator: ":")
        }
        let head = text[..<bestStart].joined(separator: ":")
        let tail = text[(bestStart + bestLength)...].joined(separator: ":")
        return head + "::" + tail
    }
    
    private static func isToken(_ value: String, maximumLength: Int) -> Bool {
        let bytes = value.utf8
        guard let first = bytes.first, bytes.count <= maximumLength, isAlphanumeric(first) else {
            return false
        }
        return bytes.allSatisfy { isAlphanumeric($0) || $0 == UInt8(ascii: ".") || $0 == UInt8(ascii: "_") || $0 == UInt8(ascii: "-") }
    }
    
    private static func isAlphanumeric(_ byte: UInt8) -> Bool {
        isLowerAlphanumeric(byte) || isUpperAlphanumeric(byte)
    }
    
    private static func isLowerAlphanumeric(_ byte: UInt8) -> Bool {
        ASCII.lowercaseLetters.contains(byte) || ASCII.digits.contains(byte)
    }
    
    private static func isUpperAlphanumeric(_ byte: UInt8) -> Bool {
        ASCII.uppercaseLetters.contains(byte) || ASCII.digits.contains(byte)
    }
}
