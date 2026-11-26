//
//  EdgeInsets+Zero.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

public extension EdgeInsets {    
    /// A predefined `EdgeInsets` instance with zero offset on all sides.
    static let zero = create(.zero)
    
    /// Creates an `EdgeInsets` with equal offsets on all sides.
    ///
    /// - Parameter offset: The offset to apply to all sides (top, leading, bottom, trailing).
    /// - Returns: An `EdgeInsets` instance with equal offsets on all sides.
    static func create(_ offset: CGFloat) -> EdgeInsets {
        .init(top: offset, leading: offset, bottom: offset, trailing: offset)
    }
}
