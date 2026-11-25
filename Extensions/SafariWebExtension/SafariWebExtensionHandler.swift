//
//  SafariWebExtensionHandler.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Packaging shell for the Safari Web Extension native handler.
///
/// Trust boundary: messages from extension scripts that run in web content, so
/// every message is untrusted. The shell decodes nothing and cancels each request.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        context.cancelRequest(withError: CocoaError(.featureUnsupported))
    }
}
