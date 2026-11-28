//
//  RoutePrefixTests.swift
//
//  Created on 16.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import HTTPTypes
import Hummingbird
import HummingbirdTesting
import NIOCore
import ServerCore
import Testing

/// Every route the router registers is under `/v1`, and nothing answers outside it.
///
/// The oracles are the versioned route list as literal strings, not values built from
/// `APIBasePath`, so a wrong prefix source fails here.
@Suite("Route prefix")
struct RoutePrefixTests {
    private static let docsRoutes: Set<String> = [
        "GET /v1/openapi.yaml",
        "GET /v1/docs",
        "GET /v1/docs/redoc/2.5.4/redoc.standalone.js"
    ]
    
    private static let apiRoutes: Set<String> = [
        "GET /v1/health",
        "GET /v1/config/stream"
    ]
    
    private static func dependencies(environment: ServerEnvironment) -> ServerDependencies {
        var dependencies = ServerDependencies.testing(environment: environment)
        dependencies.apiDocs = APIDocs.stub
        return dependencies
    }
    
    private static func registeredRoutes(
        environment: ServerEnvironment,
        clientCertificates: ClientCertificateVerification = .required
    ) throws -> [String] {
        try buildRouter(dependencies: dependencies(environment: environment), clientCertificates: clientCertificates)
            .routes.map { "\($0.method.rawValue) \($0.path)" }
    }
    
    /// Each route of the versioned list without its `/v1` prefix; none of them may answer.
    private static var unversionedRoutes: [String] {
        (apiRoutes.union(docsRoutes)).map { $0.replacingOccurrences(of: " /v1/", with: " /") }.sorted()
    }
    
    @Test
    func `With docs on in development and client certificates required, the registered routes are exactly the versioned route list, each under /v1/`() throws {
        let routes = try Self.registeredRoutes(environment: .development)
        #expect(routes.count == 5)
        #expect(Set(routes) == Self.apiRoutes.union(Self.docsRoutes))
        for route in routes {
            let path = try #require(route.split(separator: " ").last)
            #expect(path.hasPrefix("/v1/"), "\(route)")
        }
    }
    
    @Test
    func `In production, the same dependencies register every route but the docs routes`() throws {
        let routes = try Self.registeredRoutes(environment: .production)
        #expect(Set(routes) == Self.apiRoutes)
        #expect(routes.count == Self.apiRoutes.count)
    }
    
    @Test
    func `Without client-certificate verification the config stream route is not registered at all`() throws {
        let routes = try Self.registeredRoutes(environment: .production, clientCertificates: .off)
        #expect(Set(routes) == ["GET /v1/health"])
    }
    
    @Test(
        arguments: unversionedRoutes
    )
    func `Each unversioned path answers the router's own 404 ErrorResponse with no redirect`(route: String) async throws {
        let parts = route.split(separator: " ").map(String.init)
        let method = try #require(HTTPRequest.Method(parts[0]))
        let path = parts[1]
        let hasBody = method == .post || method == .patch
        let application = try Application(router: buildRouter(dependencies: Self.dependencies(environment: .development), clientCertificates: .required))
        try await application.test(.router) { client in
            let response = try await client.executeRequest(
                uri: path,
                method: method,
                headers: hasBody ? [.contentType: "application/json"] : [:],
                body: hasBody ? ByteBuffer(string: "{}") : nil
            )
            #expect(response.status == .notFound)
            #expect(response.headers[.location] == nil)
            #expect(response.headers[.contentType]?.hasPrefix("application/json") == true)
            let body = try decodeJSON(ErrorBody.self, from: response.body)
            #expect(body.code == "not_found")
            #expect(body.message == "The resource does not exist.")
        }
    }
}
