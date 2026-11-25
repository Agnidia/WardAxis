//
//  DNSProxyProvider.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import NetworkExtension

/// Packaging shell for the DNS proxy.
///
/// Trust boundary: every DNS query on the Mac once the proxy runs. The shell fails
/// `startProxy`, so resolution stays with the system resolver.
final class DNSProxyProvider: NEDNSProxyProvider {
    override func startProxy(options _: [String: Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(CocoaError(.featureUnsupported))
    }
    
    override func stopProxy(with _: NEProviderStopReason) async {}
}
