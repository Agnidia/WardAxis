//
//  ConfigurationServiceProtocol.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Keeps the live configuration from the management server's `/config/stream` feed.
///
/// The service holds a connection only while the device is enrolled and the app
/// is in the foreground, and it authenticates with the device's TLS client
/// identity only: no bearer token, no header the server could be asked to trust.
/// It applies the last cached configuration before the first network attempt;
/// unenrollment closes the connection and deletes the cache.
///
/// Both inputs are idempotent, so several windows may forward the same value.
public protocol ConfigurationServiceProtocol: AnyObject, Sendable {
    /// The configuration in effect, or `nil` before the first snapshot or cache
    /// load and after unenrollment. Observable from SwiftUI.
    @MainActor var configuration: ManagedConfiguration? { get }
    
    /// `true` once the server refused this device's identity. The feed stays idle
    /// until the enrollment changes, because retrying the same certificate cannot succeed.
    @MainActor var isIdentityRejected: Bool { get }
    
    /// Enrolled connects (in the foreground); unenrolled tears down, deletes the
    /// cache and clears ``configuration``; a different enrollment counts as an
    /// unenrollment followed by an enrollment.
    @MainActor
    func enrollmentDidChange(to state: EnrollmentState)
    
    /// The background closes the connection and schedules no reconnect; the
    /// foreground connects at once.
    @MainActor
    func sceneDidChange(isForeground: Bool)
}
