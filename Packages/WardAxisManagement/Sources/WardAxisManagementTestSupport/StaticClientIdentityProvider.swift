//
//  StaticClientIdentityProvider.swift
//
//  Created on 24.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Synchronization
import WardAxisManagement

/// Returns a scripted identity or error and counts the reads.
public final class StaticClientIdentityProvider: ClientIdentityProvider {
    private struct State {
        var result: Result<ClientIdentity?, ClientIdentityError>
        var readCount = 0
    }
    
    private let state: Mutex<State>
    
    public init(_ result: Result<ClientIdentity?, ClientIdentityError>) {
        state = Mutex(State(result: result))
    }
    
    public var readCount: Int {
        state.withLock { $0.readCount }
    }
    
    public func replace(with result: Result<ClientIdentity?, ClientIdentityError>) {
        state.withLock { $0.result = result }
    }
    
    public func currentIdentity() async throws(ClientIdentityError) -> ClientIdentity? {
        let result = state.withLock { state in
            state.readCount += 1
            return state.result
        }
        return try result.get()
    }
}
