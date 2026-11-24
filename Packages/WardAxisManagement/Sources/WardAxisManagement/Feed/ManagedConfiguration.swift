//
//  ManagedConfiguration.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// The live app configuration: the server's settings at one version.
///
/// Not a credential. It holds no token or account data, so it may be cached on
/// disk under a file-protection class (see ``FileConfigurationCache``).
public struct ManagedConfiguration: Sendable, Equatable, Codable {
    /// The server's configuration version that ``values`` represents.
    public let version: Int64

    /// Settings keyed by name.
    public let values: [String: ConfigurationValue]

    public init(version: Int64, values: [String: ConfigurationValue]) {
        self.version = version
        self.values = values
    }
}
