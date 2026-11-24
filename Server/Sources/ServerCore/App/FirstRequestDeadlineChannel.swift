//
//  FirstRequestDeadlineChannel.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import HummingbirdCore
import HummingbirdWebSocket
import Logging
import NIOCore
import NIOWebSocket

/// The HTTP/1 and WebSocket upgrade channel, with a deadline for the first request.
///
/// `HTTP1WebSocketUpgradeChannel` installs the HTTP idle timeout only once a complete
/// first request head arrives without an upgrade. Until then nothing would close a client
/// that sends nothing, or part of a head, and each such socket holds a slot under the
/// listener's connection cap. This channel closes a connection that has not finished
/// negotiating `timeout` after accept. From then on the HTTP idle timeout, or the
/// WebSocket auto-ping after an upgrade, decides when the connection is idle.
///
/// Graceful shutdown waits until every open connection closes, and the HTTP handler that
/// closes idle connections at shutdown is not in the pipeline yet. So a connection that has
/// not negotiated when shutdown starts is closed then, not at its deadline; otherwise one
/// silent client holds the shutdown for the full `timeout`.
struct FirstRequestDeadlineChannel: ServerChildChannel {
    typealias Value = HTTP1WebSocketUpgradeChannel.Value

    let base: HTTP1WebSocketUpgradeChannel
    let timeout: TimeAmount

    func setup(channel: any Channel, logger: Logger) -> EventLoopFuture<Value> {
        let deadline = channel.eventLoop.scheduleTask(in: timeout) {
            guard !Self.hasNegotiated(channel) else { return }
            logger.debug("Closing a connection that sent no complete request in time")
            channel.close(promise: nil)
        }
        // Releases the channel at close instead of at the deadline.
        channel.closeFuture.whenComplete { _ in deadline.cancel() }
        do {
            // First, so it sees the shutdown event before any handler of the upgrade channel.
            try channel.pipeline.syncOperations.addHandler(CloseUnnegotiatedOnShutdownHandler(logger: logger), position: .first)
        } catch {
            return channel.eventLoop.makeFailedFuture(error)
        }
        return base.setup(channel: channel, logger: logger)
    }

    func handle(value: Value, logger: Logger) async {
        await base.handle(value: value, logger: logger)
    }

    /// Whether the pipeline holds the HTTP/1 connection handler or the WebSocket frame
    /// encoder. The upgrade channel adds the first when it serves plain HTTP and the
    /// second when it upgrades. A pipeline with neither is still waiting for the first
    /// request, so an unknown pipeline shape closes at the deadline rather than staying open.
    ///
    /// Call it on the channel's event loop only: the synchronous pipeline view needs it.
    fileprivate static func hasNegotiated(_ channel: any Channel) -> Bool {
        let pipeline = channel.pipeline.syncOperations
        return (try? pipeline.context(handlerType: HTTPConnectionStateHandler.self)) != nil
            || (try? pipeline.context(handlerType: WebSocketFrameEncoder.self)) != nil
    }
}

/// Closes a connection that has not negotiated when the server starts its graceful
/// shutdown; passes every other event on.
///
/// A WebSocket handshake still in flight is closed too. Its client must reconnect to
/// another instance either way, as it must after the close an upgraded stream gets at
/// shutdown.
private final class CloseUnnegotiatedOnShutdownHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = NIOAny

    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        guard event is ChannelShouldQuiesceEvent, !FirstRequestDeadlineChannel.hasNegotiated(context.channel) else {
            context.fireUserInboundEventTriggered(event)
            return
        }
        logger.debug("Closing a connection that sent no complete request before shutdown")
        context.close(promise: nil)
    }
}
