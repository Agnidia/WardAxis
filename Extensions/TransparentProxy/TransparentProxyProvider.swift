//
//  TransparentProxyProvider.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import NetworkExtension

/// Packaging shell for the transparent proxy.
///
/// Trust boundary: the TCP and UDP flows the system hands to the proxy. The shell
/// fails `startProxy`, so the system claims no flow for a proxy that has no policy.
final class TransparentProxyProvider: NETransparentProxyProvider {
    override func startProxy(options _: [String: Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(CocoaError(.featureUnsupported))
    }
    
    override func stopProxy(with _: NEProviderStopReason) async {}
}
