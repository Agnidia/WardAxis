//
//  HealthController.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Hummingbird

/// Serves `GET /v1/health`, a hand-written route outside the OpenAPI contract.
///
/// `200` when the database answers, `503` otherwise, so orchestrators and load
/// balancers take an instance without a database out of rotation.
package struct HealthController: Sendable {
    /// Relative to the group ``buildRouter(dependencies:)`` passes.
    package static let path: String = "/health"
    
    // `any`: the probe is the DB-free test seam; one dynamic call per probe is negligible.
    private let probe: any DatabaseHealthProbe
    
    package init(probe: any DatabaseHealthProbe) {
        self.probe = probe
    }
    
    package func addRoutes(to group: RouterGroup<AppRequestContext>) {
        group.get(RouterPath(Self.path)) { _, _ in
            await check()
        }
    }
    
    package func check() async -> EditedResponse<HealthStatus> {
        if await probe.isReachable() {
            EditedResponse(status: .ok, response: .ok)
        } else {
            EditedResponse(status: .serviceUnavailable, response: .unavailable)
        }
    }
}
