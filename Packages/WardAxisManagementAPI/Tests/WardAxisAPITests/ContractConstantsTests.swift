//
//  ContractConstantsTests.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisAPIContract

/// The hand-written contract values against the spec text, so an edit to one
/// without the other fails here and not as a server/client mismatch.
@Suite("Hand-written contract values")
struct ContractConstantsTests {
    private static func specText() throws -> String {
        let spec = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "../../Sources/WardAxisAPIServer/openapi.yaml")
            .standardized
        return try String(contentsOf: spec, encoding: .utf8)
    }
    
    @Test
    func `The stream path is a path in the spec`() throws {
        #expect(try Self.specText().contains("\n  /\(ConfigStream.path):\n"))
    }
    
    @Test
    func `The spec lists exactly the error codes the server sends`() throws {
        let listed = APIErrorCode.all.map { "`\($0)`" }.joined(separator: ", ")
        let flattened = try Self.specText().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(flattened.contains("Known codes: \(listed)."))
    }
    
    @Test
    func `The spec states the close codes, the lifetime reason and the frame bound`() throws {
        let spec = try Self.specText().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        for code in [
            ConfigStreamCloseCode.normalClosure,
            ConfigStreamCloseCode.goingAway,
            ConfigStreamCloseCode.policyViolation,
            ConfigStreamCloseCode.internalError,
            ConfigStreamCloseCode.tryAgainLater
        ] {
            #expect(spec.contains("close code \(code)") || spec.contains("Close code \(code)"), "\(code)")
        }
        #expect(spec.contains("reason `\(ConfigStream.lifetimeReason)`"))
        #expect(spec.contains("at most \(ConfigStreamLimits.maximumFrameBytes) bytes"))
        #expect(spec.contains("nests at most \(ConfigStreamLimits.maximumNestingDepth) levels"))
    }
    
    @Test(arguments: ["/v1", "/api/v1"])
    func `A versioned base path is valid`(path: String) {
        #expect(APIBasePathRule.isValid(path))
    }
    
    @Test(arguments: ["", "/", "v1", "/v1/", "//v1", "/v1//x"])
    func `An unversioned, relative, trailing or doubled base path is invalid`(path: String) {
        #expect(!APIBasePathRule.isValid(path))
    }
}
