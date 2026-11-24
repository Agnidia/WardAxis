//
//  ConfigurationLimits.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Bounds on what the feed and the cache accept.
///
/// Encoding and decoding `ConfigurationValue` recurse once per nesting level,
/// and the cache does it on a cooperative-pool thread with a small stack, so a
/// deeply nested value from the server would crash the app. Payloads past these
/// bounds are refused before any JSON decoding starts.
enum ConfigurationLimits {
    /// Deepest array or object nesting in a whole document, envelope included.
    static let maximumNestingDepth = 32

    /// Most settings one configuration may hold.
    static let maximumEntryCount = 1024

    /// Largest frame or cache file, in bytes.
    static let maximumMessageSize = 256 * 1024

    /// `true` when `data` fits the size bound, never nests deeper than
    /// ``maximumNestingDepth``, and is a strict subset of what `JSONDecoder`
    /// accepts: UTF-8 starting with `{`, no NUL byte (which would make the
    /// decoder transcode it as UTF-16 or UTF-32), valid escapes with four hex
    /// digits after `\u`, no raw control byte in a string, and balanced brackets.
    /// Anything looser would let the decoder see nesting that this scan missed.
    static func isWithinBounds(_ data: Data) -> Bool {
        guard data.count <= maximumMessageSize, data.first == UInt8(ascii: "{") else {
            return false
        }
        var depth = 0
        var isInString = false
        var isEscaped = false
        var hexDigitsLeft = 0
        for byte in data {
            if byte == 0 {
                return false
            }
            if isInString {
                if hexDigitsLeft > 0 {
                    guard isHexDigit(byte) else { return false }
                    hexDigitsLeft -= 1
                } else if isEscaped {
                    isEscaped = false
                    switch byte {
                    case UInt8(ascii: "u"):
                        hexDigitsLeft = 4
                    case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"),
                         UInt8(ascii: "b"), UInt8(ascii: "f"), UInt8(ascii: "n"), UInt8(ascii: "r"), UInt8(ascii: "t"):
                        break
                    default:
                        return false
                    }
                } else if byte == UInt8(ascii: "\\") {
                    isEscaped = true
                } else if byte == UInt8(ascii: "\"") {
                    isInString = false
                } else if byte < 0x20 {
                    return false
                }
                continue
            }
            switch byte {
            case UInt8(ascii: "\""):
                isInString = true
            case UInt8(ascii: "["), UInt8(ascii: "{"):
                depth += 1
                if depth > maximumNestingDepth {
                    return false
                }
            case UInt8(ascii: "]"), UInt8(ascii: "}"):
                depth -= 1
                if depth < 0 {
                    return false
                }
            default:
                break
            }
        }
        return !isInString && depth == 0
    }

    /// `true` when `values` encodes to at most ``maximumMessageSize`` bytes, so a
    /// run of deltas cannot grow the configuration past what a snapshot may carry.
    static func fitsByteLimit(_ values: [String: ConfigurationValue]) -> Bool {
        guard let data = try? JSONEncoder().encode(values) else {
            return false
        }
        return data.count <= maximumMessageSize
    }

    private static func isHexDigit(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "a")...UInt8(ascii: "f"), UInt8(ascii: "A")...UInt8(ascii: "F"):
            true
        default:
            false
        }
    }
}
