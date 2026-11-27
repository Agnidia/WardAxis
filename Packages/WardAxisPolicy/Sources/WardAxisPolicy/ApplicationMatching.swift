//
//  ApplicationMatching.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisCore

/// One identity field as an enforcement component saw it. `unknown` means the
/// platform or the resolver could not supply the field; it is never the same
/// as a known empty value (ADR 0016 D2).
public enum Observed<Value: Sendable & Hashable>: Sendable, Hashable {
    case known(Value)
    case unknown
}

/// Who signed an application, beyond its signing identifier.
public enum TeamAttribution: Sendable, Hashable {
    case team(String)
    case platformBinary
    /// Ad hoc signed, or signed without a Team ID and not by Apple.
    case withoutTeam
    
    /// Byte equality, so `==` and a hash agree with `ApplicationMatcher.evaluate(_:)` (ADR 0016 D1).
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.team(let left), .team(let right)): left.utf8.elementsEqual(right.utf8)
        case (.platformBinary, .platformBinary), (.withoutTeam, .withoutTeam): true
        default: false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .team(let team):
            hasher.combine(0)
            hasher.combine(team.utf8.count)
            team.utf8.forEach { hasher.combine($0) }
        case .platformBinary:
            hasher.combine(1)
        case .withoutTeam:
            hasher.combine(2)
        }
    }
}

/// The application identity of one flow, field by field.
///
/// macOS reads every field from the audit token. Other providers supply some
/// fields or none (ADR 0016, context table); each missing field is `unknown`.
public struct FlowApplication: Sendable, Hashable {
    public let signingIdentifier: Observed<String>
    public let team: Observed<TeamAttribution>

    /// `.known(nil)` is a code object with no bundle, such as a command-line tool.
    public let bundleIdentifier: Observed<String?>

    public static let unknown = FlowApplication(signingIdentifier: .unknown, team: .unknown, bundleIdentifier: .unknown)

    public init(signingIdentifier: Observed<String>, team: Observed<TeamAttribution>, bundleIdentifier: Observed<String?>) {
        self.signingIdentifier = signingIdentifier
        self.team = team
        self.bundleIdentifier = bundleIdentifier
    }

    /// An identity from the code signature.
    ///
    /// A `nil` bundle ID may mean "not read", so it maps to `unknown`; only a
    /// provider that proves the absence of a bundle passes `.known(nil)`. A
    /// Team ID beside the platform-binary flag is a forged claim, so the team is `unknown`.
    public init(_ identity: ApplicationIdentity) {
        let team: Observed<TeamAttribution> = switch (identity.teamIdentifier, identity.isPlatformBinary) {
        case (.some(let teamIdentifier), false): .known(.team(teamIdentifier))
        case (nil, true): .known(.platformBinary)
        case (nil, false): .known(.withoutTeam)
        case (.some, true): .unknown
        }
        let bundleIdentifier: Observed<String?> = identity.bundleIdentifier.map { .known($0) } ?? .unknown
        self.init(signingIdentifier: .known(identity.signingIdentifier), team: team, bundleIdentifier: bundleIdentifier)
    }

    /// A resolver answer. `nil` (exited process, reused PID, unreadable
    /// signature) is an unknown application, never a match.
    public init(resolved identity: ApplicationIdentity?) {
        self = identity.map(FlowApplication.init) ?? .unknown
    }
    
    /// Byte equality, so `==` and a hash agree with `ApplicationMatcher.evaluate(_:)` (ADR 0016 D1).
    public static func == (lhs: Self, rhs: Self) -> Bool {
        isEqual(lhs.signingIdentifier, rhs.signingIdentifier) { $0.utf8.elementsEqual($1.utf8) }
            && lhs.team == rhs.team
            && isEqual(lhs.bundleIdentifier, rhs.bundleIdentifier) { left, right in
                switch (left, right) {
                case (.some(let left), .some(let right)): left.utf8.elementsEqual(right.utf8)
                case (nil, nil): true
                default: false
                }
            }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch signingIdentifier {
        case .known(let value): hasher.combine(0)
            Self.combineBytes(value, into: &hasher)
        case .unknown: hasher.combine(1)
        }
        hasher.combine(team)
        switch bundleIdentifier {
        case .known(.some(let value)): hasher.combine(0)
            Self.combineBytes(value, into: &hasher)
        case .known(nil): hasher.combine(1)
        case .unknown: hasher.combine(2)
        }
    }
    
    private static func isEqual<Value>(_ lhs: Observed<Value>, _ rhs: Observed<Value>, by isEqual: (Value, Value) -> Bool) -> Bool {
        switch (lhs, rhs) {
        case (.known(let left), .known(let right)): isEqual(left, right)
        case (.unknown, .unknown): true
        default: false
        }
    }
    
    private static func combineBytes(_ value: String, into hasher: inout Hasher) {
        // The length keeps adjacent fields from hashing as one byte run.
        hasher.combine(value.utf8.count)
        value.utf8.forEach { hasher.combine($0) }
    }
}

/// The outcome of one ``WardAxisCore/ApplicationMatcher`` against one flow.
public enum ApplicationMatchResult: Sendable, Hashable {
    case match
    /// A known field differs. Definite, whatever the other fields are.
    case noMatch
    /// No known field differs, but a field that the matcher names is unknown.
    case unknown
}

public extension ApplicationMatcher {
    /// Compares every field the matcher names, byte for byte (ADR 0016 D1).
    ///
    /// Byte comparison, not `String ==`: Swift equality is canonical
    /// equivalence, so `"K"` (U+212A KELVIN SIGN) would equal `"K"`, and a
    /// flow value is not validated like a policy value.
    func evaluate(_ flow: FlowApplication) -> ApplicationMatchResult {
        // An unpinned or contradictory matcher fails `validate(at:)`. If one
        // reaches here anyway, it has no team to compare, so the field counts
        // as unknown and the fail-closed fallback decides.
        let expectedTeam: TeamAttribution? = switch (teamIdentifier, isPlatformBinary) {
        case (.some(let team), false): .team(team)
        case (nil, true): .platformBinary
        default: nil
        }

        var isComplete = expectedTeam != nil
        switch flow.signingIdentifier {
        case .known(let value):
            guard Self.isExactlyEqual(value, signingIdentifier) else {
                return .noMatch
            }
        case .unknown:
            isComplete = false
        }
        switch flow.team {
        case .known(let value):
            if let expectedTeam, value != expectedTeam {
                return .noMatch
            }
        case .unknown:
            isComplete = false
        }
        if let bundleIdentifier {
            switch flow.bundleIdentifier {
            case .known(let value):
                guard let value, Self.isExactlyEqual(value, bundleIdentifier) else {
                    return .noMatch
                }
            case .unknown:
                isComplete = false
            }
        }
        return isComplete ? .match : .unknown
    }

    private static func isExactlyEqual(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.elementsEqual(rhs.utf8)
    }
}

public extension PolicyRule {
    /// Whether the application criterion lets this rule apply to `flow`.
    /// The other criteria and the resolution order belong to the engine (ADR 0015 D3).
    ///
    /// Unknown identity fails closed by action (ADR 0016 D3): a `deny` rule
    /// applies and an `allow` rule does not. Hiding or losing the identity
    /// therefore never escapes a deny and never earns an allow. A disabled rule never applies.
    func applicationApplies(to flow: FlowApplication) -> Bool {
        guard enabled else {
            return false
        }
        guard let application = match.application else {
            return true
        }
        switch application.evaluate(flow) {
        case .match:
            return true
        case .noMatch:
            return false
        case .unknown:
            return action == .deny
        }
    }
}
