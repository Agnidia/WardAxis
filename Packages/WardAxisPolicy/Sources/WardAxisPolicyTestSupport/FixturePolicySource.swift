//
//  FixturePolicySource.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisCore
import WardAxisPolicy

/// Serves a policy from encoded bytes, through ``SchemaCodec`` on every call,
/// so a consumer under test meets the same refusals as with a real source.
public struct FixturePolicySource: PolicySourceProtocol {
    private let data: Data
    
    public init(data: Data) {
        self.data = data
    }
    
    public func currentPolicy() async throws(SchemaError) -> SecurityPolicy {
        try SchemaCodec.decode(SecurityPolicy.self, from: data)
    }
}
