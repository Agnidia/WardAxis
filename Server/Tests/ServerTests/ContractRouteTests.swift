//
//  ContractRouteTests.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Hummingbird
import HummingbirdTesting
import ServerCore
import Testing

/// The router against the contract. The operation list comes from the shipped spec, so a
/// spec change that the router does not follow fails here without a test edit.
@Suite("Contract routes")
struct ContractRouteTests {
    /// Each contract operation with the hand-written route that serves it. A new operation
    /// fails ``everyOperationHasARoute`` until it is mounted and listed here.
    private static let mountedOperations: [String: String] = [
        "streamConfig": "GET /v1/config/stream"
    ]
    
    @Test
    func `The spec scan finds an operation under every path of the contract`() throws {
        let spec = try OpenAPISecurityScanner.shippedSpec()
        // The contract's only two-space keys that start with a slash are its paths.
        let paths = spec.split(separator: "\n")
            .filter { $0.hasPrefix("  /") && $0.hasSuffix(":") }
            .map { String($0.dropFirst(2).dropLast()) }
        let operations = OpenAPISecurityScanner.operations(in: spec)
        #expect(!paths.isEmpty)
        #expect(Set(operations.map(\.path)) == Set(paths))
    }
    
    @Test
    func `Every contract operation is a registered route under /v1 when client certificates are required`() throws {
        let operations = try OpenAPISecurityScanner.operations(in: OpenAPISecurityScanner.shippedSpec())
        #expect(Set(operations.map(\.operationID)) == Set(Self.mountedOperations.keys))
        let routes = try Set(
            buildRouter(dependencies: .testing(), clientCertificates: .required).routes.map { "\($0.method.rawValue) \($0.path)" }
        )
        for operation in operations {
            let expected = "\(operation.method.uppercased()) \(operation.requestPath)"
            #expect(Self.mountedOperations[operation.operationID] == expected, "\(operation.operationID)")
            #expect(routes.contains(expected), "\(expected)")
        }
    }
    
    @Test
    func `Every contract operation requires mutual TLS and nothing else; no bearer scheme remains`() throws {
        let spec = try OpenAPISecurityScanner.shippedSpec()
        for operation in OpenAPISecurityScanner.operations(in: spec) {
            #expect(operation.security == .schemes(["mutualTLS"]), "\(operation.operationID)")
        }
        #expect(spec.contains("    mutualTLS:\n      type: mutualTLS\n"))
        #expect(!spec.lowercased().contains("bearer"))
    }
    
    @Test
    func `The contract's servers path is /v1, the prefix the router serves every route under`() throws {
        let spec = try OpenAPISecurityScanner.shippedSpec()
        #expect(OpenAPISecurityScanner.serverPath(in: spec) == "/v1")
        #expect(try APIBasePath.resolve() == "/v1")
        let operations = OpenAPISecurityScanner.operations(in: spec)
        #expect(operations.allSatisfy { $0.requestPath == "/v1" + $0.path && !$0.path.hasPrefix("/v1/") })
    }
    
    @Test
    func `The base path accepts a rooted path without a trailing slash and refuses every other form`() throws {
        #expect(try APIBasePath.validate("/v1") == "/v1")
        #expect(try APIBasePath.validate("/api/v1") == "/api/v1")
        for invalid in ["", "/", "v1", "/v1/", "//v1", "/api//v1"] {
            #expect(throws: APIBasePath.InvalidPath(path: invalid), "\(invalid)") {
                try APIBasePath.validate(invalid)
            }
        }
    }
    
    @Test
    func `Without client-certificate verification GET /v1/config/stream answers 404 not_found, with or without an Authorization header`() async throws {
        let application = try makeTestApplication(clientCertificates: .off)
        try await application.test(.router) { client in
            for headers: HTTPFields in [[:], [.authorization: "Bearer sample-token"], [.upgrade: "websocket"]] {
                let response = try await client.executeRequest(uri: "/v1/config/stream", method: .get, headers: headers, body: nil)
                #expect(response.status == .notFound)
                #expect(try decodeJSON(ErrorBody.self, from: response.body).code == "not_found")
            }
        }
    }
    
    @Test
    func `A mounted stream route on a connection without TLS refuses before the upgrade with 500, never serving the feed`() async throws {
        // A composition error (route mounted, listener verifies nothing): the admission
        // check is the second gate and must hold on its own.
        let application = try makeTestApplication(clientCertificates: .required)
        try await application.test(.router) { client in
            let response = try await client.executeRequest(
                uri: "/v1/config/stream",
                method: .get,
                headers: [.upgrade: "websocket", .authorization: "Bearer sample-token"],
                body: nil
            )
            #expect(response.status == .internalServerError)
            #expect(try decodeJSON(ErrorBody.self, from: response.body).code == "internal_error")
        }
    }
}
