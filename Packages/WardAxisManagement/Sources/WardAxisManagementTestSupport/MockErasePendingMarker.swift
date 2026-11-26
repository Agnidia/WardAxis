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
        var setError: SecureItemStoreError?
        var clearError: SecureItemStoreError?
    }
    
    private let state: Mutex<State>
    
    public init(isSet: Bool = false, setError: SecureItemStoreError? = nil, clearError: SecureItemStoreError? = nil) {
        state = Mutex(State(isSet: isSet, setError: setError, clearError: clearError))
    }
    
    public var isSet: Bool {
        state.withLock { $0.isSet }
    }
    
    /// Every write so far, in order.
    public var operations: [Operation] {
        state.withLock { $0.operations }
    }
    
    public func failClears(with error: SecureItemStoreError?) {
        state.withLock { $0.clearError = error }
    }
    
    public func set() throws(SecureItemStoreError) {
        let error = state.withLock { state -> SecureItemStoreError? in
            if let error = state.setError {
                return error
            }
            state.isSet = true
            state.operations.append(.set)
            return nil
        }
        if let error {
            throw error
        }
    }
    
    public func clear() throws(SecureItemStoreError) {
        let error = state.withLock { state -> SecureItemStoreError? in
            if let error = state.clearError {
                return error
            }
            state.isSet = false
            state.operations.append(.clear)
            return nil
        }
        if let error {
            throw error
        }
    }
}
