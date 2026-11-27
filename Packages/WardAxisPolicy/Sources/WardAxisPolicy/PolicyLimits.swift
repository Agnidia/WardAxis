//
//  PolicyLimits.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Bounds on one policy. Together with the 64 KiB document bound of
/// ``SchemaLimits``, they cap the work an enforcement component does per flow.
public enum PolicyLimits {
    public static let maximumRuleCount = 256
    
    public static let maximumHostsPerRule = 64
    
    public static let maximumNetworksPerRule = 64
    
    public static let maximumPortRangesPerRule = 32
    
    /// A reported host name above this many UTF-8 bytes is refused before
    /// IDNA mapping, so a hostile name cannot buy unbounded work per flow
    /// (ADR 0017 D1). Four times the 253-byte DNS limit leaves room for
    /// Unicode labels that shrink when mapped.
    public static let maximumReportedHostLength = 1024
    
    /// A higher priority wins (ADR 0015 D3). The upper bound leaves room to
    /// insert a rule between two others without renumbering.
    public static let priorityRange = 0...10_000
}
