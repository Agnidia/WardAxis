//
//  MockErasePendingMarker.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Synchronization
import WardAxisManagement

/// ``ErasePendingMarkerProtocol`` double that can start set and records every
/// write in order.
///
/// Share one instance between two services to stand in for the persisted flag
/// across a relaunch.
public final class MockErasePendingMarker: ErasePendingMarkerProtocol {
    public enum Operation: Sendable, Equatable {
        case set
        case clear
    }

    private struct State {
        var isSet: Bool
        var operations: [Operation] = []
    }

    private let state: Mutex<State>

    public init(isSet: Bool = false) {
        state = Mutex(State(isSet: isSet))
    }

    public var isSet: Bool {
        state.withLock { $0.isSet }
    }

    /// Every write so far, in order.
    public var operations: [Operation] {
        state.withLock { $0.operations }
    }

    public func set() {
        state.withLock { state in
            state.isSet = true
            state.operations.append(.set)
        }
    }

    public func clear() {
        state.withLock { state in
            state.isSet = false
            state.operations.append(.clear)
        }
    }
}
