//
//  ManagedConfiguration+Schema.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisCore

public extension ManagedConfiguration {
    /// The value at `key`, read as a typed schema document.
    ///
    /// The feed bounds a value only in size and depth, so a consumer reads it
    /// through this method and never walks the ``ConfigurationValue`` tree as
    /// rules (TM5). `nil` means the key is absent; any other shape throws.
    func document<Body: SchemaBody>(_ type: Body.Type, forKey key: String) throws(SchemaError) -> Body? {
        guard let value = values[key] else {
            return nil
        }
        let data: Data
        do {
            data = try JSONEncoder().encode(value)
        } catch {
            throw .malformed
        }
        return try SchemaCodec.decode(type, from: data)
    }
}
