//
//  SecureItemStoreProtocol.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

public enum SecureItemStoreError: Error, Sendable, Equatable {
    /// The stored item exists but cannot be decoded. It will never become readable.
    case unreadable
    
    /// The OS refused the operation. The item may be fine and readable later,
    /// for example after the first unlock.
    case osStatus(Int32)
    
    /// This store keeps nothing, so it cannot save. Its loads find no item and
    /// its deletes succeed.
    case unavailable
    
    case markerUnavailable
}

/// A value kept in a secure item store.
///
/// The store writes `{"v": payloadVersion, "value": …}`. An item under any other
/// version is unreadable and gets deleted, so a format change never half-decodes
/// a secret. Conformers that hold secret material must redact it from
/// `description`, `debugDescription` and `customMirror`.
public protocol SecurePayload: Codable, Sendable, Equatable {
    static var payloadVersion: Int { get }
}

/// One item, at most, per store.
public protocol SecureItemStoreProtocol<Value>: Sendable {
    associatedtype Value: SecurePayload
    
    /// The stored value, or `nil` when no item exists.
    func load() throws(SecureItemStoreError) -> Value?
    
    /// Creates or replaces the stored value.
    func save(_ value: Value) throws(SecureItemStoreError)
    
    /// Removes the stored value. A missing item is success.
    func delete() throws(SecureItemStoreError)
}

public enum SecurePayloadCoding {
    private struct Header: Decodable {
        let v: Int
    }
    
    private struct Envelope<Value: SecurePayload>: Codable {
        let v: Int
        let value: Value
    }
    
    public static func encode<Value: SecurePayload>(_ value: Value) throws(SecureItemStoreError) -> Data {
        do {
            return try JSONEncoder().encode(Envelope(v: Value.payloadVersion, value: value))
        } catch {
            throw .unreadable
        }
    }
    
    /// - Throws: ``SecureItemStoreError/unreadable`` for bad JSON or another version.
    public static func decode<Value: SecurePayload>(_ data: Data, as _: Value.Type = Value.self) throws(SecureItemStoreError) -> Value {
        do {
            // The version is checked before the value is decoded, so an old
            // layout is never read with the new type's defaults.
            guard try JSONDecoder().decode(Header.self, from: data).v == Value.payloadVersion else {
                throw SecureItemStoreError.unreadable
            }
            return try JSONDecoder().decode(Envelope<Value>.self, from: data).value
        } catch {
            throw .unreadable
        }
    }
}
