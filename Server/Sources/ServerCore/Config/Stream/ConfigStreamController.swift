//
//  ConfigStreamController.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Hummingbird
import HummingbirdWebSocket

/// Mounts `GET /v1/config/stream`, the WebSocket the contract's `streamConfig` describes.
///
/// A hand-written route, because the generator makes no WebSocket server.
///
/// Authorization is "holds a certificate issued by the device CA": the listener verified
/// it in the TLS handshake, and ``ConfigStreamAdmissionMiddleware`` refuses a connection
/// where it did not. The feed is global configuration, so every such device may read it;
/// per-device authorization arrives with the Phase 5 device API. No identity header is
/// ever trusted. ``buildRouter(dependencies:clientCertificates:)`` mounts this route only
/// when the listener requires client certificates.
package struct ConfigStreamController {
    private let dependencies: ServerDependencies

    package init(dependencies: ServerDependencies) {
        self.dependencies = dependencies
    }

    package func addRoutes(to group: RouterGroup<AppRequestContext>) {
        let dependencies = dependencies
        group.group("config/stream")
            .add(middleware: ConfigStreamAdmissionMiddleware())
            .ws(
                shouldUpgrade: { request, _ in
                    // Only a plain GET gets here without the header: a request that carries
                    // it but no handshake gets a redirect from the library first.
                    guard ConfigStreamAdmissionMiddleware.requestsWebSocket(request.headers) else {
                        throw APIError.invalidRequest(message: "The request must upgrade to a WebSocket.")
                    }
                    return .upgrade([:])
                },
                onUpgrade: { inbound, outbound, context in
                    let session = ConfigStreamSession(
                        store: dependencies.configStore,
                        hub: dependencies.configHub,
                        policy: dependencies.configStreamPolicy,
                        logger: context.logger
                    )
                    await session.run(client: context.requestContext.configStreamClient, inbound: inbound, outbound: outbound)
                }
            )
    }
}
