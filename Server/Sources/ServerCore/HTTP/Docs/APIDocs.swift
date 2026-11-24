//
//  APIDocs.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import NIOCore

/// The bytes the docs routes serve, loaded once before the listener binds.
///
/// Responses share these buffers, so a request allocates nothing for the body.
package struct APIDocs: Sendable {
    /// The contract the server was built from, byte for byte.
    package let openAPIDocument: ByteBuffer
    /// The vendored Redoc bundle at ``DocsController/redocVersion``.
    package let redocScript: ByteBuffer

    package init(openAPIDocument: ByteBuffer, redocScript: ByteBuffer) {
        self.openAPIDocument = openAPIDocument
        self.redocScript = redocScript
    }

    /// The embedded contract and the script from the `ServerCore` resource bundle.
    ///
    /// Traps when the script is missing: that is a packaging defect, the same failure
    /// class as a missing bundle inside `Bundle.module`. It runs only when docs are on,
    /// and before the listener binds, so no request ever sees a half-loaded state.
    package static func bundled() -> APIDocs {
        let resourceName = "redoc.standalone.js"
        guard let url = Bundle.module.url(forResource: "redoc.standalone", withExtension: "js") else {
            fatalError("\(resourceName) is missing from the ServerCore resource bundle")
        }
        let script: Data
        do {
            script = try Data(contentsOf: url)
        } catch {
            fatalError("\(resourceName) in the ServerCore resource bundle is unreadable")
        }
        return APIDocs(
            openAPIDocument: ByteBuffer(bytes: PackageResources.openapi_yaml),
            redocScript: ByteBuffer(bytes: script)
        )
    }
}
