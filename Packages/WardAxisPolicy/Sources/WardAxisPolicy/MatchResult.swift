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
