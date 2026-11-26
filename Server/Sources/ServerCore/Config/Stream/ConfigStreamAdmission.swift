//
//  ConfigStreamAdmission.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import HTTPTypes
import Hummingbird
import NIOSSL

/// Admits `GET /v1/config/stream` only on a connection whose TLS handshake verified a
/// client certificate, and records that certificate as the stream's slot key.
///
/// Trust boundary: the TLS layer. The listener refuses a handshake without a certificate
/// that chains to the device CA, so this check is the second gate, not the first: it
/// fails closed if the route is ever mounted on a listener that does not verify clients
/// (plain HTTP, or TLS without `TLS_CLIENT_CA_PATH`). No header is read, so no
/// `Authorization`, forwarded-certificate or device-ID header can stand in for the
/// handshake.
package struct ConfigStreamAdmissionMiddleware: RouterMiddleware {
    package typealias Context = AppRequestContext
    
    package init() {}
    
    package func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        let certificate: NIOSSLCertificate?
        do {
            certificate = try await context.channel.nioSSL_peerCertificate().get()
        } catch {
            // No TLS handler on the channel: plain HTTP.
            certificate = nil
        }
        guard let certificate, let der = try? certificate.toDERBytes() else {
            context.logger.error("Config stream request without a verified client certificate")
            throw APIError.internalError
        }
        var context = context
        context.configStreamClient = ConfigStreamClient(certificateDER: der)
        return try await next(request, context)
    }
    
    /// Whether the request asks for the WebSocket protocol (`Upgrade: websocket`, any case).
    package static func requestsWebSocket(_ headers: HTTPFields) -> Bool {
        headers[values: .upgrade].contains { value in
            value.split(separator: ",").contains { $0.trimmingCharacters(in: .whitespaces).lowercased() == "websocket" }
        }
    }
}
