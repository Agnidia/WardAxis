//
//  ConfigurationFrameDecoder.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisAPIClient

/// One decoded configuration feed frame.
enum ConfigurationFrame: Sendable, Equatable {
    case snapshot(ManagedConfiguration)
    case delta(version: Int64, changed: [String: ConfigurationValue], removed: [String])
    case heartbeat(version: Int64)
}

/// Decodes feed frames with the contract's generated `ConfigMessage`, so the
/// wire format cannot drift from the spec, and keeps the generated types out
/// of the service and the cache.
struct ConfigurationFrameDecoder: Sendable {
    private typealias Message = Components.Schemas.ConfigMessage
    
    private struct TooManyEntries: Error {}
    
    /// The frame, or `nil` for a payload that does not decode, has an unknown
    /// `type`, or exceeds ``ConfigurationLimits``; the caller skips it and keeps
    /// the connection open.
    func decode(_ data: Data) -> ConfigurationFrame? {
        guard ConfigurationLimits.isWithinBounds(data) else {
            return nil
        }
        do {
            switch try JSONDecoder().decode(Message.self, from: data) {
            case .snapshot(let snapshot):
                return try .snapshot(ManagedConfiguration(version: snapshot.version, values: values(of: snapshot.values)))
            case .delta(let delta):
                guard delta.removed.count <= ConfigurationLimits.maximumEntryCount else {
                    return nil
                }
                return try .delta(version: delta.version, changed: values(of: delta.changed), removed: delta.removed)
            case .heartbeat(let heartbeat):
                return .heartbeat(version: heartbeat.version)
            }
        } catch {
            return nil
        }
    }
    
    private func values(of entries: Components.Schemas.ConfigEntries) throws -> [String: ConfigurationValue] {
        guard entries.additionalProperties.value.count <= ConfigurationLimits.maximumEntryCount else {
            throw TooManyEntries()
        }
        let data = try JSONEncoder().encode(entries.additionalProperties)
        return try JSONDecoder().decode([String: ConfigurationValue].self, from: data)
    }
}
