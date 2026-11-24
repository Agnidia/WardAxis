//
//  JSONEncoder+Dictionary.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

public enum JSONEncoderError: Error {
    case dataError
    case dictionaryError
}

/// An extension for `JSONEncoder` that provides a method for converting encodable objects to dictionaries.
public extension JSONEncoder {    
    /// Converts an encodable object to a dictionary.
    ///
    /// This method encodes the provided encodable object to JSON, then parses the JSON data into a dictionary.
    ///
    /// - Parameter dto: The encodable object to convert.
    /// - Returns: A dictionary representation of the encodable object.
    /// - Throws:
    ///   - `JSONEncoderError.dataError`: If there is an error encoding the object to JSON data.
    ///   - `JSONEncoderError.dictionaryError`: If there is an error parsing the JSON data into a dictionary.
    func dictionary(_ dto: Encodable) throws -> [String: Any] {
        // Set the output formatting to pretty printed for readability
        outputFormatting = .prettyPrinted
        
        // Encode the object to JSON
        let json = String(bytes: try! encode(dto), encoding: .utf8)!
        
        // Convert the JSON to data
        guard let data = json.data(using: String.Encoding.utf8) else {
            throw JSONEncoderError.dataError
        }
        
        // Parse the JSON data into a dictionary
        let dictionary = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any]
        
        // Ensure the dictionary is not empty
        guard let dictionary, dictionary.isEmpty == false else {
            throw JSONEncoderError.dictionaryError
        }
        
        return dictionary
    }
}
