//
//  NSWindow+Center.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if os(macOS)

import AppKit

public extension NSWindow {    
    /// Centers the window horizontally at the bottom of the screen with an optional vertical offset.
    ///
    /// - Parameters:
    ///   - offsetY: The vertical offset from the bottom of the screen. The default value is 32.
    func centerBottomOnScreen(offsetY: CGFloat = 32) {
        guard let screen else {
            return
        }
        
        // Get the screen and window frame details
        let screenFrame = screen.visibleFrame
        let windowFrame = frame
        
        // Calculate the new origin for the window to center it horizontally at the bottom of the screen
        let xPosition = (screenFrame.width - windowFrame.width) / 2
        let yPosition = screenFrame.minY + offsetY
        let origin = NSPoint(x: xPosition, y: yPosition)
        
        // Set the new origin as the frame origin of the window
        setFrameOrigin(origin)
    }
    
    func centerOnScreen() {
        guard let screen else {
            return
        }
        
        // Get the screen and window frame details
        let screenFrame = screen.frameWithDockAndMenu
        let windowFrame = frame
        let safeAreaHeight = screen.frameWithoutDockOrMenu.height - screenFrame.height
        
        // Calculate the new origin for the window to center it horizontally at the bottom of the screen
        let xPosition = screenFrame.width / 2 - windowFrame.width / 2
        let yPosition = screenFrame.height / 2 - windowFrame.height / 2 - safeAreaHeight / 3
        let origin = NSPoint(x: xPosition, y: yPosition)
        
        // Set the new origin as the frame origin of the window
        setFrameOrigin(origin)
    }
}

#endif
