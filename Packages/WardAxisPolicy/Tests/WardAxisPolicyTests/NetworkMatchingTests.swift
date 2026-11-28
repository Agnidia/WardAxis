//
//  NetworkMatchingTests.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisCore
import WardAxisCoreSynthetic
import WardAxisPolicy
import WardAxisPolicyTestSupport

private func address(_ text: String) throws -> FlowAddress {
    try #require(FlowAddress(reported: text))
}

private func network(_ cidr: String) throws -> IPNetwork {
    try #require(IPNetwork(cidr))
}

private func rule(_ action: PolicyAction, networks: [String]?, enabled: Bool = true) -> PolicyRule {
    .fixture(action, match: PolicyMatch(destinationNetworks: networks, transport: networks == nil ? .tcp : nil), enabled: enabled)
}

@Suite("CIDR network matching")
struct NetworkMatchingTests {
    // MARK: - Acceptance

    @Test
    func `An IPv6 rule matches an address inside its prefix`() throws {
        let match = PolicyMatch(destinationNetworks: ["2001:db8::/32"])
        #expect(try match.evaluateNetwork(.known(address("2001:db8::1"))) == .match)
        #expect(try rule(.deny, networks: ["2001:db8::/32"]).networkApplies(to: .known(address("2001:db8::1"))))
    }

    // MARK: - Boundaries

    @Test(arguments: [
        ("192.0.2.0/24", "192.0.2.0", "192.0.2.255", "192.0.1.255", "192.0.3.0"),
        ("10.0.0.0/8", "10.0.0.0", "10.255.255.255", "9.255.255.255", "11.0.0.0"),
        ("198.51.100.0/23", "198.51.100.0", "198.51.101.255", "198.51.99.255", "198.51.102.0"),
        ("198.51.100.6/31", "198.51.100.6", "198.51.100.7", "198.51.100.5", "198.51.100.8"),
        ("198.51.100.7/32", "198.51.100.7", "198.51.100.7", "198.51.100.6", "198.51.100.8"),
        ("128.0.0.0/1", "128.0.0.0", "255.255.255.255", "127.255.255.255", "127.255.255.255"),
        ("2001:db8::/32", "2001:db8::", "2001:db8:ffff:ffff:ffff:ffff:ffff:ffff", "2001:db7:ffff:ffff:ffff:ffff:ffff:ffff", "2001:db9::"),
        ("2001:db8::/45", "2001:db8::", "2001:db8:7:ffff:ffff:ffff:ffff:ffff", "2001:db7:ffff:ffff:ffff:ffff:ffff:ffff", "2001:db8:8::"),
        ("2001:db8::/127", "2001:db8::", "2001:db8::1", "2001:db7:ffff:ffff:ffff:ffff:ffff:ffff", "2001:db8::2"),
        ("2001:db8::1/128", "2001:db8::1", "2001:db8::1", "2001:db8::", "2001:db8::2"),
        ("8000::/1", "8000::", "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff", "7fff:ffff:ffff:ffff:ffff:ffff:ffff:ffff", "::")
    ])
    func `A network contains its first and last address and nothing next to them`(
        cidr: String, first: String, last: String, below: String, above: String
    ) throws {
        let network = try network(cidr)
        #expect(try network.contains(address(first)))
        #expect(try network.contains(address(last)))
        #expect(try !network.contains(address(below)))
        #expect(try !network.contains(address(above)))
    }

    @Test(arguments: ["0.0.0.0", "255.255.255.255", "192.0.2.1"])
    func `An IPv4 /0 contains every IPv4 address`(text: String) throws {
        #expect(try network("0.0.0.0/0").contains(address(text)))
    }

    @Test(arguments: ["::", "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff", "2001:db8::1"])
    func `An IPv6 /0 contains every IPv6 address`(text: String) throws {
        #expect(try network("::/0").contains(address(text)))
    }

    // MARK: - Families

    @Test
    func `A rule of one family never matches an address of the other`() throws {
        #expect(try !network("::/0").contains(address("192.0.2.1")))
        #expect(try !network("0.0.0.0/0").contains(address("2001:db8::1")))
        #expect(try !network("::/96").contains(address("192.0.2.1")))
    }
    
    @Test(arguments: ["::ffff:192.0.2.1", "::ffff:c000:201", "[::FFFF:192.0.2.1]", "0:0:0:0:0:ffff:c000:201"])
    func `An IPv4-mapped address is the IPv4 address it reaches`(text: String) throws {
        let flow = try address(text)
        #expect(flow == FlowAddress(ipv4: 0xC0000201))
        #expect(flow.value == .ipv4(0xC0000201))
        #expect(try network("192.0.2.0/24").contains(flow))
        #expect(try network("192.0.2.1/32").contains(flow))
        #expect(try !network("198.51.100.0/24").contains(flow))
    }
    
    @Test
    func `Every source of an IPv4-mapped address gives IPv4`() {
        let mapped: UInt128 = 0xFFFFC0000201
        #expect(FlowAddress(ipv6: mapped) == FlowAddress(ipv4: 0xC0000201))
        #expect(FlowAddress(bytes: Array(repeating: 0, count: 10) + [0xFF, 0xFF, 192, 0, 2, 1]) == FlowAddress(ipv4: 0xC0000201))
    }
    
    @Test
    func `An IPv6 allow-all never covers IPv4 through a dual-stack socket`() throws {
        let allowIPv6 = rule(.allow, networks: ["::/0"])
        #expect(try !allowIPv6.networkApplies(to: .known(address("::ffff:203.0.113.5"))))
        #expect(try !allowIPv6.networkApplies(to: .known(address("203.0.113.5"))))
        #expect(try allowIPv6.networkApplies(to: .known(address("2001:db8::5"))))
    }
    
    @Test(arguments: ["64:ff9b::192.0.2.1", "64:ff9b::c000:201"])
    func `A NAT64 well-known-prefix address is unknown to the IPv4 network it embeds`(text: String) throws {
        let flow = try address(text)
        #expect(try network("192.0.2.0/24").evaluate(flow) == .unknown)
        #expect(try network("198.51.100.0/24").evaluate(flow) == .noMatch)
        #expect(rule(.deny, networks: ["192.0.2.0/24"]).networkApplies(to: .known(flow)))
        #expect(!rule(.allow, networks: ["192.0.2.0/24"]).networkApplies(to: .known(flow)))
    }
    
    @Test
    func `An allow of a private IPv4 network never covers a NAT64 address`() throws {
        #expect(try !rule(.allow, networks: ["10.0.0.0/8"]).networkApplies(to: .known(address("64:ff9b::a00:1"))))
    }
    
    @Test
    func `An IPv6 network compares all 128 bits, so it decides a NAT64 address exactly`() throws {
        #expect(try network("64:ff9b::/96").evaluate(address("64:ff9b::192.0.2.1")) == .match)
        #expect(try network("64:ff9b::c000:200/120").evaluate(address("64:ff9b::192.0.2.1")) == .match)
        #expect(try network("2001:db8::/32").evaluate(address("64:ff9b::192.0.2.1")) == .noMatch)
        let match = PolicyMatch(destinationNetworks: ["192.0.2.0/24", "64:ff9b::/96"])
        #expect(try match.evaluateNetwork(.known(address("64:ff9b::c000:201"))) == .match)
    }
    
    @Test(arguments: ["64:ff9b:1::c000:201", "::c000:201", "::fffe:c000:201", "0:0:0:0:1:ffff:c000:201"])
    func `Other embeddings of an IPv4 address are plain IPv6`(text: String) throws {
        let flow = try address(text)
        #expect(try network("192.0.2.0/24").evaluate(flow) == .noMatch)
    }
    
    @Test(arguments: ["::ffff:0:0/96", "::ffff:c000:200/120", "::ffff:c000:201/128"])
    func `An IPv4-mapped network is refused, so it cannot miss plain IPv4 flows`(cidr: String) {
        #expect(IPNetwork(cidr) == nil)
    }
    
    // MARK: - Reported addresses

    @Test(arguments: [
        ("192.0.2.1", "192.0.2.1"),
        ("2001:DB8::1", "2001:db8::1"),
        ("2001:0db8:0000:0000:0000:0000:0000:0001", "2001:db8::1"),
        ("2001:db8:0:0:0:0:0:1", "2001:db8::1"),
        ("[2001:db8::1]", "2001:db8::1"),
        ("fe80::1%en0", "fe80::1"),
        ("[fe80::1%utun3]", "fe80::1"),
        ("[fe80::1%25en0]", "fe80::1"),
        ("[fe80::1%25]", "fe80::1"),
        ("::ffff:192.0.2.1", "::ffff:c000:201"),
        ("::", "::"),
        ("::1", "::1"),
        ("1::", "1::"),
        ("1:2:3:4:5:6:7::", "1:2:3:4:5:6:7:0"),
        ("::2:3:4:5:6:7:8", "0:2:3:4:5:6:7:8")
    ])
    func `Every spelling of one address parses to the same value`(reported: String, canonical: String) throws {
        #expect(try address(reported) == address(canonical))
        #expect(try FlowAddress.observed(reported: reported) == .known(address(canonical)))
    }

    @Test(arguments: [
        "", " ", "0x7f.0.0.1", "127.1", "010.0.0.1", "192.000.2.1", "1.2.3.4.5", "256.0.0.1", "192.0.2.1 ", " 192.0.2.1",
        "[192.0.2.1]", "192.0.2.1%en0", "::1::", ":::", "1:2:3:4:5:6:7:8:9", "1:2:3:4:5:6:7", "1::2::3", ":1::", "1::2:",
        "12345::", "+f::", "-1::", "g::", "::ffff:010.0.0.1", "::ffff:192.0.2", "192.0.2.1::", "[::1", "::1]", "fe80::1%",
        "fe80::1%en 0", "fe80::1%%en0", "fe80::1%25%en0", "[fe80::1%25%]", "fe80::1%abcdefghijklmnopq", "example.test", "::１", "2001:db8::/32",
        String(repeating: "0", count: 60) + "::1"
    ])
    func `Anything that is not one unambiguous address is unknown`(reported: String) {
        #expect(FlowAddress(reported: reported) == nil)
        #expect(FlowAddress.observed(reported: reported) == .unknown)
    }

    @Test
    func `The longest legitimate spelling fits the input bound`() throws {
        let longest = "[2001:0db8:0000:0000:0000:0000:198.151.100.200%25abcdefghijklmnop]"
        #expect(longest.utf8.count == PolicyLimits.maximumReportedAddressLength)
        #expect(try FlowAddress(reported: longest) == address("2001:db8::c697:64c8"))
        #expect(try FlowAddress(reported: "[2001:0db8:0000:0000:0000:0000:198.151.100.200%abcdefghijklmnop]") == address("2001:db8::c697:64c8"))
    }
    
    @Test(arguments: [PolicyLimits.maximumReportedAddressLength + 1, 4096, 1 << 20])
    func `Input above the bound is unknown before any parse`(length: Int) {
        let oversize = "2001:db8::1" + String(repeating: " ", count: length - 11)
        #expect(oversize.utf8.count == length)
        #expect(FlowAddress.observed(reported: oversize) == .unknown)
    }
    
    @Test
    func `Raw bytes give the same address as text`() throws {
        #expect(try FlowAddress(bytes: [192, 0, 2, 1]) == address("192.0.2.1"))
        #expect(try FlowAddress(bytes: [0x20, 0x01, 0x0D, 0xB8] + Array(repeating: 0, count: 11) + [1]) == address("2001:db8::1"))
        #expect(FlowAddress(ipv4: 0xC0000201) == FlowAddress(bytes: [192, 0, 2, 1]))
    }

    @Test(arguments: [0, 1, 3, 5, 8, 15, 17, 32])
    func `Raw bytes of any other length are refused`(count: Int) {
        #expect(FlowAddress(bytes: Array(repeating: 0, count: count)) == nil)
    }

    // MARK: - Unvalidated patterns

    @Test(arguments: ["192.0.2.1/24", "10.0.0.0/33", "2001:db8::1/32", "2001:DB8::/32", "::/129", "garbage", "", "192.0.2.0", "0.0.0.0/00"])
    func `A pattern that bypassed validation fails closed by action`(pattern: String) throws {
        #expect(IPNetwork(pattern) == nil)
        let match = PolicyMatch(destinationNetworks: [pattern])
        #expect(try match.evaluateNetwork(.known(address("192.0.2.1"))) == .unknown)
        #expect(try match.evaluateNetwork(.known(address("2001:db8::1"))) == .unknown)
        #expect(try rule(.deny, networks: [pattern]).networkApplies(to: .known(address("192.0.2.1"))))
        #expect(try !rule(.allow, networks: [pattern]).networkApplies(to: .known(address("192.0.2.1"))))
    }
    
    @Test
    func `A valid network that matches still decides next to one that bypassed validation`() throws {
        let match = PolicyMatch(destinationNetworks: ["192.0.2.0/24 ", "198.51.100.0/24"])
        #expect(try match.evaluateNetwork(.known(address("198.51.100.1"))) == .match)
        #expect(try match.evaluateNetwork(.known(address("203.0.113.1"))) == .unknown)
    }
    
    @Test
    func `A decoded policy matches like one built in code`() throws {
        let built = PolicyMatch(destinationNetworks: ["192.0.2.0/24"])
        let decoded = try JSONDecoder().decode(PolicyMatch.self, from: Data(#"{"destinationNetworks":["192.0.2.0/24"]}"#.utf8))
        #expect(decoded == built)
        #expect(try decoded.evaluateNetwork(.known(address("192.0.2.1"))) == .match)
        let encoded = try JSONEncoder().encode(decoded)
        #expect(String(decoding: encoded, as: UTF8.self) == #"{"destinationNetworks":["192.0.2.0\/24"]}"#)
    }

    // MARK: - Observed table

    @Test
    func `One matching network of the list is enough`() throws {
        let match = PolicyMatch(destinationNetworks: ["198.51.100.0/24", "2001:db8::/32"])
        #expect(try match.evaluateNetwork(.known(address("2001:db8::5"))) == .match)
        #expect(try match.evaluateNetwork(.known(address("203.0.113.1"))) == .noMatch)
    }

    @Test
    func `A flow without an address is no match and an unknown address is unknown`() {
        let match = PolicyMatch(destinationNetworks: ["192.0.2.0/24"])
        #expect(match.evaluateNetwork(.known(nil)) == .noMatch)
        #expect(match.evaluateNetwork(.unknown) == .unknown)
    }

    @Test
    func `An unknown address applies a deny rule and never an allow rule`() {
        let networks = ["192.0.2.0/24"]
        #expect(rule(.deny, networks: networks).networkApplies(to: .unknown))
        #expect(!rule(.allow, networks: networks).networkApplies(to: .unknown))
        #expect(!rule(.deny, networks: networks).networkApplies(to: .known(nil)))
        #expect(!rule(.allow, networks: networks).networkApplies(to: .known(nil)))
    }

    @Test
    func `A known address applies a rule by containment, whatever the action`() throws {
        let inside = try address("192.0.2.9")
        let outside = try address("198.51.100.9")
        for action in [PolicyAction.deny, .allow] {
            #expect(rule(action, networks: ["192.0.2.0/24"]).networkApplies(to: .known(inside)))
            #expect(!rule(action, networks: ["192.0.2.0/24"]).networkApplies(to: .known(outside)))
        }
    }

    @Test
    func `A disabled rule never applies`() throws {
        let inside = try address("192.0.2.9")
        for action in [PolicyAction.deny, .allow] {
            let disabled = rule(action, networks: ["192.0.2.0/24"], enabled: false)
            #expect(!disabled.networkApplies(to: .known(inside)))
            #expect(!disabled.networkApplies(to: .unknown))
        }
    }

    @Test
    func `A rule without a network criterion applies to every flow`() throws {
        for observed: Observed<FlowAddress?> in try [.known(address("192.0.2.1")), .known(nil), .unknown] {
            #expect(PolicyMatch(transport: .tcp).evaluateNetwork(observed) == .match)
            #expect(rule(.allow, networks: nil).networkApplies(to: observed))
            #expect(rule(.deny, networks: nil).networkApplies(to: observed))
        }
    }

    // MARK: - Properties

    private static let seeds: [UInt64] = [1, 0x5EED, 0xDEADBEEF, 0x0123456789ABCDEF]
    private static let caseCount = 500

    @Test(arguments: seeds)
    func `An IPv4 address lies in every network of its own prefixes and leaves it at the last prefix bit`(seed: UInt64) throws {
        var random = SeededGenerator(seed: seed)
        for index in 0..<Self.caseCount {
            let bits = UInt32(truncatingIfNeeded: random.next())
            let prefix = random.next(below: 33)
            let mask: UInt32 = prefix == 0 ? 0 : .max << (32 - prefix)
            let context = "seed \(seed), case \(index), prefix \(prefix)"
            let network = try #require(IPNetwork("\(ipv4Text(bits & mask))/\(prefix)"), "\(context)")
            #expect(network.contains(FlowAddress(ipv4: bits)), "\(context)")
            if prefix > 0 {
                let flipped = bits ^ (1 << (32 - prefix))
                #expect(!network.contains(FlowAddress(ipv4: flipped)), "\(context)")
            }
        }
    }

    @Test(arguments: seeds)
    func `An IPv6 address lies in every network of its own prefixes and leaves it at the last prefix bit`(seed: UInt64) throws {
        var random = SeededGenerator(seed: seed)
        for index in 0..<Self.caseCount {
            let bits = random.ipv6()
            let prefix = random.next(below: 129)
            // A mapped base is refused by validation and is IPv4 as a flow.
            guard (bits & (prefix == 0 ? 0 : .max << (128 - prefix))) >> 32 != 0xFFFF, bits >> 32 != 0xFFFF else {
                continue
            }
            let mask: UInt128 = prefix == 0 ? 0 : .max << (128 - prefix)
            let context = "seed \(seed), case \(index), prefix \(prefix)"
            let network = try #require(IPNetwork("\(canonicalIPv6Text(bits & mask))/\(prefix)"), "\(context)")
            #expect(network.contains(FlowAddress(ipv6: bits)), "\(context)")
            if prefix > 0 {
                let flipped = bits ^ (1 << (128 - prefix))
                #expect(!network.contains(FlowAddress(ipv6: flipped)), "\(context)")
            }
        }
    }

    @Test(arguments: seeds)
    func `Canonical, expanded, uppercase and bracketed IPv6 spellings parse alike`(seed: UInt64) {
        var random = SeededGenerator(seed: seed)
        for index in 0..<Self.caseCount {
            let bits = random.ipv6()
            guard bits >> 32 != 0xFFFF else {
                continue
            }
            let expected = FlowAddress(ipv6: bits)
            let canonical = canonicalIPv6Text(bits)
            let expanded = (0..<8).map { group in
                let value = String(UInt16(truncatingIfNeeded: bits >> (112 - 16 * group)), radix: 16)
                return String(repeating: "0", count: 4 - value.count) + value
            }.joined(separator: ":")
            let context = "seed \(seed), case \(index)"
            #expect(FieldRules.isCanonicalIPv6(canonical), "\(context)")
            for spelling in [canonical, expanded, canonical.uppercased(), "[\(canonical)]", "\(canonical)%en0"] {
                #expect(FlowAddress(reported: spelling) == expected, "\(context), \(spelling)")
            }
        }
    }

    @Test(arguments: seeds)
    func `Arbitrary accepted input is the address the system parser reads`(seed: UInt64) {
        var random = SeededGenerator(seed: seed)
        let alphabet: [String] = ["0", "1", "9", "a", "f", "F", "g", ":", ":", ".", "%", "[", "]", "+", "-", " ", "/", "x", "１"]
        for index in 0..<Self.caseCount {
            let length = random.next(below: index.isMultiple(of: 50) ? 80 : 24)
            let text = (0..<length).map { _ in alphabet[random.next(below: alphabet.count)] }.joined()
            guard let parsed = FlowAddress(reported: text) else {
                continue
            }
            #expect(referenceAddress(text) == parsed, "seed \(seed), case \(index), \(text)")
        }
    }
    
    @Test(arguments: seeds)
    func `Every RFC 4291 spelling of a random address is the address the system parser reads`(seed: UInt64) {
        var random = SeededGenerator(seed: seed)
        for index in 0..<Self.caseCount {
            let bits = random.ipv6()
            let text = random.spelling(of: bits)
            let context = "seed \(seed), case \(index), \(text)"
            #expect(FlowAddress(reported: text) == FlowAddress(ipv6: bits), "\(context)")
            #expect(referenceAddress(text) == FlowAddress(ipv6: bits), "\(context)")
        }
    }
}

/// `inet_pton` as an independent oracle for an address that the parser under
/// test accepted; brackets and a zone are stripped first, as `inet_pton` takes neither.
private func referenceAddress(_ reported: String) -> FlowAddress? {
    var text = Substring(reported)
    if text.hasPrefix("["), text.hasSuffix("]") {
        text = text.dropFirst().dropLast()
    }
    if let percent = text.firstIndex(of: "%") {
        text = text[..<percent]
    }
    let core = String(text)
    if core.contains(":") {
        var address = in6_addr()
        guard inet_pton(AF_INET6, core, &address) == 1 else {
            return nil
        }
        return withUnsafeBytes(of: &address) { FlowAddress(bytes: Array($0)) }
    }
    var address = in_addr()
    guard inet_pton(AF_INET, core, &address) == 1 else {
        return nil
    }
    return withUnsafeBytes(of: &address) { FlowAddress(bytes: Array($0)) }
}

private extension IPNetwork {
    func contains(_ address: FlowAddress) -> Bool {
        evaluate(address) == .match
    }
}

private func ipv4Text(_ bits: UInt32) -> String {
    (0..<4).map { String(UInt8(truncatingIfNeeded: bits >> (24 - 8 * $0))) }.joined(separator: ".")
}

/// RFC 5952 text, written independently of the parser under test.
private func canonicalIPv6Text(_ bits: UInt128) -> String {
    let groups = (0..<8).map { UInt16(truncatingIfNeeded: bits >> (112 - 16 * $0)) }
    var bestStart = -1
    var bestLength = 1
    var index = 0
    while index < 8 {
        guard groups[index] == 0 else {
            index += 1
            continue
        }
        let start = index
        while index < 8, groups[index] == 0 {
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
    return text[..<bestStart].joined(separator: ":") + "::" + text[(bestStart + bestLength)...].joined(separator: ":")
}

private extension SeededGenerator {
    /// A random RFC 4291 §2.2 spelling: leading zeros, mixed case, any zero run
    /// compressed or none, and an optional dotted IPv4 tail.
    mutating func spelling(of bits: UInt128) -> String {
        let groups = (0..<8).map { UInt16(truncatingIfNeeded: bits >> (112 - 16 * $0)) }
        let hasTail = next(below: 3) == 0
        let hexCount = hasTail ? 6 : 8
        var fields = groups[..<hexCount].map { group in
            var text = String(group, radix: 16)
            text = String(repeating: "0", count: next(below: 5 - text.count)) + text
            return next(below: 2) == 0 ? text.uppercased() : text
        }
        if hasTail {
            fields.append(ipv4Text(UInt32(groups[6]) << 16 | UInt32(groups[7])))
        }
        let zeroIndices = (0..<hexCount).filter { groups[$0] == 0 }
        guard !zeroIndices.isEmpty, next(below: 4) != 0 else {
            return fields.joined(separator: ":")
        }
        let start = zeroIndices[next(below: zeroIndices.count)]
        var end = start + 1
        while end < hexCount, groups[end] == 0, next(below: 3) != 0 {
            end += 1
        }
        return fields[..<start].joined(separator: ":") + "::" + fields[end...].joined(separator: ":")
    }
    
    /// Biased toward zero groups, so `::` compression is exercised.
    mutating func ipv6() -> UInt128 {
        (0..<8).reduce(UInt128(0)) { bits, _ in
            let group: UInt128 = next(below: 3) == 0 ? 0 : UInt128(UInt16(truncatingIfNeeded: next()))
            return bits << 16 | group
        }
    }
}
