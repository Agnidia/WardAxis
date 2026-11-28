//
//  TestSupport.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Hummingbird
import Logging
import ServerCore

/// A health probe with a fixed answer, so router tests need no database.
struct StubHealthProbe: DatabaseHealthProbe {
    let reachable: Bool
    
    func isReachable() async -> Bool {
        reachable
    }
}

extension ServerDependencies {
    /// Production wiring with test doubles: a stub health probe and in-memory config.
    ///
    /// - Parameter environment: Development, so a test that sets `apiDocs` gets the docs
    ///   routes; the production default of the initializer is tested on its own.
    static func testing(
        databaseReachable: Bool = true,
        configStore: any ConfigStore = EmptyConfigStore(),
        configNotifier: any ConfigChangeNotifier = ManualConfigChangeNotifier(),
        configStreamPolicy: ConfigStreamPolicy = .standard,
        environment: ServerEnvironment = .development
    ) -> ServerDependencies {
        ServerDependencies(
            databaseProbe: StubHealthProbe(reachable: databaseReachable),
            configStore: configStore,
            configNotifier: configNotifier,
            configStreamPolicy: configStreamPolicy,
            environment: environment
        )
    }
}

/// A configuration store at version 0 with no entries, for tests that do not stream.
struct EmptyConfigStore: ConfigStore {
    func snapshot() async throws -> ConfigSnapshotRecord {
        ConfigSnapshotRecord(version: 0, values: .init())
    }
    
    func currentVersion() async throws -> Int64 {
        0
    }
    
    func changes(after _: Int64, limit _: Int) async throws -> [ConfigChange] {
        []
    }
}

/// Builds an application from the production router with stub dependencies.
///
/// - Parameter clientCertificates: Off, as on a listener without a device CA; a test
///   that needs the config stream route says so explicitly.
func makeTestApplication(
    databaseReachable: Bool = true,
    clientCertificates: ClientCertificateVerification = .off,
    logger: Logger = Logger(label: "test")
) throws -> some ApplicationProtocol {
    let dependencies = ServerDependencies.testing(databaseReachable: databaseReachable)
    return try Application(router: buildRouter(dependencies: dependencies, clientCertificates: clientCertificates), logger: logger)
}

/// Decodes a JSON response body; compare decoded values, because key order is not stable on Linux.
func decodeJSON<Value: Decodable>(_: Value.Type, from body: ByteBuffer) throws -> Value {
    try JSONDecoder().decode(Value.self, from: Data(String(buffer: body).utf8))
}

/// The body of every error response, as the contract's `ErrorResponse` defines it.
struct ErrorBody: Decodable, Equatable {
    let code: String
    let message: String
    let requestId: String?
}

extension APIDocs {
    /// Docs routes with stand-in bytes, for tests of routing rather than content.
    static let stub = APIDocs(
        openAPIDocument: ByteBuffer(string: "openapi: 3.1.0\n"),
        redocScript: ByteBuffer(string: "/* redoc */")
    )
}

extension ConfigStreamClient {
    /// A distinct slot key with stand-in bytes; the hub never parses them.
    static func sample() -> ConfigStreamClient {
        ConfigStreamClient(certificateDER: Array(UUID().uuidString.utf8))
    }
}

extension ConfigConnectionHub {
    /// Room for five streams per client and a 32-frame buffer, enough for any relay test.
    static func testing() -> ConfigConnectionHub {
        ConfigConnectionHub(maxConnectionsPerClient: 5, bufferSize: 32)
    }
}
