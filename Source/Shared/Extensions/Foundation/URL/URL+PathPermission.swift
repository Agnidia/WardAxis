//
//  URL+PathPermission.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

public extension URL {
    /// Checks if the URL has both read and write access permissions.
    var hasAccess: Bool {
        let fm = FileManager.default
        
        // Request access to the security-scoped resource.
        let _ = startAccessingSecurityScopedResource()
        
        // Check if the URL is both readable and writable.
        let hasAccess = fm.isReadableFile(atPath: path) && fm.isWritableFile(atPath: path)
        
        // Stop accessing the security-scoped resource.
        stopAccessingSecurityScopedResource()
        
        return hasAccess
    }
}
