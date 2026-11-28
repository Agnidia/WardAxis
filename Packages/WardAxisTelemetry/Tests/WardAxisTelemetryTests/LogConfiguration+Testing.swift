//
//  LogConfiguration+Testing.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

@testable import WardAxisTelemetry

extension Log.Configuration {
    /// No categories, no file output, the base level: only the arguments vary.
    static func testing(
        label: String = "",
        consoleEmojis: [Log.Level: String] = [:],
        dateDisplayStyle: DateDisplayStyle = .none
    ) -> Self {
        .init(
            categoryStates: [:],
            label: label,
            consoleEmojis: consoleEmojis,
            saveToFileByDefault: false,
            fileLogLevel: .base,
            dateDisplayStyle: dateDisplayStyle
        )
    }
}
