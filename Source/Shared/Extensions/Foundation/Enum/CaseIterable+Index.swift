//
//  CaseIterable+Index.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// An extension that adds an `index` property to types that are both `CaseIterable` and `Equatable`.
public extension CaseIterable where Self: Equatable {
    /// The index of the current instance within the `allCases` collection.
    var index: Self.AllCases.Index? {
        Self.allCases.firstIndex { self == $0 }
    }
}
