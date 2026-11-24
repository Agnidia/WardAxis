//
//  APIRedirectRefusal.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Session delegate that refuses every HTTP redirect for the API session.
///
/// A 307 or 308 would replay the request body, and the TLS client identity, to
/// whatever host the `Location` header names. The contract lists no 3xx for any
/// operation, so the 3xx response is handed back unfollowed and fails closed.
///
/// It applies only to tasks without their own delegate, which is why the
/// transport must run in buffered mode (plain data tasks).
public final class APIRedirectRefusal: NSObject, URLSessionTaskDelegate, Sendable {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
