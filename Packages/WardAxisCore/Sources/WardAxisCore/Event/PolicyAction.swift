//
//  PolicyAction.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// What a policy decides for a flow. Events report it, so it lives here; the
/// policy models in `WardAxisPolicy` use the same type.
public enum PolicyAction: String, Sendable, Hashable, Codable {
    case allow
    case deny
}
