//
//  MatchResult.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// One flow field as an enforcement component saw it. `unknown` means the
/// platform or the provider could not supply the field; it is never the same
/// as a known empty value such as `.known(nil)` (ADR 0016 D2, ADR 0017 D3).
public enum Observed<Value: Sendable & Hashable>: Sendable, Hashable {
    case known(Value)
    case unknown
}

/// The outcome of one rule criterion against one flow, shared by every criterion.
/// A rule turns `unknown` into a decision by its action (ADR 0016 D3, ADR 0017 D3).
public enum MatchResult: Sendable, Hashable {
    case match
    /// A known field contradicts the criterion. Definite, whatever the other fields are.
    case noMatch
    /// No known field contradicts the criterion, but a field it needs is unknown.
    case unknown
}

extension Observed {
    /// Evaluates a field whose known value can be absent, such as a flow with
    /// no host name. An absent field never matches, so the rules for the other
    /// field decide; an unknown field stays unknown.
    func evaluate<Wrapped>(_ present: (Wrapped) -> MatchResult) -> MatchResult where Value == Wrapped? {
        switch self {
        case .known(.some(let value)): present(value)
        case .known(nil): .noMatch
        case .unknown: .unknown
        }
    }
}

extension PolicyRule {
    /// The only place a criterion result becomes a decision, so every criterion
    /// fails closed the same way (ADR 0016 D3): `unknown` lets a `deny` rule
    /// apply and never an `allow` rule. A disabled rule never applies, and its
    /// criterion is not evaluated.
    func applies(_ result: @autoclosure () -> MatchResult) -> Bool {
        guard enabled else {
            return false
        }
        
        return switch result() {
        case .match: true
        case .noMatch: false
        case .unknown: action == .deny
        }
    }
}
