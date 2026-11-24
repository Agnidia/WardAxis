//
//  ConfigFrameEncoder.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import WardAxisAPIServer
import Foundation

/// Encodes the contract's `ConfigMessage` frames as JSON text.
///
/// Keys are sorted, so a frame's text depends only on its content.
package enum ConfigFrameEncoder {
    package static func snapshot(_ record: ConfigSnapshotRecord) throws -> String {
        try encode(.snapshot(.init(_type: .snapshot, version: record.version, values: record.values)))
    }

    package static func delta(_ change: ConfigChange) throws -> ConfigDeltaFrame {
        let text = try encode(.delta(.init(_type: .delta, version: change.version, changed: change.changed, removed: change.removed)))
        return ConfigDeltaFrame(version: change.version, text: text)
    }

    package static func heartbeat(version: Int64) throws -> String {
        try encode(.heartbeat(.init(_type: .heartbeat, version: version)))
    }

    private static func encode(_ message: Components.Schemas.ConfigMessage) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try String(decoding: encoder.encode(message), as: UTF8.self)
    }
}
