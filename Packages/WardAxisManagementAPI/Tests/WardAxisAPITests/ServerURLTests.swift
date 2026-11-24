//
//  ServerURLTests.swift
//
//  Created on 16.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import WardAxisAPIClient
import Foundation
import Testing

/// The generated `Servers` value is the only source of the `/v1` prefix for the app and
/// the server, so it is pinned here.
@Suite("Contract servers URL")
struct ServerURLTests {
    @Test("The contract's only server is the relative path /v1, with no host and no trailing slash")
    func serverIsVersionedPath() throws {
        let url = try Servers.Server1.url()
        #expect(url.absoluteString == "/v1")
        #expect(url.path(percentEncoded: true) == "/v1")
        #expect(url.host() == nil)
        #expect(url.scheme == nil)
    }
}
