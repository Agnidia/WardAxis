//
//  EnrollmentState.swift
//
//  Created on 24.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Whether this device is enrolled with a management server.
public enum EnrollmentState: Sendable, Equatable {
    /// The stored enrollment has not been read yet.
    case restoring
    
    case unenrolled
    
    /// Enrolled under `id`. A different id is a different enrollment: state
    /// cached for the previous one must not carry over.
    case enrolled(EnrollmentID)
}

/// An opaque enrollment identifier, compared but never shown or logged.
public struct EnrollmentID: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    private let rawValue: String
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    public var description: String {
        "EnrollmentID(<private>)"
    }
    
    public var debugDescription: String {
        description
    }
}
