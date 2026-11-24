//
//  JSONDecoder+Decodable.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

public enum JSONDecoderError: Error {
    case dataError
}

/// An extension for `JSONDecoder` that provides convenient methods for decoding JSON data.
public extension JSONDecoder {    
    /// Decodes JSON data into a specific decodable object of the given type.
    ///
    /// - Parameters:
    ///   - type: The type of the decodable object to decode.
    ///   - data: The JSON data to be decoded.
    /// - Returns: An instance of the specified type.
    /// - Throws: An error if decoding fails.
    static func make<T: Decodable>(_ type: T.Type, data: Data) throws -> T {
        try jsonDecoder().decode(T.self, from: data)
    }
    
    /// Decodes JSON text into a specific decodable object of the given type.
    ///
    /// - Parameters:
    ///   - type: The type of the decodable object to decode.
    ///   - json: The JSON text to be decoded.
    ///   - encoding: The string encoding used to decode the JSON text (default is UTF-8).
    /// - Returns: An instance of the specified type.
    /// - Throws: An error if decoding fails.
    static func make<T: Decodable>(_ type: T.Type, json: String, using encoding: String.Encoding = .utf8) throws -> T {
        guard let data = json.data(using: encoding) else {
            throw JSONDecoderError.dataError
        }
        return try make(T.self, data: data)
    }
    
    /// Creates a standard JSON decoder with ISO8601 date decoding strategy.
    ///
    /// - Returns: A JSONDecoder instance.
    static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public extension Decodable {
    /// Decodes a value from a JSON-compatible dictionary.
    ///
    /// Uses ``JSONDecoder/jsonDecoder()`` so dates decode as ISO8601.
    ///
    /// - Parameter dictionary: A dictionary that `JSONSerialization` accepts.
    /// - Throws: `JSONDecoderError.dataError` for non-JSON values, or a decoding error.
    init(dictionary: [String: Any]) throws {
        // JSONSerialization raises an Objective-C exception, not a Swift error, on invalid input.
        guard JSONSerialization.isValidJSONObject(dictionary) else {
            throw JSONDecoderError.dataError
        }
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        self = try JSONDecoder.jsonDecoder().decode(Self.self, from: data)
    }
}
