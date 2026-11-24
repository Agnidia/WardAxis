//
//  DocsRouteTests.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import ServerCore
import Testing

@Suite("API reference routes")
struct DocsRouteTests {
    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // ServerTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Server
            .deletingLastPathComponent() // repository root
    }
    
    private static var contractURL: URL {
        repositoryRoot.appendingPathComponent("Packages/WardAxisManagementAPI/Sources/WardAxisAPIServer/openapi.yaml")
    }
    
    private static var vendoredDirectory: URL {
        repositoryRoot.appendingPathComponent("Server/Sources/ServerCore/Resources/APIDocs")
    }
    
    /// Literal oracles, not built from `DocsController`, so a wrong prefix fails here.
    private static let scriptPath: String = "/v1/docs/redoc/\(DocsController.redocVersion)/redoc.standalone.js"
    private static let docsPaths: [String] = ["/v1/docs", "/v1/openapi.yaml", scriptPath]
    /// The docs paths without the `/v1` prefix; none of them may answer.
    private static let unversionedDocsPaths: [String] = [
        "/docs",
        "/openapi.yaml",
        "/docs/redoc/\(DocsController.redocVersion)/redoc.standalone.js"
    ]
    
    /// Small stand-in bytes, so header tests do not depend on the 1 MB bundle.
    private static let stubDocs = APIDocs(
        openAPIDocument: ByteBuffer(string: "openapi: 3.1.0\n"),
        redocScript: ByteBuffer(string: "/* redoc */")
    )
    
    private static func application(docs: APIDocs?, environment: ServerEnvironment = .development) async throws -> some ApplicationProtocol {
        var dependencies = ServerDependencies.testing(environment: environment)
        dependencies.apiDocs = docs
        return try Application(router: buildRouter(dependencies: dependencies))
    }
    
    private static func bytes(_ buffer: ByteBuffer) -> [UInt8] {
        Array(buffer.readableBytesView)
    }
    
    // MARK: - Docs on
    
    @Test
    func `GET /v1/openapi.yaml serves the contract file's exact bytes as application/yaml`() async throws {
        let expected = try [UInt8](Data(contentsOf: Self.contractURL))
        let application = try await Self.application(docs: .bundled())
        try await application.test(.router) { client in
            let response = try await client.executeRequest(uri: "/v1/openapi.yaml", method: .get, headers: [:], body: nil)
            #expect(response.status == .ok)
            #expect(response.headers[.contentType] == "application/yaml")
            #expect(response.headers[.xContentTypeOptions] == "nosniff")
            #expect(response.headers[.cacheControl] == "no-cache")
            #expect(Self.bytes(response.body) == expected, "rebuild the server after a contract edit")
        }
    }
    
    @Test
    func `The Redoc asset serves the vendored file's exact bytes as JavaScript, cached as immutable`() async throws {
        let expected = try [UInt8](Data(contentsOf: Self.vendoredDirectory.appendingPathComponent("redoc.standalone.js")))
        let application = try await Self.application(docs: .bundled())
        try await application.test(.router) { client in
            let response = try await client.executeRequest(
                uri: Self.scriptPath,
                method: .get,
                headers: [:],
                body: nil
            )
            #expect(response.status == .ok)
            #expect(response.headers[.contentType] == "text/javascript; charset=utf-8")
            #expect(response.headers[.xContentTypeOptions] == "nosniff")
            #expect(response.headers[.cacheControl] == "public, max-age=31536000, immutable")
            #expect(Self.bytes(response.body) == expected)
        }
    }
    
    @Test
    func `GET /v1/docs serves an HTML page that loads the spec and the script from this origin only`() async throws {
        let application = try await Self.application(docs: Self.stubDocs)
        try await application.test(.router) { client in
            let response = try await client.executeRequest(uri: "/v1/docs", method: .get, headers: [:], body: nil)
            #expect(response.status == .ok)
            #expect(response.headers[.contentType] == "text/html; charset=utf-8")
            #expect(response.headers[.xContentTypeOptions] == "nosniff")
            #expect(response.headers[.cacheControl] == "no-cache")
            #expect(response.headers[HTTPField.Name("Referrer-Policy")!] == "no-referrer")
            
            let html = String(buffer: response.body)
            #expect(html.contains(#"<redoc spec-url="/v1/openapi.yaml"></redoc>"#))
            #expect(html.contains(#"<script src="/v1/docs/redoc/\#(DocsController.redocVersion)/redoc.standalone.js"></script>"#))
            #expect(html.range(of: #"(src|href)\s*=\s*"?\s*(https?:)?//"#, options: .regularExpression) == nil)
            // Every script element is an external one with an empty body: the CSP allows no inline script.
            let scriptTags = html.components(separatedBy: "<script").count - 1
            let externalEmptyScripts = html.components(separatedBy: #""></script>"#).count - 1
            #expect(scriptTags == 1)
            #expect(externalEmptyScripts == scriptTags)
            #expect(!html.contains("<link"))
        }
    }
    
    @Test
    func `GET /v1/docs sends one strict Content-Security-Policy with no remote origin and no eval`() async throws {
        let application = try await Self.application(docs: Self.stubDocs)
        try await application.test(.router) { client in
            let response = try await client.executeRequest(uri: "/v1/docs", method: .get, headers: [:], body: nil)
            let policies = response.headers[values: .contentSecurityPolicy]
            #expect(policies.count == 1)
            let policy = try #require(policies.first)
            #expect(policy == DocsController.contentSecurityPolicy)
            
            #expect(policy.contains("default-src 'self'"))
            #expect(policy.contains("worker-src blob:"))
            for forbidden in ["'unsafe-eval'", "http:", "https:", "*", "'strict-dynamic'"] {
                #expect(!policy.contains(forbidden), "CSP must not contain \(forbidden)")
            }
            
            var directives: [String: [String]] = [:]
            for directive in policy.split(separator: ";") {
                let parts = directive.split(separator: " ").map(String.init)
                let name = try #require(parts.first)
                #expect(directives[name] == nil, "\(name) appears twice")
                directives[name] = Array(parts.dropFirst())
            }
            #expect(directives["object-src"] == ["'none'"])
            #expect(directives["base-uri"] == ["'none'"])
            #expect(directives["frame-ancestors"] == ["'none'"])
            #expect(directives["script-src"] == ["'self'"])
            #expect(directives["img-src"] == ["'self'", "data:"])
            // Inline code only in style-src, data: only in img-src, and no host source anywhere.
            let keywords: Set<String> = ["'self'", "'none'", "blob:"]
            for (name, sources) in directives {
                for source in sources {
                    if source == "'unsafe-inline'" {
                        #expect(name == "style-src", "'unsafe-inline' is allowed in style-src only, found in \(name)")
                    } else if source == "data:" {
                        #expect(name == "img-src", "data: is allowed in img-src only, found in \(name)")
                    } else {
                        #expect(keywords.contains(source), "\(name) has the non-keyword source \(source)")
                    }
                }
            }
        }
    }
    
    @Test
    func `Only /docs carries the CSP; the document and the script do not need one`() async throws {
        let application = try await Self.application(docs: Self.stubDocs)
        try await application.test(.router) { client in
            for path in ["/v1/openapi.yaml", Self.scriptPath] {
                let response = try await client.executeRequest(uri: path, method: .get, headers: [:], body: nil)
                #expect(response.status == .ok)
                #expect(response.headers[.contentSecurityPolicy] == nil, "\(path)")
            }
        }
    }
    
    // MARK: - Docs off
    
    private struct ErrorBody: Decodable, Equatable {
        let code: String
        let message: String
        let requestId: String?
    }
    
    @Test(arguments: docsPaths)
    func `With docs off, each docs path answers exactly like a path that was never registered`(path: String) async throws {
        try await Self.expectUnregistered(path, application: Self.application(docs: nil))
    }
    
    @Test(arguments: docsPaths)
    func `In production, each docs path answers 404 even when the docs assets are set`(path: String) async throws {
        try await Self.expectUnregistered(path, application: Self.application(docs: Self.stubDocs, environment: .production))
    }
    
    @Test
    func `In development with the docs assets set, every docs path answers 200`() async throws {
        let application = try await Self.application(docs: Self.stubDocs, environment: .development)
        try await application.test(.router) { client in
            for path in Self.docsPaths {
                let response = try await client.executeRequest(uri: path, method: .get, headers: [:], body: nil)
                #expect(response.status == .ok, "\(path)")
            }
        }
    }
    
    @Test(arguments: unversionedDocsPaths)
    func `With docs on, each unversioned docs path answers 404`(path: String) async throws {
        try await Self.expectUnregistered(path, application: Self.application(docs: Self.stubDocs))
    }
    
    @Test
    func `A composition root that omits the environment gets production, so docs stay off`() async throws {
        let base = ServerDependencies.testing()
        let dependencies = ServerDependencies(
            databaseProbe: base.databaseProbe,
            configStore: base.configStore,
            configNotifier: base.configNotifier,
            apiDocs: Self.stubDocs
        )
        #expect(dependencies.environment == .production)
        let application = try Application(router: buildRouter(dependencies: dependencies))
        for path in Self.docsPaths {
            try await Self.expectUnregistered(path, application: application)
        }
    }
    
    /// `path` must answer exactly like a path that was never registered.
    private static func expectUnregistered(_ path: String, application: some ApplicationProtocol) async throws {
        try await application.test(.router) { client in
            let docs = try await client.executeRequest(uri: path, method: .get, headers: [:], body: nil)
            let unknown = try await client.executeRequest(uri: "/never-registered", method: .get, headers: [:], body: nil)
            
            #expect(docs.status == .notFound, "\(path)")
            #expect(docs.status == unknown.status)
            #expect(docs.headers[.contentType] == unknown.headers[.contentType])
            #expect(Set(docs.headers.map(\.name)) == Set(unknown.headers.map(\.name)))
            #expect(docs.headers[.contentSecurityPolicy] == nil)
            
            let docsBody = try decodeJSON(ErrorBody.self, from: docs.body)
            let unknownBody = try decodeJSON(ErrorBody.self, from: unknown.body)
            #expect(docsBody.code == unknownBody.code)
            #expect(docsBody.message == unknownBody.message)
            #expect((docsBody.requestId == nil) == (unknownBody.requestId == nil))
        }
    }
    
    @Test
    func `The default dependencies leave docs off`() {
        let dependencies = ServerDependencies.testing()
        #expect(dependencies.apiDocs == nil)
    }
    
    // MARK: - Provenance
    
    @Test
    func `The served Redoc version is a pinned 2.x.y release and matches the vendored files`() throws {
        let version = DocsController.redocVersion
        #expect(version.range(of: #"^2\.\d+\.\d+$"#, options: .regularExpression) != nil)
        #expect(DocsController.redocScriptPath == "/docs/redoc/\(version)/redoc.standalone.js")
        
        let provenance = try String(
            contentsOf: Self.vendoredDirectory.appendingPathComponent("PROVENANCE.md"),
            encoding: .utf8
        )
        #expect(provenance.contains("| Version | `\(version)` |"))
        #expect(provenance.contains("redoc-\(version).tgz"))
        #expect(provenance.range(of: #"`sha512-[A-Za-z0-9+/]{86}==`"#, options: .regularExpression) != nil)
        #expect(provenance.range(of: #"`[0-9a-f]{64}`"#, options: .regularExpression) != nil)
        
        let notices = try String(
            contentsOf: Self.vendoredDirectory.appendingPathComponent("redoc.standalone.js.LICENSE.txt"),
            encoding: .utf8
        )
        #expect(notices.contains(#"Version: "\#(version)""#))
        let license = try String(
            contentsOf: Self.vendoredDirectory.appendingPathComponent("redoc-LICENSE.txt"),
            encoding: .utf8
        )
        #expect(license.contains("MIT License"))
    }
}
