//
//  Logger+Safety.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Logging

package extension Logger {
    /// A copy that logs at `notice` or above only. Below it PostgresNIO logs bind
    /// values and connection errors in full, and at `trace` protocol messages that
    /// include row data and the SCRAM exchange.
    func cappedForPostgres() -> Logger {
        var capped = self
        capped.logLevel = Swift.max(logLevel, .notice)
        return capped
    }
}

package extension Logger.Metadata {
    /// The error's type only. A driver or I/O error's description can carry
    /// connection details, paths or input, so no log line quotes one.
    static func errorType(_ error: any Error) -> Logger.Metadata {
        ["error.type": "\(type(of: error))"]
    }
}
