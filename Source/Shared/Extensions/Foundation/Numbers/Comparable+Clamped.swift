//
//  Comparable+Clamped.swift
//
//  Created on 14.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

extension Comparable {
    /// The value moved into `range` when it lies outside.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
