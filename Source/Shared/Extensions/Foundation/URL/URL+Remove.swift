//
//  URL+Remove.swift
//
//  Created on 10.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisTelemetry

public extension URL {
    private static let removeLogger = Log(category: .cache)
    
    /// Removes the file, folder or symbolic link at the URL if it exists.
    ///
    /// A symbolic link is removed itself, also when its target is missing.
    ///
    /// - Returns: `true` only when an existing item was removed.
    @discardableResult
    func remove() -> Bool {
        do {
            try FileManager.default.removeItem(at: self)
            return true
        } catch CocoaError.fileNoSuchFile {
            return false
        } catch {
            Self.removeLogger.error("Cannot remove item: \(error)", privacy: .private)
            return false
        }
    }
}
