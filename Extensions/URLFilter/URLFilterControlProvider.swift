//
//  URLFilterControlProvider.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import ExtensionFoundation
import Foundation
import NetworkExtension

/// Packaging shell for the URL filter control provider.
///
/// Trust boundary: the prefilter the system uses to judge URLs. `start` throws, so
/// the system loads no prefilter, and `fetchPrefilter` offers none.
@main
struct URLFilterControlProvider: NEURLFilterControlProvider {
    init() {}
    
    func start() async throws {
        throw CocoaError(.featureUnsupported)
    }
    
    func stop(reason _: NEProviderStopReason) async throws {}
    
    func fetchPrefilter(existingPrefilterTag _: String?) async throws -> NEURLFilterPrefilter? {
        nil
    }
}
