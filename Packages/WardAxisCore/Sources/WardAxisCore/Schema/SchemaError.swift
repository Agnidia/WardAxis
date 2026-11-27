//
//  SchemaError.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Why ``SchemaCodec`` refused a document.
///
/// A `path` is built from schema keys and array indexes only, such as
/// `$.body.rules[2].action`. It never carries a value or a key from the input,
/// so an error is safe to log with `privacy: .public`.
public enum SchemaError: Error, Sendable, Equatable {
    /// Over the byte or nesting bound, or not a strict JSON object (``BoundedJSON``).
    case outOfBounds
    
    /// An object repeats a key (``BoundedJSON/Verdict/duplicateKey``).
    case duplicateField
    
    /// No `schema` string or no integer `schemaVersion` in the envelope, or the
    /// document could not be decoded or encoded as JSON for another reason.
    case malformed
    
    /// The envelope names a different schema, or one this build does not know.
    case wrongKind(expected: SchemaKind)
    
    /// The envelope's version is outside what this build can read.
    case unsupportedVersion(Int, supported: ClosedRange<Int>)
    
    /// A field is missing, has the wrong JSON type, or holds an unknown enum case.
    case wrongShape(path: String)
    
    /// The object at `path` has a field that the schema does not define.
    case unknownField(path: String)
    
    /// The document decoded but breaks a rule of the schema.
    case invalid(SchemaViolation)
}

/// One broken schema rule, found by ``SchemaBody/validate()``.
public struct SchemaViolation: Error, Sendable, Equatable {
    public enum Reason: String, Sendable, Equatable {
        case malformedIdentifier
        case malformedTeamIdentifier
        case malformedHost
        case malformedNetwork
        case outOfRange
        case tooMany
        case duplicate
        case contradictory
        case missingRequired
    }
    
    public let path: String
    public let reason: Reason
    
    public init(path: String, reason: Reason) {
        self.path = path
        self.reason = reason
    }
}
