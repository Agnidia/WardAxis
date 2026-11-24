//
//  RequestLoggingTests.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Hummingbird
import HummingbirdTesting
import ServerCore
import Testing

@Suite("Request ID and request logging")
struct RequestLoggingTests {
    private static let requestCompleted: String = "Request completed"
    
    @Test("A request without X-Request-ID gets a generated ID in the response and in its log lines")
    func generatedRequestIDMatchesLogs() async throws {
        let capture = LogCapture()
        let application = try makeTestApplication(logger: capture.makeLogger())
        
        let responseID: String? = try await application.test(.router) { client in
            try await client.execute(uri: "/v1/health", method: .get) { response in
                response.headers[RequestIDMiddleware.headerName]
            }
        }
        
        let requestID = try #require(responseID)
        #expect(UUID(uuidString: requestID) != nil)
        let completed = capture.records.filter { $0.message == Self.requestCompleted }
        #expect(completed.count == 1)
        for record in completed {
            #expect(record.metadata[RequestIDMiddleware.metadataKey] == .string(requestID))
            #expect(record.metadata["http.method"] == "GET")
            #expect(record.metadata["http.route"] == "/v1/health")
            #expect(record.metadata["http.status"] == "200")
        }
    }
    
    @Test("Credentials, cookies, query strings and bodies never reach the log")
    func credentialsAreNotLogged() async throws {
        let capture = LogCapture()
        let application = try makeTestApplication(logger: capture.makeLogger())
        let bearerToken = "sample-bearer-token-7f3a9c"
        let cookieValue = "sample-session-cookie-41d2"
        let queryValue = "sample-query-token-c81e"
        let bodyValue = "sample-body-token-90ab"
        let inboundID = "upstream-proxy.id_42"
        
        let responseID: String? = try await application.test(.router) { client in
            try await client.execute(
                uri: "/v1/health?token=\(queryValue)",
                method: .get,
                headers: [
                    .authorization: "Bearer \(bearerToken)",
                    .cookie: "session=\(cookieValue)",
                    .contentType: "application/json",
                    RequestIDMiddleware.headerName: inboundID
                ],
                body: ByteBuffer(string: #"{"refreshToken":"\#(bodyValue)"}"#)
            ) { response in
                response.headers[RequestIDMiddleware.headerName]
            }
        }
        
        #expect(responseID == inboundID)
        let records = capture.records
        #expect(records.contains { $0.message == Self.requestCompleted })
        for record in records {
            let text = record.renderedText
            #expect(!text.contains(bearerToken))
            #expect(!text.contains(cookieValue))
            #expect(!text.contains(queryValue))
            #expect(!text.contains(bodyValue))
        }
        let completed = try #require(records.first { $0.message == Self.requestCompleted })
        #expect(completed.metadata[RequestIDMiddleware.metadataKey] == .string(inboundID))
        #expect(completed.metadata["http.route"] == "/v1/health")
    }
    
    @Test(
        "An unsafe inbound X-Request-ID is replaced",
        arguments: [
            "has space",
            "line\u{7F}break",
            "quote\"injection",
            String(repeating: "a", count: RequestIDMiddleware.maximumLength + 1)
        ]
    )
    func unsafeRequestIDIsReplaced(inboundID: String) async throws {
        let application = try makeTestApplication()
        let responseID: String? = try await application.test(.router) { client in
            try await client.execute(
                uri: "/v1/health",
                method: .get,
                headers: [RequestIDMiddleware.headerName: inboundID]
            ) { response in
                response.headers[RequestIDMiddleware.headerName]
            }
        }
        
        let requestID = try #require(responseID)
        #expect(requestID != inboundID)
        #expect(UUID(uuidString: requestID) != nil)
    }
    
    @Test("Error responses carry the request ID too")
    func errorResponseCarriesRequestID() async throws {
        let capture = LogCapture()
        let application = try makeTestApplication(logger: capture.makeLogger())
        
        let responseID: String? = try await application.test(.router) { client in
            try await client.execute(uri: "/no-such-route", method: .get) { response in
                #expect(response.status == .notFound)
                return response.headers[RequestIDMiddleware.headerName]
            }
        }
        
        let requestID = try #require(responseID)
        let completed = try #require(capture.records.first { $0.message == Self.requestCompleted })
        #expect(completed.metadata[RequestIDMiddleware.metadataKey] == .string(requestID))
        #expect(completed.metadata["http.status"] == "404")
        // The route template, never the attacker-chosen raw path.
        #expect(completed.metadata["http.route"] == "NotFound")
    }
}
