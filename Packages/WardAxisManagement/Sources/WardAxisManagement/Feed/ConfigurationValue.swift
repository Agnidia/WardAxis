//
//  ConfigurationValue.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// One configuration value: any JSON value.
///
/// Decoding tries `Bool`, then an integer, then a floating-point number, the
/// same order as the generated client's `OpenAPIValueContainer`, so a value
/// keeps its kind when it passes through both. A number with no fractional
/// part, such as `1.0`, therefore becomes ``integer(_:)``.
public enum ConfigurationValue: Sendable, Hashable, Codable {
    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([ConfigurationValue])
    case object([String: ConfigurationValue])
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Backstop for the byte pre-scan: decoding recurses once per level.
        guard decoder.codingPath.count <= ConfigurationLimits.maximumNestingDepth else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Nested too deep")
        }
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([ConfigurationValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: ConfigurationValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}
