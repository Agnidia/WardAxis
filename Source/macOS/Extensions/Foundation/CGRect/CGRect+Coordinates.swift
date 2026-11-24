//
//  CGRect+Coordinates.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if os(macOS)

import AppKit

public extension CGRect {
    /// NSRect or CGRect's signiture is => { x, y, width, height }
    /// Silica uses top-left corner of the main screen as origin and
    /// (x, y) refers to top-left corner of a window.
    /// However Cocoa uses bottom-left corner of the main screen
    /// as origin (increasing bottom to top) and bottom-left corner
    /// of a window as (x, y).
    ///
    /// This method converts between top-left <=> bottom-left (in both ways)
    ///
    /// Primary screen is the screen at index 0, that contains
    /// the menu bar and whose origin is at the point (0, 0).
    func topLeft2bottomLeft(_ primaryScreen: NSScreen) -> CGRect {
        .init(x: origin.x,
              y: primaryScreen.frame.height - height - origin.y,
              width: width,
              height: height)
    }
    
    func inLocalPosition(on screen: NSScreen) -> CGRect {
        .init(origin: .init(x: minX - screen.frame.origin.x,
                            y: minY - screen.frame.origin.y),
              size: size)
    }
}

#endif
