//
//  CGSize+Compare.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import CoreFoundation

/// An extension for CGSize that provides comparison operators for size comparison.
extension CGSize {    
    /// Checks if the size is greater than another size in either width or height.
    ///
    /// - Parameters:
    ///   - left: The first `CGSize` to compare.
    ///   - right: The second `CGSize` to compare against.
    /// - Returns: `true` if the left size is greater than the right size in either width or height, `false` otherwise.
    static func > (left: CGSize, right: CGSize) -> Bool {
        left.width > right.width || left.height > right.height
    }
    
    /// Checks if the size is less than another size in both width and height.
    ///
    /// - Parameters:
    ///   - left: The first `CGSize` to compare.
    ///   - right: The second `CGSize` to compare against.
    /// - Returns: `true` if the left size is less than the right size in both width and height, `false` otherwise.
    static func < (left: CGSize, right: CGSize) -> Bool {
        left.width < right.width && left.height < right.height
    }
    
    /// Checks if the size is greater than or equal to another size in either width or height.
    ///
    /// - Parameters:
    ///   - left: The first `CGSize` to compare.
    ///   - right: The second `CGSize` to compare against.
    /// - Returns: `true` if the left size is greater than or equal to the right size in either width or height, `false` otherwise.
    static func >= (left: CGSize, right: CGSize) -> Bool {
        left.width >= right.width || left.height >= right.height
    }
    
    /// Checks if the size is less than or equal to another size in both width and height.
    ///
    /// - Parameters:
    ///   - left: The first `CGSize` to compare.
    ///   - right: The second `CGSize` to compare against.
    /// - Returns: `true` if the left size is less than or equal to the right size in both width and height, `false` otherwise.
    static func <= (left: CGSize, right: CGSize) -> Bool {
        left.width <= right.width && left.height <= right.height
    }
}
