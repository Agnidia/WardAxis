//
//  SplitMix64.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// Seeded generator, so a failing property reproduces from the seed in its message.
/// Every choice reads the raw stream; `Int.random(in:using:)` may change its mapping.
struct SplitMix64: RandomNumberGenerator {
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
}
