//
//  SchemaBody.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// The names a document can carry in its `schema` field.
public enum SchemaKind: String, Sendable, Codable, CaseIterable {
    case securityEvent = "wardaxis.security-event"
    case securityPolicy = "wardaxis.security-policy"
    case applicationIdentity = "wardaxis.application-identity"
}

/// A type that travels as the `body` of a ``SchemaDocument``.
///
/// The document's version governs the body and every type nested in it, so
/// nested types carry no version of their own.
public protocol SchemaBody: Sendable, Equatable, Codable {
    static var schemaKind: SchemaKind { get }
    
    /// The versions this build decodes. A version outside it is refused, never guessed.
    static var supportedVersions: ClosedRange<Int> { get }
    
    /// The version this build writes.
    static var currentVersion: Int { get }
    
    /// Checks the rules that `Codable` cannot express. ``SchemaCodec`` calls it
    /// on every decode and encode.
    func validate() throws(SchemaViolation)
}

/// The envelope of every schema document.
///
/// ```json
/// {"schema": "wardaxis.security-policy", "schemaVersion": 1, "body": {...}}
/// ```
public struct SchemaDocument<Body: SchemaBody>: Sendable, Equatable, Codable {
    public let schema: SchemaKind
    public let schemaVersion: Int
    public let body: Body
    
    public init(body: Body) {
        schema = Body.schemaKind
        schemaVersion = Body.currentVersion
        self.body = body
    }
}

/// The schema versions this build knows.
public enum SchemaVersion {
    public static let v1 = 1
    public static let onlyV1 = v1...v1
}

/// Bounds on one schema document and its fields.
public enum SchemaLimits {
    public static let maximumDocumentSize = 64 * 1024
    
    /// Deepest array or object nesting, envelope included.
    public static let maximumNestingDepth = 16
    
    /// Most events one ``SecurityEventSourceProtocol`` batch may hold.
    public static let maximumBatchSize = 256
    
    /// The lowest policy revision; `0` is never issued, so it cannot pass as "no policy yet".
    public static let minimumRevision: Int64 = 1
    
    /// Longest policy or rule identifier, in bytes.
    public static let maximumIdentifierLength = 128
    
    /// Longest code-signing or bundle identifier, in bytes.
    public static let maximumSigningIdentifierLength = 255
    
    /// An Apple Developer Team ID has exactly this many bytes.
    public static let teamIdentifierLength = 10
    
    /// Longest host name, in bytes (RFC 1035).
    public static let maximumHostNameLength = 253
    
    /// Longest label of a host name, in bytes (RFC 1035).
    public static let maximumHostLabelLength = 63
    
    public static let validPorts = 1...65_535
    
    /// The longest IPv6 text without an IPv4 tail: eight groups of four hex digits and seven colons.
    public static let maximumIPv6TextLength = 8 * 4 + 7
}
