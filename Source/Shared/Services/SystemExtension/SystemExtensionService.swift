//
//  SystemExtensionService.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisTelemetry
#if os(macOS)
import SystemExtensions
#endif

/// Submits `OSSystemExtensionRequest`s for the NetworkFilter system extension.
///
/// Off macOS every request fails with ``SystemExtensionError/unsupportedPlatform``.
final class SystemExtensionService: SystemExtensionServiceProtocol {
    private let identifier: Result<String, SystemExtensionError>
    
    init(bundle: Bundle) {
        do throws(SystemExtensionError) {
            identifier = try .success(SystemExtensionIdentifier.resolve(in: bundle))
        } catch {
            identifier = .failure(error)
        }
    }
    
    func activate() -> AsyncThrowingStream<SystemExtensionEvent, any Error> {
        submit(.activate)
    }
    
    func deactivate() -> AsyncThrowingStream<SystemExtensionEvent, any Error> {
        submit(.deactivate)
    }
    
    private enum Kind {
        case activate
        case deactivate
    }

#if os(macOS)
    private static let queue = DispatchQueue(label: "SystemExtensionService.requests")
    private static let logger = Log(category: .filter)
    
    private func submit(_ kind: Kind) -> AsyncThrowingStream<SystemExtensionEvent, any Error> {
        AsyncThrowingStream { continuation in
            let extensionID: String
            switch identifier {
            case .success(let value):
                extensionID = value
            case .failure(let error):
                Self.logger.error("System extension request refused: invalid identifier", privacy: .public)
                continuation.finish(throwing: error)
                return
            }
            
            let request = switch kind {
            case .activate:
                OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionID, queue: Self.queue)
            case .deactivate:
                OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: extensionID, queue: Self.queue)
            }
            let delegate = RequestDelegate(continuation: continuation)
            request.delegate = delegate
            // The request holds its delegate weakly; the stream keeps it alive until it ends.
            continuation.onTermination = { _ in withExtendedLifetime(delegate) {} }
            OSSystemExtensionManager.shared.submitRequest(request)
        }
    }
    
    /// Maps an `OSSystemExtensionError` to ``SystemExtensionError``; any other error is `.unknown`.
    static func map(_ error: any Error) -> SystemExtensionError {
        let nsError = error as NSError
        guard nsError.domain == OSSystemExtensionErrorDomain,
              let code = OSSystemExtensionError.Code(rawValue: nsError.code)
        else {
            return .unknown(code: nsError.code)
        }
        return switch code {
        case .missingEntitlement: .missingEntitlement
        case .unsupportedParentBundleLocation: .unsupportedParentBundleLocation
        case .extensionNotFound: .extensionNotFound
        case .codeSignatureInvalid: .codeSignatureInvalid
        case .validationFailed: .validationFailed
        case .forbiddenBySystemPolicy: .forbiddenBySystemPolicy
        case .requestCanceled: .requestCanceled
        case .requestSuperseded: .requestSuperseded
        case .authorizationRequired: .authorizationRequired
        case .unknown, .extensionMissingIdentifier, .duplicateExtensionIdentifer, .unknownExtensionCategory:
            .unknown(code: code.rawValue)
        @unknown default:
            .unknown(code: code.rawValue)
        }
    }
    
    /// Called only on ``queue``; holds nothing but the Sendable continuation.
    private final class RequestDelegate: NSObject, OSSystemExtensionRequestDelegate, Sendable {
        private let continuation: AsyncThrowingStream<SystemExtensionEvent, any Error>.Continuation
        
        init(continuation: AsyncThrowingStream<SystemExtensionEvent, any Error>.Continuation) {
            self.continuation = continuation
        }
        
        /// The OS offers a replacement only for the extension embedded in this signed
        /// app, so a newer debug build may replace the installed one.
        func request(
            _ request: OSSystemExtensionRequest,
            actionForReplacingExtension existing: OSSystemExtensionProperties,
            withExtension ext: OSSystemExtensionProperties
        ) -> OSSystemExtensionRequest.ReplacementAction {
            .replace
        }
        
        func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
            continuation.yield(.needsUserApproval)
        }
        
        func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
            switch result {
            case .completed:
                continuation.yield(.completed)
            case .willCompleteAfterReboot:
                continuation.yield(.willCompleteAfterReboot)
            @unknown default:
                continuation.finish(throwing: SystemExtensionError.unknown(code: result.rawValue))
                return
            }
            continuation.finish()
        }
        
        func request(_ request: OSSystemExtensionRequest, didFailWithError error: any Error) {
            let mapped = SystemExtensionService.map(error)
            SystemExtensionService.logger.error("System extension request failed: \(mapped)", privacy: .public)
            continuation.finish(throwing: mapped)
        }
    }
#else
    private func submit(_ kind: Kind) -> AsyncThrowingStream<SystemExtensionEvent, any Error> {
        AsyncThrowingStream { $0.finish(throwing: SystemExtensionError.unsupportedPlatform) }
    }
#endif
}
