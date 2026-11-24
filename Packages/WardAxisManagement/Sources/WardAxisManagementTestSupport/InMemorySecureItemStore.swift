//
//  InMemorySecureItemStore.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Synchronization
import WardAxisManagement

/// ``SecureItemStoreProtocol`` double that keeps one value in memory, so tests
/// never touch the real Keychain.
///
/// Each operation can be made to fail, and every operation is recorded in order.
public final class InMemorySecureItemStore<Value: SecurePayload>: SecureItemStoreProtocol {
    public enum Operation: Sendable, Equatable {
        case load
        case save
        case delete
    }

    private struct State {
        var value: Value?
        var loadError: SecureItemStoreError?
        var saveError: SecureItemStoreError?
        var deleteError: SecureItemStoreError?
        /// Deletes still to fail before `deleteError` clears; `nil` fails every one.
        var deleteFailuresRemaining: Int?
        var operations: [Operation] = []
    }

    private let state: Mutex<State>

    public init(
        value: Value? = nil,
        loadError: SecureItemStoreError? = nil,
        saveError: SecureItemStoreError? = nil,
        deleteError: SecureItemStoreError? = nil
    ) {
        state = Mutex(State(value: value, loadError: loadError, saveError: saveError, deleteError: deleteError))
    }

    /// The stored value right now.
    public var value: Value? {
        state.withLock { $0.value }
    }

    /// Every operation so far, in order.
    public var operations: [Operation] {
        state.withLock { $0.operations }
    }

    /// Replaces the error the next loads throw; `nil` lets them succeed.
    public func failLoads(with error: SecureItemStoreError?) {
        state.withLock { $0.loadError = error }
    }

    /// Replaces the error the next saves throw; `nil` lets them succeed.
    public func failSaves(with error: SecureItemStoreError?) {
        state.withLock { $0.saveError = error }
    }

    /// Replaces the error deletes throw; `nil` lets them succeed.
    /// - Parameter times: fail only the next `times` deletes, then succeed;
    ///   `nil` fails every delete until replaced.
    public func failDeletes(with error: SecureItemStoreError?, times: Int? = nil) {
        state.withLock { state in
            let isFailing = error != nil && (times.map { $0 > 0 } ?? true)
            state.deleteError = isFailing ? error : nil
            state.deleteFailuresRemaining = isFailing ? times : nil
        }
    }

    public func load() throws(SecureItemStoreError) -> Value? {
        let result: Result<Value?, SecureItemStoreError> = state.withLock { state in
            state.operations.append(.load)
            if let error = state.loadError {
                return .failure(error)
            }
            return .success(state.value)
        }
        return try result.get()
    }

    public func save(_ value: Value) throws(SecureItemStoreError) {
        let error: SecureItemStoreError? = state.withLock { state in
            state.operations.append(.save)
            guard state.saveError == nil else { return state.saveError }
            state.value = value
            return nil
        }
        if let error {
            throw error
        }
    }

    public func delete() throws(SecureItemStoreError) {
        let error: SecureItemStoreError? = state.withLock { state in
            state.operations.append(.delete)
            if let error = state.deleteError {
                if let remaining = state.deleteFailuresRemaining {
                    if remaining > 1 {
                        state.deleteFailuresRemaining = remaining - 1
                    } else {
                        // The last scripted failure: later deletes succeed.
                        state.deleteFailuresRemaining = nil
                        state.deleteError = nil
                    }
                }
                return error
            }
            state.value = nil
            // An unreadable item is gone once deleted.
            if state.loadError == .unreadable {
                state.loadError = nil
            }
            return nil
        }
        if let error {
            throw error
        }
    }
}
