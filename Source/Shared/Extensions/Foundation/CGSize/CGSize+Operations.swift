//
//  CGSize+Operations.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CoreFoundation

/// An extension for CGSize that adds addition for two CGSize instances.
public extension CGSize {    
    /// Adds two CGSize instances by summing their respective widths and heights.
    ///
    /// - Parameters:
    ///   - left: The first CGSize to add.
    ///   - right: The second CGSize to add.
    /// - Returns: A new CGSize resulting from the addition.
    static func + (left: CGSize, right: CGSize) -> CGSize {
        .init(width: left.width + right.width, height: left.height + right.height)
    }
}
