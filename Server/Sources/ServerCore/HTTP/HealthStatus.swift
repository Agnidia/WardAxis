//
//  HealthStatus.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Hummingbird

/// The `GET /v1/health` response body.
package struct HealthStatus: ResponseCodable, Equatable {
    package static let ok: HealthStatus = .init(status: "ok", database: "ok")
    package static let unavailable: HealthStatus = .init(status: "unavailable", database: "unreachable")
    
    package let status: String
    package let database: String
    
    package init(status: String, database: String) {
        self.status = status
        self.database = database
    }
}
