//
//  DecodableDictionaryTests.swift
//
//  Created on 10.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
@testable import WardAxis

@Suite("Decodable init(dictionary:)")
struct DecodableDictionaryTests {
    private struct Sample: Decodable, Equatable {
        let name: String
        let count: Int
        let date: Date
    }

    @Test("Decodes values and an ISO8601 date")
    func decodesDictionary() throws {
        let sample = try Sample(dictionary: ["name": "a", "count": 3, "date": "2026-01-02T03:04:05Z"])

        #expect(sample == Sample(name: "a", count: 3, date: Date(timeIntervalSince1970: 1_767_323_045)))
    }

    @Test("Throws for a dictionary JSONSerialization cannot encode")
    func rejectsNonJSONValues() {
        #expect(throws: JSONDecoderError.self) {
            try Sample(dictionary: ["name": "a", "count": 3, "date": Date()])
        }
    }

    @Test("Throws for a missing key")
    func rejectsMissingKey() {
        #expect(throws: DecodingError.self) {
            try Sample(dictionary: ["name": "a"])
        }
    }
}
