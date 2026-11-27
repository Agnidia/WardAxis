//
//  PortRange.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisCore

/// An inclusive range of destination ports. One port is `first == last`.
public struct PortRange: Sendable, Hashable, Codable {
    public let first: Int
    public let last: Int
    
    public init(first: Int, last: Int) {
        self.first = first
        self.last = last
    }
    
    /// Both ends are valid ports and `first <= last`. An inverted range would
    /// match nothing, so it is refused rather than silently dropped.
    var isValid: Bool {
        FieldRules.isPort(first) && FieldRules.isPort(last) && first <= last
    }
}
