//
//  GoldenConfigFrame.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Golden `ConfigMessage` frames in the server encoder's canonical form (compact JSON, keys
/// sorted at every level, ASCII only, no `/`); every contract consumer must reproduce them.
public enum GoldenConfigFrame: String, CaseIterable, Sendable {
    case snapshot
    case delta
    case heartbeat
    
    public var expectedVersion: Int64 {
        switch self {
        case .snapshot:
            41
        case .delta:
            42
        case .heartbeat:
            // 2^53 + 1: a decoder that goes through `Double` cannot hold it exactly.
            9_007_199_254_740_993
        }
    }
    
    /// The bytes without the file's trailing newline. Throws only when the bundle lacks the
    /// frame file; a consumer that does not carry the bundle traps in `Bundle.module` instead.
    public func data() throws -> Data {
        guard let url = Bundle.module.url(forResource: "config-frame-\(rawValue)", withExtension: "json", subdirectory: "Frames") else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        var bytes = try Data(contentsOf: url)
        while let last = bytes.last, last == UInt8(ascii: "\n") || last == UInt8(ascii: "\r") || last == UInt8(ascii: " ") || last == UInt8(ascii: "\t") {
            bytes.removeLast()
        }
        return bytes
    }
}
