//
//  0001_Baseline.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

extension Migration {
    /// Marks the schema epoch. It has no statements: the first domain table arrives
    /// as version 2.
    static let baseline0001: Migration = .init(version: 1, name: "baseline", statements: [])
}
