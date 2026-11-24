//
//  LocalizedStringKey+Key.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

extension LocalizedStringKey: @retroactive Hashable {    
    static func == (lhs: LocalizedStringKey, rhs: LocalizedStringKey) -> Bool {
        lhs.stringKey == rhs.stringKey
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(stringKey)
    }
    
    /// This will mirror the `LocalizedStringKey` so it can access its
    /// internal `key` property. Mirroring is rather expensive, but it
    /// should be fine performance-wise, unless you are
    /// using it too much or doing something out of the norm.
    private var stringKey: String? {
        Mirror(reflecting: self).children.first(where: { $0.label == "key" })?.value as? String
    }
}
