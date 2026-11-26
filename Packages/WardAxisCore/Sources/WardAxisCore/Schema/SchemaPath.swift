//
//  SchemaPath.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Builds the paths that ``SchemaError`` and ``SchemaViolation`` report.
///
/// Members come from a type's `CodingKeys`, so a path always names the real
/// JSON key and never a key taken from the input.
enum SchemaPath {
    static let root = "$"
    static let body = member(root, "body")
    
    static func member(_ path: String, _ key: some CodingKey) -> String {
        member(path, key.stringValue)
    }
    
    static func member(_ path: String, _ name: String) -> String {
        "\(path).\(name)"
    }
    
    static func index(_ path: String, _ index: Int) -> String {
        "\(path)[\(index)]"
    }
}
