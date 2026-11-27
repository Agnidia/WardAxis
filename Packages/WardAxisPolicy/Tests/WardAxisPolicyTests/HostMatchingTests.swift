//
//  HostMatchingTests.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Testing
import WardAxisCore
import WardAxisPolicy

private func host(_ name: String) throws -> FlowHost {
    try #require(FlowHost(normalizing: name))
}

private func rule(_ action: PolicyAction, hosts: [String]?, enabled: Bool = true) -> PolicyRule {
    PolicyRule(
        identifier: "r1",
        priority: 100,
        enabled: enabled,
        action: action,
        match: PolicyMatch(destinationHosts: hosts, transport: hosts == nil ? .tcp : nil)
    )
}

@Suite("Host name matching")
struct HostMatchingTests {
    // MARK: - Label-aware match
    
    @Test
    func `A name rule never matches a host that only ends with the same characters`() throws {
        let match = PolicyMatch(destinationHosts: ["example.test"])
        #expect(try match.evaluateHost(.known(host("fakeexample.test"))) == .noMatch)
        #expect(try match.evaluateHost(.known(host("a.example.test"))) == .noMatch)
        #expect(try match.evaluateHost(.known(host("example.test"))) == .match)
    }
    
    @Test(arguments: ["a.example.test", "a.b.example.test", "xn--bcher-kva.example.test"])
    func `A wildcard matches every subdomain`(name: String) throws {
        #expect(try host(name).matches("*.example.test"))
    }
    
    @Test(arguments: ["example.test", "fakeexample.test", "example.test.evil", "a.fakeexample.test", "example.tes", "xample.test"])
    func `A wildcard matches neither its apex nor a host without the label boundary`(name: String) throws {
        #expect(try !host(name).matches("*.example.test"))
    }
    
    @Test
    func `One matching element of the host list is enough`() throws {
        let match = PolicyMatch(destinationHosts: ["other.test", "*.example.test"])
        #expect(try match.evaluateHost(.known(host("www.example.test"))) == .match)
        #expect(try match.evaluateHost(.known(host("www.other.test"))) == .noMatch)
    }
    
    @Test(arguments: ["EXAMPLE.TEST", "*", "*.", "example.test.", "*.EXAMPLE.test", ""])
    func `A pattern that bypassed validation cannot widen a match`(pattern: String) throws {
        #expect(try !host("www.example.test").matches(pattern))
        #expect(try !host("example.test").matches(pattern))
    }
    
    // MARK: - Normalization
    
    @Test(arguments: [
        ("Example.TEST", "example.test"),
        ("example.test.", "example.test"),
        ("WWW.Example.Test.", "www.example.test"),
        ("XN--BCHER-KVA.de", "xn--bcher-kva.de"),
        ("bücher.de", "xn--bcher-kva.de"),
        ("BÜCHER.DE", "xn--bcher-kva.de"),
        ("ü.xn--bcher-kva.de", "xn--tda.xn--bcher-kva.de"),
        ("ｅｘａｍｐｌｅ.test", "example.test"),
        ("example。test", "example.test"),
        ("аpple.com", "xn--pple-43d.com")
    ])
    func `Case, one trailing dot and IDNA map to one canonical name`(reported: String, canonical: String) throws {
        #expect(try host(reported).name == canonical)
    }
    
    @Test(arguments: [
        "", ".", "example.test..", ".example.test", "example..test", "exa mple.test", "ex%41.test", "under_score.test",
        "-lead.test", "trail-.test", "*.example.test", "127.1", "0x7f.1", "010.0.0.1", "999", "[fe80::1%en0]", "[192.0.2.1]",
        "xn--zz.test", "ü.xn--zz", "xn--abc-.test", "xn--fa-hia.de", "faß.de", "FAẞ.de", "ς.test", "a\u{200D}b.test",
        "exa mple.bücher.de", "bücher.de/path", "user@example.test", "example.test:443",
        String(repeating: "a", count: 64) + ".test",
        Array(repeating: "abcdefghi", count: 26).joined(separator: "."),
        String(repeating: "a", count: PolicyLimits.maximumReportedHostLength + 1),
        String(repeating: "ü", count: 200) + ".test"
    ])
    func `A name without a canonical form is refused`(reported: String) {
        #expect(FlowHost(normalizing: reported) == nil)
        #expect(FlowHost.observed(reportedName: reported) == .unknown)
    }
    
    @Test
    func `Equality and hashing see one name in every spelling`() throws {
        let spellings = try ["example.test", "EXAMPLE.test", "example.test.", "ｅxample.test"].map(host)
        #expect(Set(spellings).count == 1)
        #expect(try host("example.test") != host("example.tests"))
    }
    
    @Test(arguments: ["192.0.2.1", "192.0.2.1.", "::1", "[::1]", "[::FFFF:C000:201]", "2001:db8::1", "１９２.０.２.１"])
    func `An IP literal is a flow without a host name, not an unknown one`(reported: String) {
        #expect(FlowHost(normalizing: reported) == nil)
        #expect(FlowHost.observed(reportedName: reported) == .known(nil))
        #expect(!rule(.deny, hosts: ["*.tracker.test"]).hostApplies(to: FlowHost.observed(reportedName: reported)))
    }
    
    // MARK: - Unknown and absent hosts
    
    @Test
    func `A flow connected by address is no match for a host rule; an unknown host is unknown`() {
        let match = PolicyMatch(destinationHosts: ["example.test"])
        #expect(match.evaluateHost(.known(nil)) == .noMatch)
        #expect(match.evaluateHost(.unknown) == .unknown)
        #expect(match.evaluateHost(FlowHost.observed(reportedName: "exa mple.test")) == .unknown)
    }
    
    @Test
    func `An unknown or malformed host applies a deny rule and never an allow rule`() {
        for observed in [Observed<FlowHost?>.unknown, FlowHost.observed(reportedName: "EXAMPLE.test..")] {
            #expect(rule(.deny, hosts: ["example.test"]).hostApplies(to: observed))
            #expect(!rule(.allow, hosts: ["example.test"]).hostApplies(to: observed))
        }
    }
    
    @Test
    func `A known host follows the match result for both actions`() throws {
        for action in [PolicyAction.allow, .deny] {
            #expect(try rule(action, hosts: ["*.example.test"]).hostApplies(to: .known(host("A.Example.Test."))))
            #expect(try !rule(action, hosts: ["*.example.test"]).hostApplies(to: .known(host("fakeexample.test"))))
            #expect(!rule(action, hosts: ["*.example.test"]).hostApplies(to: .known(nil)))
        }
    }
    
    @Test
    func `A disabled rule never applies; a rule without a host criterion always does`() throws {
        for observed in try [Observed<FlowHost?>.unknown, .known(nil), .known(host("example.test"))] {
            #expect(!rule(.deny, hosts: ["example.test"], enabled: false).hostApplies(to: observed))
            #expect(rule(.allow, hosts: nil).hostApplies(to: observed))
            #expect(rule(.deny, hosts: nil).hostApplies(to: observed))
        }
    }
    
    // MARK: - Properties
    
    private static let seeds: [UInt64] = [1, 0x5EED, 0xDEADBEEF, 0x0123456789ABCDEF]
    private static let caseCount = 500
    
    @Test(arguments: seeds)
    func `Normalization is idempotent and yields a canonical host name`(seed: UInt64) {
        var random = SplitMix64(seed: seed)
        for index in 0..<Self.caseCount {
            let reported = random.noisyString()
            guard let normalized = FlowHost(normalizing: reported) else {
                continue
            }
            #expect(FieldRules.isHostName(normalized.name), "seed \(seed), case \(index)")
            #expect(FlowHost(normalizing: normalized.name) == normalized, "seed \(seed), case \(index)")
        }
    }
    
    @Test(arguments: seeds)
    func `Case and trailing-dot variants normalize alike and match alike`(seed: UInt64) throws {
        var random = SplitMix64(seed: seed)
        for index in 0..<Self.caseCount {
            let name = random.hostName()
            let parent = name.split(separator: ".", maxSplits: 1).last.map(String.init) ?? name
            let variant = random.variant(of: name)
            let canonical = try host(name)
            let normalized = try #require(FlowHost(normalizing: variant), "seed \(seed), case \(index)")
            #expect(normalized == canonical, "seed \(seed), case \(index)")
            for pattern in [name, "*.\(parent)"] where FieldRules.isHostPattern(pattern) {
                #expect(normalized.matches(pattern) == canonical.matches(pattern), "seed \(seed), case \(index)")
            }
        }
    }
    
    @Test(arguments: seeds)
    func `Wildcards respect label boundaries`(seed: UInt64) throws {
        var random = SplitMix64(seed: seed)
        for index in 0..<Self.caseCount {
            let suffix = random.hostName(minimumLabels: 2)
            let label = random.label()
            let context = "seed \(seed), case \(index)"
            #expect(try host("\(label).\(suffix)").matches("*.\(suffix)"), "\(context)")
            #expect(try !host(suffix).matches("*.\(suffix)"), "\(context)")
            #expect(try host(suffix).matches(suffix), "\(context)")
            #expect(try !host("\(label).\(suffix)").matches(suffix), "\(context)")
            if let joined = FlowHost(normalizing: label + suffix) {
                #expect(!joined.matches("*.\(suffix)"), "\(context)")
                #expect(!joined.matches(suffix), "\(context)")
            }
        }
    }
    
    @Test(arguments: seeds)
    func `Arbitrary input is either refused or canonical`(seed: UInt64) {
        var random = SplitMix64(seed: seed)
        for index in 0..<Self.caseCount {
            let reported = random.noisyString(maximumLength: index.isMultiple(of: 50) ? 1100 : 40)
            switch FlowHost.observed(reportedName: reported) {
            case .known(.some(let host)):
                #expect(FieldRules.isHostName(host.name), "seed \(seed), case \(index)")
            case .known(nil):
                #expect(FlowHost(normalizing: reported) == nil, "An address is never also a name; seed \(seed), case \(index)")
            case .unknown:
                break
            }
        }
    }
}

/// Seeded generator, so a failing property reproduces from the seed in its message.
/// Every choice reads the raw stream; `Int.random(in:using:)` may change its mapping.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        state = seed
    }
    
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
    
    mutating func below(_ bound: Int) -> Int {
        Int(next() % UInt64(bound))
    }
    
    mutating func label() -> String {
        let letters = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        let length = 1 + below(12)
        var bytes = (0..<length).map { _ in letters[below(letters.count)] }
        if length > 2, below(4) == 0 {
            bytes[1 + below(length - 2)] = "-"
        }
        return String(bytes)
    }
    
    /// A canonical host name whose last label holds a letter, so it never reads as an address.
    mutating func hostName(minimumLabels: Int = 1) -> String {
        var labels = (0..<(minimumLabels + below(3))).map { _ in label() }
        labels[labels.count - 1] = "t" + labels[labels.count - 1]
        return labels.joined(separator: ".")
    }
    
    mutating func variant(of name: String) -> String {
        let flipped = String(name.map { below(2) == 0 ? Character($0.uppercased()) : $0 })
        return below(2) == 0 ? flipped + "." : flipped
    }
    
    mutating func noisyString(maximumLength: Int = 40) -> String {
        let alphabet: [String] = [
            "a", "z", "0", "9", "A", "Z", "-", ".", ".", "%", " ", "_", "*", ":", "/", "[", "]", "@",
            "ü", "ß", "ｅ", "。", "\u{200B}", "\u{0301}", "K", "а", "😀", "\u{0}"
        ]
        let length = below(maximumLength + 1)
        return (0..<length).map { _ in alphabet[below(alphabet.count)] }.joined()
    }
}
