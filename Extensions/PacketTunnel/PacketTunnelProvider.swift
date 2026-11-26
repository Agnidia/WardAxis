//
//  PacketTunnelProvider.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import NetworkExtension

/// Packaging shell for the packet tunnel.
///
/// Trust boundary: all device traffic once the tunnel is up. The shell fails
/// `startTunnel`, so the system never routes packets into a tunnel with no policy.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options _: [String: NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(CocoaError(.featureUnsupported))
    }
    
    override func stopTunnel(with _: NEProviderStopReason) async {}
}
