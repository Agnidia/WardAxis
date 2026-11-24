//
//  CGSize+Name.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CoreFoundation

/// An extension for CGSize that provides a string representation of the size.
public extension CGSize {    
    /// A human-readable string representation of the size in the format "width x height".
    var name: String {
        "\(Int(width)) x \(Int(height))"
    }
}
