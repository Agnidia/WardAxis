//
//  DatabaseHealthProbe.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// Answers whether the database accepts queries. The seam that keeps router tests DB-free.
package protocol DatabaseHealthProbe: Sendable {
    /// Returns within a bounded time; never throws, because "unreachable" is an answer.
    func isReachable() async -> Bool
}
