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
    
    /// A higher priority wins (ADR 0015 D3). The upper bound leaves room to
    /// insert a rule between two others without renumbering.
    public static let priorityRange = 0...10_000
}
