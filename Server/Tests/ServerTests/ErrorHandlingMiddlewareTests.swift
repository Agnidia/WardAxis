//
//  ErrorHandlingMiddlewareTests.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import Logging
import ServerCore
import Testing

/// The decoded `ErrorResponse` body, for assertions.
@Suite("Error handling middleware")
struct ErrorHandlingMiddlewareTests {
    /// A distinctive type name and message that must never reach a body or a log line.
    private struct SampleDatabaseMeltdown: Error, CustomStringConvertible {
        var description: String {
            "SELECT secret_column FROM hidden_table"
        }
    }
    
    /// The production router plus routes that fail on purpose.
    private static func application(logger: Logger = Logger(label: "test")) throws -> some ApplicationProtocol {
        let router = try buildRouter(dependencies: .testing())
        router.get("/test/meltdown") { _, _ -> Response in throw SampleDatabaseMeltdown() }
        router.get("/test/forbidden") { _, _ -> Response in throw HTTPError(.forbidden, message: "hidden detail") }
        return Application(router: router, logger: logger)
    }
    
    private static func expectErrorBody(_ response: TestResponse, status: HTTPResponse.Status, code: String) throws {
        #expect(response.status == status)
        #expect(response.headers[.contentType]?.hasPrefix("application/json") == true)
        #expect(response.headers[.cacheControl] == "no-store")
        let body = try decodeJSON(ErrorBody.self, from: response.body)
        #expect(body.code == code)
        let requestID = try #require(response.headers[RequestIDMiddleware.headerName])
        #expect(body.requestId == requestID)
        let text = String(buffer: response.body)
        for leak in ["SampleDatabaseMeltdown", "secret_column", "hidden detail", "DecodingError"] {
            #expect(!text.contains(leak))
        }
    }
    
    @Test
    func `A non-HTTP error answers 500 internal_error; the log has its type, not its text`() async throws {
        let capture = LogCapture()
        let application = try Self.application(logger: capture.makeLogger())
        try await application.test(.router) { client in
            let response = try await client.executeRequest(uri: "/test/meltdown", method: .get, headers: [:], body: nil)
            try Self.expectErrorBody(response, status: .internalServerError, code: "internal_error")
        }
        let failure = try #require(capture.records.first { $0.message == "Request failed" })
        #expect(failure.level == .error)
        #expect(failure.metadata["error.type"] == "SampleDatabaseMeltdown")
        #expect(failure.metadata[RequestIDMiddleware.metadataKey] != nil)
        #expect(!capture.records.contains { $0.renderedText.contains("secret_column") })
    }
    
    @Test
    func `A body over 64 KiB answers 413 with an ErrorResponse`() async throws {
        let application = try Self.application()
        try await application.test(.router) { client in
            let response = try await client.executeRequest(
                uri: "/v1/health",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(repeating: UInt8(ascii: " "), count: RequestBodyLimitMiddleware.defaultLimit + 1)
            )
            try Self.expectErrorBody(response, status: .contentTooLarge, code: "payload_too_large")
        }
    }
    
    @Test
    func `An HTTPError keeps its status, drops its message; an unknown route answers not_found`() async throws {
        let application = try Self.application()
        try await application.test(.router) { client in
            let forbidden = try await client.executeRequest(uri: "/test/forbidden", method: .get, headers: [:], body: nil)
            try Self.expectErrorBody(forbidden, status: .forbidden, code: "invalid_request")
            let missing = try await client.executeRequest(uri: "/no-such-route", method: .get, headers: [:], body: nil)
            try Self.expectErrorBody(missing, status: .notFound, code: "not_found")
        }
    }
    
    @Test
    func `Classification: an APIError wins, an HTTP status error maps to its contract code, anything else is 500`() {
        let invalid = APIError.invalidRequest(message: "The request must upgrade to a WebSocket.")
        #expect(ErrorHandlingMiddleware.classify(invalid).0 == invalid)
        #expect(ErrorHandlingMiddleware.classify(SampleDatabaseMeltdown()).0 == .internalError)
        #expect(ErrorHandlingMiddleware.classify(HTTPError(.notFound)).0.code == "not_found")
        #expect(ErrorHandlingMiddleware.classify(HTTPError(.contentTooLarge)).0.code == "payload_too_large")
    }
}
