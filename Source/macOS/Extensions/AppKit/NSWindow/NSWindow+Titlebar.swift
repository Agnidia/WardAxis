//
//  NSWindow+Titlebar.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if os(macOS)

import AppKit

/// An extension to the `NSWindow` class to provide additional functionalities
/// regarding the appearance and behavior of windows in macOS applications.
public extension NSWindow {    
    /// Hides the top shadow of the window, providing a cleaner and flatter appearance.
    ///
    /// This method searches through the window's subviews to find the view responsible
    /// for rendering the top shadow and then removes it from the view hierarchy, thus
    /// hiding the shadow. It makes use of the class name suffix `NSTitlebarContainerView` to identify
    /// the correct view.
    func hideTopShadow() {
        // define the class name suffix for the titlebar container view
        let titlebarContainerViewName = "NSTitlebarContainerView"
        
        // find the view with the specified class name suffix in the subviews of the content view's superview
        guard let titlebarContainerView = contentView?.superview?.subviews.first(where: { $0.className.hasSuffix(titlebarContainerViewName) }) else {
            // exit the function if the view couldn't be found
            return
        }
        
        // remove the found view from the superview, effectively hiding the top shadow of the window
        titlebarContainerView.removeFromSuperview()
    }
    
    /// Hides the title bar of the window to offer a more immersive and clean user interface.
    ///
    /// This method sets several properties of the window to effectively hide the title bar.
    /// The title visibility is set to hidden, the title bar appears transparent, the background color is set to clear,
    /// and shadow is enabled to maintain a sense of depth.
    func hideTitleBar() {
        // set the title visibility to hidden to hide the title text
        titleVisibility = .hidden
        
        // set the title bar to appear transparent, hiding the bar while keeping the buttons (if any)
        titlebarAppearsTransparent = true
        
        // set the background color to clear to remove any background color from the title bar area
        backgroundColor = .clear
        
        // enable shadow to maintain a sense of depth around the window
        hasShadow = true
    }
}

#endif
