//
//  NSScreen+Frame.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if os(macOS)

import AppKit

public extension NSScreen {
    /// Retrieve the screen that serves as the origin screen (with the origin at CGPoint.zero).
    static var originScreen: NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.origin == CGPoint.zero {
                return screen
            }
        }
        
        return nil
    }
    
    /// Calculate the frame of the screen including the Dock and menu bar.
    var frameWithDockAndMenu: CGRect {
        if let primaryScreen = NSScreen.originScreen {
            var frame = frame
            frame.origin.y = NSHeight(primaryScreen.frame) - NSHeight(frame) - frame.origin.y
            return frame
        }
        
        return frame
    }
    
    /// Calculate the frame of the screen excluding the Dock and menu bar.
    var frameWithoutDockOrMenu: CGRect {
        if let primaryScreen = NSScreen.originScreen {
            var frame = visibleFrame
            frame.origin.y = NSHeight(primaryScreen.frame) - NSHeight(frame) - frame.origin.y
            return frame
        }
        
        return frame
    }
}

#endif
