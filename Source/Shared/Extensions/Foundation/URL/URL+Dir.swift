//
//  URL+Dir.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

public extension URL {    
    /// Determines whether the URL represents a folder (directory).
    var isFolder: Bool {
        var isDir: ObjCBool = false
        
        FileManager.default.fileExists(atPath: path(), isDirectory: &isDir)
        
        return isDir.boolValue
    }
}
