//
//  RequestBodyLimitTests.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import NIOCore
import NIOEmbedded
import ServerCore
import Testing

@Suite("Request body limit")
struct RequestBodyLimitTests {
    private static let limit: Int = RequestBodyLimitMiddleware.defaultLimit
    
    @Test("A body one byte over the limit with Content-Length answers 413 with a request ID")
    func declaredLengthOverLimit() async throws {
        let application = try makeTestApplication()
        try await application.test(.router) { client in
            // The router test client sets Content-Length from the body. The limit runs
            // before routing, so it holds for every path.
            try await client.execute(
                uri: "/v1/health",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(repeating: UInt8(ascii: " "), count: Self.limit + 1)
            ) { response in
                #expect(response.status == .contentTooLarge)
                #expect(response.headers[RequestIDMiddleware.headerName] != nil)
            }
        }
    }

    @Test("A chunked body without Content-Length that grows past the limit answers 413")
    func streamedBodyOverLimit() async throws {
        let request = Self.streamedRequest(chunks: 5, chunkSize: 16 * 1024)
        var nextWasCalled = false
        
        let response = try await Self.limitChain(request) { _, _ in
            nextWasCalled = true
            return Response(status: .ok)
        }
        
        #expect(response.status == .contentTooLarge)
        #expect(response.headers[RequestIDMiddleware.headerName] != nil)
        #expect(!nextWasCalled)
    }
    
    @Test("A chunked body within the limit reaches the route in full")
    func streamedBodyWithinLimit() async throws {
        let request = Self.streamedRequest(chunks: 3, chunkSize: 1024)
        
        let response = try await Self.limitChain(request) { request, _ in
            let body = try await request.body.collect(upTo: .max)
            #expect(body.readableBytes == 3 * 1024)
            return Response(status: .ok)
        }
        
        #expect(response.status == .ok)
    }
    
    @Test("A body at the limit passes the middleware and reaches routing")
    func bodyAtLimitPasses() async throws {
        let application = try makeTestApplication()
        try await application.test(.router) { client in
            try await client.execute(
                uri: "/v1/health",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(repeating: UInt8(ascii: " "), count: Self.limit)
            ) { response in
                // The router's 404 for an unregistered method, so the body got through the limit.
                #expect(response.status == .notFound)
            }
        }
    }
    
    // MARK: - Helpers
    
    /// A POST whose body arrives as separate chunks, with no Content-Length header.
    private static func streamedRequest(chunks: Int, chunkSize: Int) -> Request {
        let stream = AsyncStream<ByteBuffer> { continuation in
            for _ in 0..<chunks {
                continuation.yield(ByteBuffer(repeating: UInt8(ascii: " "), count: chunkSize))
            }
            continuation.finish()
        }
        let head = HTTPRequest(
            method: .post,
            scheme: "http",
            authority: "localhost",
            path: "/v1/health",
            headerFields: [.contentType: "application/json"]
        )
        return Request(head: head, body: RequestBody(asyncSequence: stream))
    }
    
    /// Runs the production order: request ID outside the body limit, then `route`.
    private static func limitChain(
        _ request: Request,
        route: (Request, AppRequestContext) async throws -> Response
    ) async throws -> Response {
        let source = ApplicationRequestContextSource(channel: EmbeddedChannel(), logger: Logger(label: "test"))
        let context = AppRequestContext(source: source)
        return try await RequestIDMiddleware().handle(request, context: context) { request, context in
            try await RequestBodyLimitMiddleware().handle(request, context: context, next: route)
        }
    }
}
