//
//  URL+List.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

public extension URL {
    /// Gets the names of all direct children, hidden ones included, of the directory at the URL.
    var fileNameList: [String]? {
        contents(skipsHiddenFiles: false)?.map(\.lastPathComponent)
    }
}

public extension URL {
    /// Gets the regular files below the directory at the URL, recursively.
    ///
    /// Hidden files and package contents are skipped. Directories are not included.
    var recursiveFileList: [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: self,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        
        return enumerator.compactMap { element in
            guard let url = element as? URL,
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
            else {
                return nil
            }
            return url
        }
    }
    
    /// Gets the direct children (files and folders) of the directory at the URL.
    ///
    /// - Parameter skipsHiddenFiles: Excludes hidden items when `true`.
    /// - Returns: The child URLs, or `nil` if the directory cannot be read.
    func contents(skipsHiddenFiles: Bool = true) -> [URL]? {
        try? FileManager.default.contentsOfDirectory(
            at: self,
            includingPropertiesForKeys: nil,
            options: skipsHiddenFiles ? .skipsHiddenFiles : []
        )
    }
}
