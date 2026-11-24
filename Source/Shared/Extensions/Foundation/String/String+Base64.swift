//
//  String+Base64.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// An extension for `String` that provides methods for encoding and decoding base64 data.
public extension String {
    /// Decodes a base64-encoded string into its original string representation.
    ///
    /// - Returns: The original string if decoding is successful, or `nil` if the base64-encoded string is invalid.
    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// Encodes the string to a base64 representation.
    ///
    /// - Returns: A base64-encoded string.
    func toBase64() -> String {
        Data(utf8).base64EncodedString()
    }
}
