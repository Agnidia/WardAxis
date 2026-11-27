//
//  BoundedJSON.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Byte-level pre-scan that runs before any `JSONDecoder` sees untrusted data.
///
/// `Codable` decoding recurses once per nesting level, often on a
/// cooperative-pool thread with a small stack, so deep nesting from an
/// untrusted peer could crash the process. The scan is iterative and refuses a
/// payload before decoding starts.
public enum BoundedJSON {
    public enum Verdict: Sendable, Equatable {
        case accepted
        case outOfBounds
        
        /// An object repeats a key. `JSONDecoder` keeps the first copy while
        /// other parsers keep the last, so two readers of the same bytes would
        /// see different values.
        case duplicateKey
    }
    
    /// `true` when ``scan(_:maximumSize:maximumDepth:)`` accepts `data`.
    public static func isWithinBounds(_ data: Data, maximumSize: Int, maximumDepth: Int) -> Bool {
        scan(data, maximumSize: maximumSize, maximumDepth: maximumDepth) == .accepted
    }
    
    /// Accepts `data` only when it is at most `maximumSize` bytes, never nests
    /// deeper than `maximumDepth`, repeats no key within an object, and is a
    /// strict subset of what `JSONDecoder` accepts: UTF-8 starting with `{`, no
    /// NUL byte (which would make the decoder transcode it as UTF-16 or UTF-32),
    /// valid escapes with four hex digits after `\u`, no raw control byte in a
    /// string, and matching brackets. Anything looser would let the decoder see
    /// structure that this scan missed.
    public static func scan(_ data: Data, maximumSize: Int, maximumDepth: Int) -> Verdict {
        guard data.count <= maximumSize, data.first == UInt8(ascii: "{") else {
            return .outOfBounds
        }
        var containers: [Container] = []
        var isInString = false
        var isEscaped = false
        var hasEscape = false
        var hexDigitsLeft = 0
        var stringBytes: [UInt8] = []
        var isKey = false
        var isComplete = false
        for byte in data {
            if byte == 0 {
                return .outOfBounds
            }
            if isInString {
                if hexDigitsLeft > 0 {
                    guard ASCII.isHexDigit(byte) else { return .outOfBounds }
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
                        return .outOfBounds
                    }
                } else if byte == UInt8(ascii: "\\") {
                    isEscaped = true
                    hasEscape = true
                } else if byte == UInt8(ascii: "\"") {
                    isInString = false
                    if isKey {
                        isKey = false
                        guard let key = normalizedKey(stringBytes, hasEscape: hasEscape) else {
                            return .outOfBounds
                        }
                        guard containers[containers.count - 1].insert(key) else {
                            return .duplicateKey
                        }
                    }
                    continue
                } else if byte < 0x20 {
                    return .outOfBounds
                }
                if isKey {
                    stringBytes.append(byte)
                }
                continue
            }
            if isComplete {
                // Only whitespace may follow the root object.
                guard [UInt8(ascii: " "), UInt8(ascii: "\n"), UInt8(ascii: "\r"), UInt8(ascii: "\t")].contains(byte) else {
                    return .outOfBounds
                }
                continue
            }
            switch byte {
            case UInt8(ascii: "\""):
                isInString = true
                hasEscape = false
                isKey = containers.last?.isExpectingKey ?? false
                stringBytes.removeAll(keepingCapacity: true)
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                guard containers.count < maximumDepth else {
                    return .outOfBounds
                }
                containers.append(byte == UInt8(ascii: "{") ? .object(keys: [], isExpectingKey: true) : .array)
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                guard let last = containers.popLast(), last.isObject == (byte == UInt8(ascii: "}")) else {
                    return .outOfBounds
                }
                isComplete = containers.isEmpty
            case UInt8(ascii: ","):
                guard !containers.isEmpty else {
                    return .outOfBounds
                }
                containers[containers.count - 1].expectKey()
            default:
                break
            }
        }
        return !isInString && containers.isEmpty ? .accepted : .outOfBounds
    }
    
    // MARK: - Private
    
    private enum Container {
        case object(keys: Set<String>, isExpectingKey: Bool)
        case array
        
        var isObject: Bool {
            if case .object = self {
                true
            } else {
                false
            }
        }
        
        var isExpectingKey: Bool {
            if case .object(_, let isExpectingKey) = self {
                isExpectingKey
            } else {
                false
            }
        }
        
        /// `false` when the object already holds `key`.
        mutating func insert(_ key: String) -> Bool {
            guard case .object(var keys, _) = self else {
                return true
            }
            let isNew = keys.insert(key).inserted
            self = .object(keys: keys, isExpectingKey: false)
            return isNew
        }
        
        mutating func expectKey() {
            if case .object(let keys, _) = self {
                self = .object(keys: keys, isExpectingKey: true)
            }
        }
    }
    
    /// The key as the decoder sees it, so `"a"` and `"a"` count as the same key.
    private static func normalizedKey(_ bytes: [UInt8], hasEscape: Bool) -> String? {
        guard hasEscape else {
            return String(bytes: bytes, encoding: .utf8)
        }
        let quoted = Data([UInt8(ascii: "\"")] + bytes + [UInt8(ascii: "\"")])
        return try? JSONDecoder().decode(String.self, from: quoted)
    }
}
