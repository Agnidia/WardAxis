//
//  BuildApplication.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Hummingbird
import HummingbirdCore
import HummingbirdTLS
import HummingbirdWebSocket
import Logging
import NIOCore
import PostgresNIO
import ServiceLifecycle

/// Builds the runnable application: the application core, the database client and
/// start-up migrations.
///
/// Migrations run in `beforeServerStarts`, so the listener binds only after the
/// schema is current. A migration error ends `runService()` with that error.
///
/// - Throws: ``ConfigurationError`` when ``AppConfiguration/tls`` names files that do not
///   load, before anything starts.
package func buildApplication(
    configuration: AppConfiguration,
    dependencies: ServerDependencies,
    client: PostgresClient,
    logger: Logger
) throws -> some ApplicationProtocol {
    let tlsConfiguration = try configuration.tls.map { files throws(ConfigurationError) in
        try ServerTLS.configuration(for: files)
    }
    var application = try buildApplicationCore(
        dependencies: dependencies,
        address: .hostname(configuration.host, port: configuration.port),
        logger: logger,
        services: [client],
        tlsConfiguration: tlsConfiguration
    )
    application.beforeServerStarts {
        try await MigrationRunner(logger: logger).run(on: client)
    }
    return application
}

/// Builds the HTTP and WebSocket server and the config change relay, without a database
/// client, so live tests can run it on in-memory stores.
///
/// One router serves both plain HTTP and WebSocket upgrades. Every connection must finish
/// its first request head within `httpIdleTimeout` of accept (`FirstRequestDeadlineChannel`).
/// After that, a plain HTTP connection closes after `httpIdleTimeout` with no traffic, and
/// an upgraded one is closed by the WebSocket auto-ping instead. With the connection cap,
/// these bound how long silent or idle clients hold a connection. They do not bound a
/// client that keeps sending slowly; a reverse proxy still owns per-client limits and
/// read timeouts.
///
/// - Parameters:
///   - services: Services the relay depends on, such as the database client. They start
///     before the relay and, because shutdown runs in reverse order, stop after it.
///   - httpIdleTimeout: Closes a connection that has no complete first request head this
///     long after accept, and an HTTP connection that sends nothing for this long. With
///     TLS the same deadline also bounds the handshake.
///   - tlsConfiguration: Serves TLS on the listener when set; plain HTTP when `nil`. The
///     config stream is mounted only when it requires client certificates
///     (``ServerTLS/requiresClientCertificates(_:)``); otherwise start-up logs once that
///     the feed is disabled.
package func buildApplicationCore(
    dependencies: ServerDependencies,
    address: BindAddress,
    logger: Logger,
    services: [any Service] = [],
    httpIdleTimeout: TimeAmount = HTTPServerLimits.idleTimeout,
    tlsConfiguration: TLSConfiguration? = nil
) throws -> Application<RouterResponder<AppRequestContext>> {
    let clientCertificates: ClientCertificateVerification = tlsConfiguration.map(ServerTLS.requiresClientCertificates) == true ? .required : .off
    if clientCertificates == .off {
        logger.notice(
            "Config stream disabled: the listener verifies no client certificates, and the feed has no other credential",
            metadata: ["config.stream.requires": "\(AppConfiguration.Variable.tlsClientCAPath)"]
        )
    }
    let router = try buildRouter(dependencies: dependencies, clientCertificates: clientCertificates)
    let webSocketResponder = router.buildResponder()
    let channelConfiguration = HTTP1WebSocketUpgradeChannel.Configuration(
        http1: .init(idleTimeout: httpIdleTimeout),
        ws: WebSocketServerConfiguration(autoPing: .enabled(timePeriod: dependencies.configStreamPolicy.pingInterval))
    )
    // The same channel `.http1WebSocketUpgrade(webSocketRouter:configuration:)` builds,
    // wrapped so a connection cannot stay open without sending a request. TLS wraps the
    // deadline channel, so the deadline starts at accept, before the handshake.
    let server = HTTPServerBuilder { responder in
        let channel = FirstRequestDeadlineChannel(
            base: HTTP1WebSocketUpgradeChannel(
                responder: responder,
                webSocketResponder: webSocketResponder,
                configuration: channelConfiguration
            ),
            timeout: httpIdleTimeout
        )
        guard let tlsConfiguration else {
            return channel
        }
        return try TLSChannel(channel, tlsConfiguration: tlsConfiguration)
    }
    var application = Application(
        router: router,
        server: server,
        configuration: ApplicationConfiguration(
            address: address,
            availableConnectionsDelegate: MaximumAvailableConnections(HTTPServerLimits.maximumConnections, logger: logger)
        ),
        logger: logger
    )
    application.addServices(services)
    application.addServices(
        ConfigChangeRelay(
            store: dependencies.configStore,
            notifier: dependencies.configNotifier,
            hub: dependencies.configHub,
            policy: dependencies.configStreamPolicy,
            logger: logger
        )
    )
    return application
}

/// Connection limits for the HTTP listener.
package enum HTTPServerLimits {
    /// Closes a connection with no complete first request head this long after accept,
    /// and an HTTP connection that sends nothing for this long.
    package static let idleTimeout: TimeAmount = .seconds(30)
    /// Above this many open connections the listener stops accepting new ones.
    package static let maximumConnections: Int = 1024
}
