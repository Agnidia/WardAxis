//
//  SeededGenerator.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// SplitMix64: the same seed gives the same sequence on every platform and
/// run, so a synthetic fixture failure reproduces from its seed. Not for
/// anything that needs unpredictability.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    
    public init(seed: UInt64) {
        state = seed
    }
    
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
    
    /// A value in `0..<upperBound`, from one raw draw. Unlike `Int.random(in:using:)`,
    /// the mapping is fixed here, so a toolchain update cannot change the stream.
    public mutating func next(below upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }
    
    public mutating func nextBool() -> Bool {
        next() & 1 == 1
    }
    
    /// A version 4 UUID built from the next 128 bits.
    public mutating func nextUUID() -> UUID {
        let high = next()
        let low = next()
        var bytes = withUnsafeBytes(of: high.bigEndian) { Array($0) } + withUnsafeBytes(of: low.bigEndian) { Array($0) }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
