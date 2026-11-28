//
//  PolicyRule+Fixture.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import WardAxisCore
import WardAxisPolicy

public extension PolicyRule {
    /// A rule with a fixed identifier and priority, for tests that vary only
    /// the action, the criteria and whether the rule is enabled.
    static func fixture(
        _ action: PolicyAction = .deny,
        match: PolicyMatch,
        enabled: Bool = true,
        identifier: String = "r1",
        priority: Int = 100
    ) -> PolicyRule {
        PolicyRule(identifier: identifier, priority: priority, enabled: enabled, action: action, match: match)
    }
}
