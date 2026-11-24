//
//  String+XCAsset.swift
//
//  Created on 02.11.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension String {
    /// Decodes JSON data stored as a Data asset in the asset catalog into a Codable model.
    /// - Parameter type: The Codable type to decode into.
    /// - Returns: An instance of the specified Codable type.
    /// - Throws: An error if the asset is missing or decoding fails.
    /// - Complexity: Time O(n), Space O(n), where n is the size of JSON data.
    func createModelFromAsset<T: Codable>(type: T.Type) throws -> T {
        guard let dataAsset = NSDataAsset(name: self) else {
            throw NSError(domain: "String+Codable", code: 404, userInfo: [NSLocalizedDescriptionKey: "Asset named '\(self)' not found"])
        }
        return try JSONDecoder().decode(T.self, from: dataAsset.data)
    }
}
