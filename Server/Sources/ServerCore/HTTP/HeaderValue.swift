//
//  HeaderValue.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// Response header values that several routes send.
package enum HeaderValue {
    /// The browser must not guess a content type, so a body is never run as a script it is not.
    package static let noSniff: String = "nosniff"
    
    /// Cached copies must be revalidated, so a redeploy is seen at once.
    package static let revalidate: String = "no-cache"
    
    /// Never stored: error bodies can be specific to one request.
    package static let noStore: String = "no-store"
    
    package static let json: String = "application/json; charset=utf-8"
}
