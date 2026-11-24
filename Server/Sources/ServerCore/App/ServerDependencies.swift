//
//  ServerDependencies.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// The long-lived services routes depend on, assembled once by the composition root.
///
/// A new service becomes a field here, never a global. Fields are `any` protocol
/// existentials, as in the app's `AppContainer`: tests pass stubs, and adding a
/// service does not change the generic signature of every builder.
package struct ServerDependencies: Sendable {
    package var databaseProbe: any DatabaseHealthProbe
    package var configStore: any ConfigStore
    package var configNotifier: any ConfigChangeNotifier
    /// Built from ``configStreamPolicy`` in `init`, so the cap it enforces always matches
    /// the policy; one instance per process.
    package let configHub: ConfigConnectionHub
    package let configStreamPolicy: ConfigStreamPolicy
    /// The API reference assets; `nil` means docs are off and their routes are never
    /// registered.
    package var apiDocs: APIDocs?
    /// The deployment the routes serve. ``buildRouter(dependencies:clientCertificates:)``
    /// mounts the docs routes only in ``ServerEnvironment/development``, whatever
    /// ``apiDocs`` holds.
    package var environment: ServerEnvironment

    package init(
        databaseProbe: any DatabaseHealthProbe,
        configStore: any ConfigStore,
        configNotifier: any ConfigChangeNotifier,
        configStreamPolicy: ConfigStreamPolicy = .standard,
        apiDocs: APIDocs? = nil,
        // Production fails closed: a composition root that omits it gets no docs.
        environment: ServerEnvironment = .production
    ) {
        self.databaseProbe = databaseProbe
        self.configStore = configStore
        self.configNotifier = configNotifier
        self.configStreamPolicy = configStreamPolicy
        self.apiDocs = apiDocs
        self.environment = environment
        configHub = ConfigConnectionHub(
            maxConnectionsPerClient: configStreamPolicy.maxConnectionsPerClient,
            bufferSize: configStreamPolicy.subscriberBufferSize
        )
    }
}
