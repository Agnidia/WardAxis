//
//  CGRect+Size.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// An extension for CGRect that provides positioning of frame.
public extension CGRect {    
    /// Scales the rectangle while keeping it centered.
    ///
    /// - Parameter scale: The scaling factor to apply.
    /// - Returns: A new `CGRect` with the scaled dimensions and centered position.
    func scaleCentered(_ scale: CGFloat) -> CGRect {
        let newWidth = width * scale
        let newHeight = height * scale
        
        let centeredPoint = CGPoint(x: minX + (width - newWidth) / 2,
                                    y: minY + (height - newHeight) / 2)
        
        return .init(x: centeredPoint.x, y: centeredPoint.y,
                     width: newWidth, height: newHeight)
    }
}
