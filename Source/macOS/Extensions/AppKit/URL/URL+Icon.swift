//
//  URL+Icon.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if os(macOS)

import AppKit

public extension URL {    
    /// Gets an `NSImage` representing the icon associated with the URL.
    var icon: NSImage? {        
        let workspace = NSWorkspace.shared
        
        let img: NSImage = if #unavailable(macOS 13) {
            workspace.icon(forFile: path)
        } else {
            workspace.icon(forFile: path())
        }
        
        // Icon for a folder without an icon
        let emptyIcon = workspace.icon(for: .item)
        
        // Return the default folder icon if the icon is the same as the empty icon
        if img.tiffRepresentation == emptyIcon.tiffRepresentation {
            return workspace.icon(for: .folder)
        }
        
        return img
    }
}

#endif
