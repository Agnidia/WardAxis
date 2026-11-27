//
//  FieldRulesTests.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Testing
@testable import WardAxisCore

@Suite("Field rules")
struct FieldRulesTests {
    @Test(arguments: ["example.com", "a.b.c", "xn--bcher-kva.example", "a-b.example", String(repeating: "a", count: 63) + ".com"])
    func `Canonical host names are accepted`(host: String) {
        #expect(FieldRules.isHostName(host))
    }
    
    @Test(arguments: [
        "", "Example.com", "example.com.", ".example.com", "exa mple.com", "-a.example", "a-.example",
        "bücher.example", "ex\u{0430}mple.com", "example.com/path", "a..b", "999.0.0.1", "127.1", "192.0.2.10",
        String(repeating: "a", count: 64) + ".com",
        Array(repeating: String(repeating: "a", count: 63), count: 4).joined(separator: ".") + ".com"
    ])
    func `Non-canonical host names are refused`(host: String) {
        #expect(!FieldRules.isHostName(host))
    }
    
    /// `*.co.uk` passes: the rule counts labels and has no public-suffix list (ADR 0011 D3).
    @Test(arguments: [("*.example.com", true), ("*.co.uk", true), ("*.com", false), ("*example.com", false), ("a.*.example.com", false), ("**.example.com", false)])
    func `A wildcard needs at least two labels after the star`(pattern: String, isValid: Bool) {
        #expect(FieldRules.isHostPattern(pattern) == isValid)
    }
    
    @Test(arguments: [
        ("192.0.2.10", true), ("0.0.0.0", true), ("255.255.255.255", true), ("example.com", true),
        ("2001:db8::1", true), ("::1", true), ("::", true), ("1::", true), ("2001:db8:0:1:1:1:1:1", true),
        ("999.0.0.1", false), ("127.1", false), ("1", false), ("0x7f.0.0.1", false), ("010.0.0.1", false), ("192.0.2.256", false),
        ("[2001:db8::1]", false), ("2001:DB8::1", false), ("fe80::1%en0", false), ("2001:db8:0:0:0:0:0:1", false),
        ("2001:0db8::1", false), ("2001:db8::0:1", false), ("::ffff:192.0.2.1", false), ("1:2:3:4:5:6:7:8:9", false), ("1::2::3", false)
    ])
    func `A remote host is a host name or a canonical IP literal`(host: String, isValid: Bool) {
        #expect(FieldRules.isRemoteHost(host) == isValid)
    }
    
    @Test(arguments: [("EXAMPLE001", true), ("example001", false), ("EXAMPLE01", false), ("EXAMPLE0011", false), ("EXAMPLE-01", false)])
    func `A Team ID is ten uppercase alphanumerics`(team: String, isValid: Bool) {
        #expect(FieldRules.isTeamIdentifier(team) == isValid)
    }
    
    @Test(arguments: [("com.example.app", true), ("a", true), (".hidden", false), ("com/example", false), ("com.ex\u{0430}mple", false), (String(repeating: "a", count: 256), false)])
    func `A signing identifier is an ASCII token of at most 255 bytes`(identifier: String, isValid: Bool) {
        #expect(FieldRules.isSigningIdentifier(identifier) == isValid)
    }
    
    @Test(arguments: ["0x7f000001", "0x7f.0x0.0x0.0x1", "127.0x0.0x0.0x1", "0x7f.1", "0177.0.0.1", "2130706433", "127.1"])
    func `Numeric address alternatives are neither host names nor policy patterns`(host: String) {
        #expect(!FieldRules.isHostName(host))
        #expect(!FieldRules.isHostPattern(host))
        #expect(!FieldRules.isRemoteHost(host))
    }
    
    @Test(arguments: ["0x7f.example.com", "example0x1.com", "localhost", "example.com"])
    func `Non-numeric host names remain valid`(host: String) {
        #expect(FieldRules.isHostName(host))
    }
    
    @Test(arguments: ["192.0.2.0/24", "0.0.0.0/0", "198.51.100.7/32", "10.0.0.0/8", "2001:db8::/32", "::/0", "fe80::/10", "2001:db8::1/128"])
    func `A canonical network with zero host bits is accepted`(network: String) {
        #expect(FieldRules.isCanonicalNetwork(network))
    }
    
    @Test(arguments: [
        "", "192.0.2.0", "/24", "192.0.2.0/", "192.0.2.0/24/8", "192.0.2.1/24", "192.0.2.0/33", "192.0.2.0/024", "192.0.2.0/-1",
        "192.0.2.0/+8", "192.0.2.0/ 24", "192.000.2.0/24", "0x7f.0.0.0/8", "127.1/8", "2001:DB8::/32", "2001:0db8::/32",
        "2001:db8::1/32", "2001:db8::/129", "fe80::%en0/64", "::ffff:192.0.2.0/120", "example.com/24", "2001:db8::/0032"
    ])
    func `Any other network spelling is refused`(network: String) {
        #expect(!FieldRules.isCanonicalNetwork(network))
    }
}
