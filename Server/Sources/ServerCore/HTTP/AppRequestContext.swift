//
//  AppRequestContext.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Hummingbird
import HummingbirdWebSocket
import NIOCore

/// The request context every route and middleware uses.
package struct AppRequestContext: RequestContext, WebSocketRequestContext {
    package var coreContext: CoreRequestContextStorage
    /// Set by ``RequestIDMiddleware``; `nil` only in a chain built without it.
    package var requestID: String?
    /// The socket peer; `nil` when the channel has none, as in router-mode tests.
    package let remoteAddress: SocketAddress?
    /// The connection's channel, from which ``ConfigStreamAdmissionMiddleware`` reads the
    /// certificate that the TLS handshake verified.
    package let channel: any Channel
    /// Hands a WebSocket route's handler to the upgrade. A reference, so every copy of the
    /// context that middleware makes shares it.
    package let webSocket: WebSocketHandlerReference<AppRequestContext>
    /// Set by ``ConfigStreamAdmissionMiddleware`` on `GET /v1/config/stream`. The upgrade
    /// handler reads it, because task-locals bound in middleware do not reach it.
    package var configStreamClient: ConfigStreamClient?
    
    package init(source: ApplicationRequestContextSource) {
        coreContext = .init(source: source)
        requestID = nil
        remoteAddress = source.channel.remoteAddress
        channel = source.channel
        webSocket = .init()
        configStreamClient = nil
    }
}
