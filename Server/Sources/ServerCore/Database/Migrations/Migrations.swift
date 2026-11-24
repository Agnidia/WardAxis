//
//  Migrations.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// The registry of every migration the server applies at start-up.
///
/// Append-only: add a new file with the next version and list it last. Versions run
/// 1, 2, 3, … with no gap. Never edit, renumber or remove an entry that has shipped; the
/// runner reports that as drift.
package enum Migrations {
    package static let all: [Migration] = [
        .baseline0001,
        .createConfiguration0002
    ]
}
