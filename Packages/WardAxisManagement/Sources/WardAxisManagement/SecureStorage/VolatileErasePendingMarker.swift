//
//  VolatileErasePendingMarker.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Synchronization

/// An ``ErasePendingMarkerProtocol`` that lives only as long as the process.
///
/// For a fallback container that must never read or write the production
/// marker, which belongs to the real item.
public final class VolatileErasePendingMarker: ErasePendingMarkerProtocol {
    private let flag = Mutex(false)
    
    public init() {}
    
    public var isSet: Bool {
        flag.withLock { $0 }
    }
    
    public func set() {
        flag.withLock { $0 = true }
    }
    
    public func clear() {
        flag.withLock { $0 = false }
    }
}
