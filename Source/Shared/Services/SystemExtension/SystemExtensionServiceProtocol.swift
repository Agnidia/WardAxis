//
//  SystemExtensionServiceProtocol.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// A state change of one system extension request, in the order the OS reports it.
enum SystemExtensionEvent: Equatable, Sendable {
    /// The OS waits for the user to allow the extension in System Settings.
    case needsUserApproval
    /// The OS activated or removed the extension.
    case completed
    /// The OS finishes the request at the next restart.
    case willCompleteAfterReboot
}

/// The extension's installed state as the OS reports it.
enum SystemExtensionInstallState: Equatable, Sendable {
    case notInstalled
    case awaitingApproval
    case enabled
    /// Installed but not enabled, for example turned off in System Settings.
    case disabled
    /// Removal finishes at the next restart.
    case uninstalling
}

/// The OS record of one installed version of the extension.
struct SystemExtensionRecord: Equatable, Sendable {
    var isEnabled: Bool
    var isAwaitingUserApproval: Bool
    var isUninstalling: Bool
}

extension SystemExtensionInstallState {
    /// Several versions can be installed at once, for example while a replacement
    /// awaits approval; a version that is not being removed decides.
    init(records: [SystemExtensionRecord]) {
        let live = records.filter { !$0.isUninstalling }
        if live.contains(where: \.isEnabled) {
            self = .enabled
        } else if live.contains(where: \.isAwaitingUserApproval) {
            self = .awaitingApproval
        } else if !live.isEmpty {
            self = .disabled
        } else if !records.isEmpty {
            self = .uninstalling
        } else {
            self = .notInstalled
        }
    }
}

/// Why a system extension request failed.
enum SystemExtensionError: Error, Equatable, Sendable {
    /// The platform has no system extensions (iOS, iPadOS, tvOS).
    case unsupportedPlatform
    case invalidIdentifier
    /// The app does not run from `/Applications`.
    case unsupportedParentBundleLocation
    case extensionNotFound
    case missingEntitlement
    case codeSignatureInvalid
    case validationFailed
    /// A system policy, for example an MDM restriction, forbids the extension.
    case forbiddenBySystemPolicy
    case requestCanceled
    case requestSuperseded
    case authorizationRequired
    case endedWithoutResult
    /// An error the app does not map; the value is the OS error code.
    case unknown(code: Int)
    
    /// `error` when it is already a ``SystemExtensionError``; otherwise `.unknown`
    /// with its code only, so no description reaches the log or the UI.
    init(_ error: any Error) {
        self = error as? SystemExtensionError ?? .unknown(code: (error as NSError).code)
    }
}

/// Installs and removes the app's own NetworkFilter system extension.
///
/// Trust boundary: the host app and `sysextd`. A request only installs or removes
/// the extension; it never saves a filter configuration, so the OS routes no traffic
/// to the extension (ADR 0005 D2, ADR 0006).
///
/// Each call submits one request and returns its events. The stream finishes after
/// `.completed` or `.willCompleteAfterReboot`, or throws a ``SystemExtensionError``.
protocol SystemExtensionServiceProtocol: Sendable {
    /// Asks the OS to activate the NetworkFilter system extension.
    func activate() -> AsyncThrowingStream<SystemExtensionEvent, any Error>
    
    /// Asks the OS to deactivate and remove the NetworkFilter system extension.
    func deactivate() -> AsyncThrowingStream<SystemExtensionEvent, any Error>
    
    /// Reads the extension's installed state. Read-only: it changes nothing on the system.
    func installState() async throws(SystemExtensionError) -> SystemExtensionInstallState
}
