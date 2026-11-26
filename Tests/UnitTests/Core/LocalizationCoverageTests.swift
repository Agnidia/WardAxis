//
//  LocalizationCoverageTests.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing

/// The OS picks one table for the user's language and does not fall back to the
/// development language per key, so a partly translated language shows raw keys.
@Suite("Localization coverage")
struct LocalizationCoverageTests {
    private static let developmentLanguage = "en"

    private static var shippedLanguages: [String] {
        Bundle.main.localizations.filter { $0 != "Base" && $0 != developmentLanguage }
    }

    private static func keys(for language: String) -> Set<String> {
        guard let url = Bundle.main.url(
                  forResource: "Localizable",
                  withExtension: "strings",
                  subdirectory: nil,
                  localization: language
              ),
              let table = NSDictionary(contentsOf: url) as? [String: Any]
        else {
            return []
        }
        return Set(table.keys)
    }

    @Test
    func `The development language ships a non-empty table`() {
        #expect(!Self.keys(for: Self.developmentLanguage).isEmpty)
    }

    @Test(arguments: shippedLanguages)
    func `Every shipped language translates every key`(language: String) {
        let missing = Self.keys(for: Self.developmentLanguage).subtracting(Self.keys(for: language))

        #expect(missing.isEmpty, "\(language) has no translation for \(missing.sorted())")
    }
}
