//
//  FilterDataProvider.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import NetworkExtension

/// Packaging shell for the content filter.
///
/// Trust boundary: every flow on the Mac once the filter runs. With no policy, a
/// running filter would pass or drop traffic on no basis, so `startFilter` fails
/// and the system never routes a flow here.
final class FilterDataProvider: NEFilterDataProvider {
    override func startFilter() async throws {
        throw CocoaError(.featureUnsupported)
    }
    
    override func stopFilter(with _: NEProviderStopReason) async {}
}
