//
//  HostConfigurationTests.swift
//
//  Created on 24.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisManagement
@testable import WardAxis

/// Checks on the built app's Info.plist, which only the app test host can read.
@Suite("Host app configuration")
struct HostConfigurationTests {
    @Test
    func `The app declares no App Transport Security exception`() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") == nil)
    }
    
    @Test
    func `The app's APIBaseURL resolves under the current build's rule and composes to /v1`() throws {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: APIConfiguration.infoPlistKey) as? String
        
        let configuration = try APIConfiguration.resolve(rawValue: rawValue, requiresHTTPS: APIConfiguration.requiresHTTPS)
        
        #expect(configuration.baseURL.host() != nil)
        #expect(configuration.baseURL.path(percentEncoded: true) == "/v1")
    }
    
    @Test
    func `The bundle identifier is the WardAxis root`() {
        #expect(Bundle.main.bundleIdentifier == "com.agnidia.wardaxis")
    }
}
