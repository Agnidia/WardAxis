//
//  SystemExtensionServiceTests.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
@testable import WardAxis
#if os(macOS)
import SystemExtensions
#endif

@Suite("System extension service")
struct SystemExtensionServiceTests {
#if os(macOS)
    @Test(arguments: [
        (OSSystemExtensionError.Code.missingEntitlement, SystemExtensionError.missingEntitlement),
        (.unsupportedParentBundleLocation, .unsupportedParentBundleLocation),
        (.extensionNotFound, .extensionNotFound),
        (.codeSignatureInvalid, .codeSignatureInvalid),
        (.validationFailed, .validationFailed),
        (.forbiddenBySystemPolicy, .forbiddenBySystemPolicy),
        (.requestCanceled, .requestCanceled),
        (.requestSuperseded, .requestSuperseded),
        (.authorizationRequired, .authorizationRequired),
        (.unknown, .unknown(code: OSSystemExtensionError.Code.unknown.rawValue)),
        (.duplicateExtensionIdentifer, .unknown(code: OSSystemExtensionError.Code.duplicateExtensionIdentifer.rawValue))
    ])
    func `Each OS error code maps to its case`(code: OSSystemExtensionError.Code, expected: SystemExtensionError) {
        let error = NSError(domain: OSSystemExtensionErrorDomain, code: code.rawValue)
        
        #expect(SystemExtensionService.map(error) == expected)
    }
    
    @Test
    func `An out-of-range OS code maps to unknown`() {
        let error = NSError(domain: OSSystemExtensionErrorDomain, code: 9999)
        
        #expect(SystemExtensionService.map(error) == .unknown(code: 9999))
    }
    
    @Test
    func `An error from another domain never maps to a known case`() {
        let code = OSSystemExtensionError.Code.requestCanceled.rawValue
        let error = NSError(domain: NSCocoaErrorDomain, code: code)
        
        #expect(SystemExtensionService.map(error) == .unknown(code: code))
    }
#else
    @Test
    func `Requests fail as unsupported off macOS`() async {
        let service = SystemExtensionService(bundle: .main)
        
        await #expect(throws: SystemExtensionError.unsupportedPlatform) {
            for try await _ in service.activate() {}
        }
    }
#endif

    @Test(arguments: [
        ([], SystemExtensionInstallState.notInstalled),
        ([record(enabled: true)], .enabled),
        ([record(awaiting: true)], .awaitingApproval),
        ([record()], .disabled),
        ([record(enabled: true, uninstalling: true)], .uninstalling),
        // A replacement awaiting approval does not hide the enabled version.
        ([record(enabled: true), record(awaiting: true)], .enabled),
        // A version being removed does not count as the enabled one.
        ([record(enabled: true, uninstalling: true), record(awaiting: true)], .awaitingApproval)
    ])
    func `OS records map to one install state`(records: [SystemExtensionRecord], expected: SystemExtensionInstallState) {
        #expect(SystemExtensionInstallState(records: records) == expected)
    }
    
    @Test
    func `A bundle without the identifier key refuses every request`() async {
        let bundle = Bundle(for: BundleToken.self)
        let service = SystemExtensionService(bundle: bundle)

#if os(macOS)
        let expected = SystemExtensionError.invalidIdentifier
#else
        let expected = SystemExtensionError.unsupportedPlatform
#endif
        await #expect(throws: expected) {
            for try await _ in service.activate() {}
        }
        await #expect(throws: expected) {
            for try await _ in service.deactivate() {}
        }
        await #expect(throws: expected) {
            try await service.installState()
        }
    }
}

private func record(enabled: Bool = false, awaiting: Bool = false, uninstalling: Bool = false) -> SystemExtensionRecord {
    SystemExtensionRecord(isEnabled: enabled, isAwaitingUserApproval: awaiting, isUninstalling: uninstalling)
}

/// Locates the test bundle, whose Info.plist has no extension identifier.
private final class BundleToken {}
