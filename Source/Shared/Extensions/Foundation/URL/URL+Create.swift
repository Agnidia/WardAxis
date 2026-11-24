//
//  URL+Create.swift
//
//  Created on 10.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

public extension URL {
    /// Creates the folder at the URL, with intermediates, when it does not exist yet.
    ///
    /// An existing folder is kept as is.
    ///
    /// - Returns: `true` when the folder exists after the call.
    @discardableResult
    func createDir() -> Bool {
        FileManager.default.secureSafeCreateDirectory(at: self)
    }
}
