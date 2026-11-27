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
    
    /// The longest zone after `%` that a reported IPv6 address may carry.
    public static let maximumZoneLength = 16
    
    /// A reported address above this many UTF-8 bytes is refused before parsing
    /// (ADR 0018 N5). The longest legitimate form fits: a bracketed IPv6 with an
    /// IPv4 tail, the RFC 6874 `%25` delimiter and a zone.
    public static let maximumReportedAddressLength = bracketedIPv6WithIPv4TailLength + "%25".utf8.count + maximumZoneLength
    
    /// `[` + six groups of four hex digits with their colons + a dotted IPv4 + `]`.
    private static let bracketedIPv6WithIPv4TailLength = 1 + 6 * 5 + 15 + 1
    
    /// A higher priority wins (ADR 0015 D3). The upper bound leaves room to
    /// insert a rule between two others without renumbering.
    public static let priorityRange = 0...10_000
}
