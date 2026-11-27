//
//  ApplicationMatchingTests.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Testing
import WardAxisCore
import WardAxisPolicy

private let browser = ApplicationMatcher(
    signingIdentifier: "com.example.browser",
    teamIdentifier: "EXAMPLE001",
    isPlatformBinary: false,
    bundleIdentifier: "com.example.browser"
)

private let curl = ApplicationMatcher(signingIdentifier: "com.apple.curl", teamIdentifier: nil, isPlatformBinary: true)

private let browserFlow = FlowApplication(
    signingIdentifier: .known("com.example.browser"),
    team: .known(.team("EXAMPLE001")),
    bundleIdentifier: .known("com.example.browser")
)

private func rule(_ action: PolicyAction, application: ApplicationMatcher?, enabled: Bool = true) -> PolicyRule {
    PolicyRule(
        identifier: "r1",
        priority: 100,
        enabled: enabled,
        action: action,
        match: PolicyMatch(application: application, destinationHosts: application == nil ? ["example.com"] : nil)
    )
}

@Suite("Application identity matching")
struct ApplicationMatchingTests {
    // MARK: - Exact match

    @Test
    func `A flow matches when every named field is known and equal`() {
        #expect(browser.evaluate(browserFlow) == .match)
        #expect(curl.evaluate(FlowApplication(signingIdentifier: .known("com.apple.curl"), team: .known(.platformBinary), bundleIdentifier: .known(nil))) == .match)
    }

    @Test
    func `A matcher without a bundle ID accepts any bundle, and an unknown one`() {
        let matcher = ApplicationMatcher(signingIdentifier: "com.example.browser", teamIdentifier: "EXAMPLE001", isPlatformBinary: false)
        for bundle: Observed<String?> in [.known("com.example.other"), .known(nil), .unknown] {
            let flow = FlowApplication(signingIdentifier: browserFlow.signingIdentifier, team: browserFlow.team, bundleIdentifier: bundle)
            #expect(matcher.evaluate(flow) == .match)
        }
    }

    @Test
    func `A full identity from the resolver matches like an observed one`() {
        let identity = ApplicationIdentity(signingIdentifier: "com.example.browser", teamIdentifier: "EXAMPLE001", isPlatformBinary: false, bundleIdentifier: "com.example.browser")
        #expect(FlowApplication(resolved: identity) == browserFlow)
        #expect(browser.evaluate(FlowApplication(identity)) == .match)
    }

    @Test
    func `A resolver without a bundle ID leaves the bundle unknown, so a bundle-scoped deny still applies`() {
        let identity = ApplicationIdentity(signingIdentifier: "com.example.browser", teamIdentifier: "EXAMPLE001", isPlatformBinary: false, bundleIdentifier: nil)
        let flow = FlowApplication(identity)
        
        #expect(flow.bundleIdentifier == .unknown)
        #expect(browser.evaluate(flow) == .unknown)
        #expect(rule(.deny, application: browser).applicationApplies(to: flow))
        #expect(!rule(.allow, application: browser).applicationApplies(to: flow))
    }
    
    @Test
    func `A forged identity with a Team ID and the platform-binary flag has an unknown team`() {
        let identity = ApplicationIdentity(signingIdentifier: "com.example.browser", teamIdentifier: "EXAMPLE001", isPlatformBinary: true, bundleIdentifier: "com.example.browser")
        let flow = FlowApplication(identity)
        
        #expect(flow.team == .unknown)
        #expect(browser.evaluate(flow) == .unknown)
        #expect(!rule(.allow, application: browser).applicationApplies(to: flow))
    }
    
    // MARK: - Negative

    @Test(arguments: [
        FlowApplication(signingIdentifier: .known("com.example.browser2"), team: .known(.team("EXAMPLE001")), bundleIdentifier: .known("com.example.browser")),
        FlowApplication(signingIdentifier: .known("example.browser"), team: .known(.team("EXAMPLE001")), bundleIdentifier: .known("com.example.browser")),
        FlowApplication(signingIdentifier: .known("com.Example.browser"), team: .known(.team("EXAMPLE001")), bundleIdentifier: .known("com.example.browser")),
        FlowApplication(signingIdentifier: .known("com.example.browser"), team: .known(.team("EXAMPLE999")), bundleIdentifier: .known("com.example.browser")),
        FlowApplication(signingIdentifier: .known("com.example.browser"), team: .known(.team("example001")), bundleIdentifier: .known("com.example.browser")),
        FlowApplication(signingIdentifier: .known("com.example.browser"), team: .known(.withoutTeam), bundleIdentifier: .known("com.example.browser")),
        FlowApplication(signingIdentifier: .known("com.example.browser"), team: .known(.platformBinary), bundleIdentifier: .known("com.example.browser")),
        FlowApplication(signingIdentifier: .known("com.example.browser"), team: .known(.team("EXAMPLE001")), bundleIdentifier: .known("com.example.browser.helper")),
        FlowApplication(signingIdentifier: .known("com.example.browser"), team: .known(.team("EXAMPLE001")), bundleIdentifier: .known(nil))
    ])
    func `Any differing field is no match, with no prefix, suffix or case folding`(flow: FlowApplication) {
        #expect(browser.evaluate(flow) == .noMatch)
    }

    @Test
    func `A canonically equivalent but different spelling is no match`() {
        // U+212A KELVIN SIGN is canonically equivalent to "K", so `String ==` would accept it.
        let matcher = ApplicationMatcher(signingIdentifier: "com.example.K", teamIdentifier: "EXAMPLE001", isPlatformBinary: false)
        let flow = FlowApplication(signingIdentifier: .known("com.example.\u{212A}"), team: .known(.team("EXAMPLE001")), bundleIdentifier: .unknown)
        #expect("com.example.\u{212A}" == "com.example.K")
        #expect(matcher.evaluate(flow) == .noMatch)
    }
    
    @Test
    func `Flow equality and hashing compare bytes, like the matcher`() {
        let kelvin = FlowApplication(signingIdentifier: .known("com.example.\u{212A}"), team: .known(.team("EXAMPLE001")), bundleIdentifier: .known("com.example.\u{212A}"))
        let letter = FlowApplication(signingIdentifier: .known("com.example.K"), team: .known(.team("EXAMPLE001")), bundleIdentifier: .known("com.example.K"))
        
        #expect(kelvin != letter)
        #expect(Set([kelvin, letter]).count == 2)
        #expect(TeamAttribution.team("EXAMPLE\u{212A}01") != .team("EXAMPLEK01"))
        #expect(kelvin == FlowApplication(signingIdentifier: .known("com.example.\u{212A}"), team: .known(.team("EXAMPLE001")), bundleIdentifier: .known("com.example.\u{212A}")))
    }

    @Test
    func `A platform-binary matcher refuses a team-signed or ad hoc copy`() {
        for team: TeamAttribution in [.team("EXAMPLE001"), .withoutTeam] {
            let flow = FlowApplication(signingIdentifier: .known("com.apple.curl"), team: .known(team), bundleIdentifier: .known(nil))
            #expect(curl.evaluate(flow) == .noMatch)
        }
    }

    // MARK: - Unknown fields

    @Test
    func `A flow with no identity is unknown, never a match`() {
        #expect(browser.evaluate(.unknown) == .unknown)
        #expect(FlowApplication(resolved: nil) == .unknown)
    }

    @Test(arguments: [
        FlowApplication(signingIdentifier: .unknown, team: .known(.team("EXAMPLE001")), bundleIdentifier: .known("com.example.browser")),
        FlowApplication(signingIdentifier: .known("com.example.browser"), team: .unknown, bundleIdentifier: .known("com.example.browser")),
        FlowApplication(signingIdentifier: .known("com.example.browser"), team: .known(.team("EXAMPLE001")), bundleIdentifier: .unknown)
    ])
    func `One unknown named field makes a partial identity unknown, not a match`(flow: FlowApplication) {
        #expect(browser.evaluate(flow) == .unknown)
    }

    @Test(arguments: [
        FlowApplication(signingIdentifier: .known("com.example.other"), team: .unknown, bundleIdentifier: .unknown),
        FlowApplication(signingIdentifier: .unknown, team: .known(.team("EXAMPLE999")), bundleIdentifier: .unknown),
        FlowApplication(signingIdentifier: .unknown, team: .unknown, bundleIdentifier: .known("com.example.other"))
    ])
    func `A known differing field is no match even when other fields are unknown`(flow: FlowApplication) {
        #expect(browser.evaluate(flow) == .noMatch)
    }

    @Test
    func `An unpinned matcher that bypassed validation never reports a match`() {
        let unpinned = ApplicationMatcher(signingIdentifier: "com.example.browser", teamIdentifier: nil, isPlatformBinary: false)
        let contradictory = ApplicationMatcher(signingIdentifier: "com.example.browser", teamIdentifier: "EXAMPLE001", isPlatformBinary: true)
        let adHoc = FlowApplication(signingIdentifier: .known("com.example.browser"), team: .known(.withoutTeam), bundleIdentifier: .known(nil))

        #expect(unpinned.evaluate(adHoc) == .unknown)
        #expect(contradictory.evaluate(browserFlow) == .unknown)
    }

    // MARK: - Fallback

    @Test
    func `Unknown identity applies a deny rule and never an allow rule`() {
        let partial = FlowApplication(signingIdentifier: .known("com.example.browser"), team: .unknown, bundleIdentifier: .unknown)
        for flow in [FlowApplication.unknown, partial] {
            #expect(rule(.deny, application: browser).applicationApplies(to: flow))
            #expect(!rule(.allow, application: browser).applicationApplies(to: flow))
        }
    }

    @Test(arguments: [PolicyAction.allow, .deny])
    func `A known identity decides alone, whatever the action`(action: PolicyAction) {
        let other = FlowApplication(signingIdentifier: .known("com.example.other"), team: .known(.team("EXAMPLE001")), bundleIdentifier: .known(nil))
        #expect(rule(action, application: browser).applicationApplies(to: browserFlow))
        #expect(!rule(action, application: browser).applicationApplies(to: other))
    }

    @Test(arguments: [PolicyAction.allow, .deny])
    func `A disabled rule never applies, even to an unknown flow`(action: PolicyAction) {
        #expect(!rule(action, application: browser, enabled: false).applicationApplies(to: .unknown))
        #expect(!rule(action, application: browser, enabled: false).applicationApplies(to: browserFlow))
        #expect(!rule(action, application: nil, enabled: false).applicationApplies(to: .unknown))
    }
    
    @Test(arguments: [PolicyAction.allow, .deny])
    func `A rule without an application criterion applies to an unknown flow`(action: PolicyAction) {
        #expect(rule(action, application: nil).applicationApplies(to: .unknown))
    }
}
