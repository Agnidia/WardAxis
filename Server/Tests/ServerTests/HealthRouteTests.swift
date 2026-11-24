//
//  HealthRouteTests.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Hummingbird
import HummingbirdTesting
import ServerCore
import Testing

@Suite("GET /v1/health")
struct HealthRouteTests {
    @Test("A reachable database answers 200 with an ok JSON body")
    func databaseReachable() async throws {
        let application = try makeTestApplication(databaseReachable: true)
        try await application.test(.router) { client in
            try await client.execute(uri: "/v1/health", method: .get) { response in
                #expect(response.status == .ok)
                #expect(response.headers[.contentType]?.hasPrefix("application/json") == true)
                let body = try decodeJSON(HealthStatus.self, from: response.body)
                #expect(body == HealthStatus(status: "ok", database: "ok"))
            }
        }
    }
    
    @Test("An unreachable database answers 503 with an unavailable JSON body")
    func databaseUnreachable() async throws {
        let application = try makeTestApplication(databaseReachable: false)
        try await application.test(.router) { client in
            try await client.execute(uri: "/v1/health", method: .get) { response in
                #expect(response.status == .serviceUnavailable)
                #expect(response.headers[.contentType]?.hasPrefix("application/json") == true)
                let body = try decodeJSON(HealthStatus.self, from: response.body)
                #expect(body == HealthStatus(status: "unavailable", database: "unreachable"))
            }
        }
    }
}
