//
//  SchemaCodec.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// The only way to read or write a schema document.
///
/// Decoding fails closed, in this order: byte, depth and duplicate-key checks, envelope kind,
/// envelope version, typed shape, unknown fields, then ``SchemaBody/validate()``.
/// The version is checked before the body is decoded, so a newer document is
/// refused as ``SchemaError/unsupportedVersion(_:supported:)`` and never read
/// with the rules of an older one.
public enum SchemaCodec {
    public static func decode<Body: SchemaBody>(_: Body.Type, from data: Data) throws(SchemaError) -> Body {
        switch BoundedJSON.scan(data, maximumSize: SchemaLimits.maximumDocumentSize, maximumDepth: SchemaLimits.maximumNestingDepth) {
        case .accepted:
            break
        case .outOfBounds:
            throw .outOfBounds
        case .duplicateKey:
            throw .duplicateField
        }
        let decoder = makeDecoder()
        let envelope: Envelope
        do {
            envelope = try decoder.decode(Envelope.self, from: data)
        } catch {
            throw .malformed
        }
        guard envelope.schema == Body.schemaKind.rawValue else {
            throw .wrongKind(expected: Body.schemaKind)
        }
        guard Body.supportedVersions.contains(envelope.schemaVersion) else {
            throw .unsupportedVersion(envelope.schemaVersion, supported: Body.supportedVersions)
        }
        let document: SchemaDocument<Body>
        do {
            document = try decoder.decode(SchemaDocument<Body>.self, from: data)
        } catch let error as DecodingError {
            throw .wrongShape(path: path(of: error))
        } catch {
            throw .malformed
        }
        try requireKnownFields(in: data, decoded: document)
        do {
            try document.body.validate()
        } catch {
            throw .invalid(error)
        }
        return document.body
    }
    
    /// Validates `body` and writes it at ``SchemaBody/currentVersion`` with sorted keys.
    public static func encode(_ body: some SchemaBody) throws(SchemaError) -> Data {
        do {
            try body.validate()
        } catch {
            throw .invalid(error)
        }
        let data: Data
        do {
            data = try makeEncoder().encode(SchemaDocument(body: body))
        } catch {
            throw .malformed
        }
        // A writer must never produce what a reader would refuse.
        guard BoundedJSON.isWithinBounds(data, maximumSize: SchemaLimits.maximumDocumentSize, maximumDepth: SchemaLimits.maximumNestingDepth) else {
            throw .outOfBounds
        }
        return data
    }
    
    /// Refuses a body decode that did not start in ``SchemaCodec``, so a plain
    /// `JSONDecoder` cannot skip the bounds, version, field and rule checks.
    static func requireCodec(_ decoder: any Decoder) throws {
        guard decoder.userInfo[codecKey] is CodecMarker else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Decode through SchemaCodec"))
        }
    }
    
    // MARK: - Private
    
    /// Outside this module the type cannot be named, so no other decoder can carry it.
    private struct CodecMarker: Sendable {}
    
    private static let codecKey = CodingUserInfoKey(rawValue: "com.agnidia.wardaxis.schema-codec")!
    
    private struct Envelope: Decodable {
        let schema: String
        let schemaVersion: Int
    }
    
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.userInfo[codecKey] = CodecMarker()
        // `.iso8601` also accepts fractions and offsets that the encoder rewrites,
        // so a time must already be in the one form the encoder writes.
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            let style = Date.ISO8601FormatStyle()
            guard let date = try? Date(text, strategy: style), date.formatted(style) == text else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a whole-second UTC ISO 8601 time")
            }
            return date
        }
        return decoder
    }
    
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
    
    /// `Codable` skips keys it does not know, so a misspelled optional field such
    /// as `"applicaton"` would silently widen a rule. The input's key tree must
    /// therefore be a subset of the key tree that the decoded value writes back.
    /// An explicit `null` for an optional field is refused too: absence is the
    /// only way to omit one.
    private static func requireKnownFields(in data: Data, decoded document: SchemaDocument<some SchemaBody>) throws(SchemaError) {
        let input: JSONShape
        let known: JSONShape
        do {
            input = try JSONDecoder().decode(JSONShape.self, from: data)
            known = try JSONDecoder().decode(JSONShape.self, from: makeEncoder().encode(document))
        } catch {
            throw .malformed
        }
        if let path = input.firstUnknownField(comparedWith: known, at: SchemaPath.root) {
            throw .unknownField(path: path)
        }
    }
    
    private static func path(of error: DecodingError) -> String {
        let codingPath: [any CodingKey] = switch error {
        case .keyNotFound(let key, let context):
            context.codingPath + [key]
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            context.codingPath
        @unknown default:
            []
        }
        return codingPath.reduce(SchemaPath.root) { path, key in
            key.intValue.map { SchemaPath.index(path, $0) } ?? SchemaPath.member(path, key)
        }
    }
}

/// The key structure of a JSON document, without its values.
private indirect enum JSONShape: Decodable {
    case leaf
    case array([JSONShape])
    case object([String: JSONShape])
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil()
            || (try? container.decode(Bool.self)) != nil
            || (try? container.decode(Double.self)) != nil
            || (try? container.decode(String.self)) != nil
        {
            self = .leaf
        } else if let object = try? container.decode([String: JSONShape].self) {
            self = .object(object)
        } else {
            // An error here fails the check; never fall back to `.leaf`, which has no keys to compare.
            self = try .array(container.decode([JSONShape].self))
        }
    }
    
    /// The path of the first object, in key order, that holds a key `known` lacks.
    func firstUnknownField(comparedWith known: JSONShape, at path: String) -> String? {
        switch (self, known) {
        case (.object(let fields), .object(let knownFields)):
            for key in fields.keys.sorted() {
                guard let knownField = knownFields[key] else {
                    return path
                }
                // Only a known key reaches the path, never one from the input.
                if let found = fields[key]?.firstUnknownField(comparedWith: knownField, at: SchemaPath.member(path, key)) {
                    return found
                }
            }
            return nil
        case (.array(let elements), .array(let knownElements)):
            guard elements.count == knownElements.count else {
                return path
            }
            for (index, pair) in zip(elements, knownElements).enumerated() {
                if let found = pair.0.firstUnknownField(comparedWith: pair.1, at: SchemaPath.index(path, index)) {
                    return found
                }
            }
            return nil
        case (.leaf, .leaf):
            return nil
        default:
            // The typed decode accepted a shape that it writes back differently.
            return path
        }
    }
}
