//
//  SystemExtensionIdentifierTests.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
@testable import WardAxis

@Suite("System extension identifier")
struct SystemExtensionIdentifierTests {
    private let host = "com.agnidia.wardaxis"
    
    @Test
    func `The host Info.plist names the NetworkFilter extension under the app ID`() throws {
        let identifier = try SystemExtensionIdentifier.resolve(in: .main)
        
        #expect(identifier == "com.agnidia.wardaxis.networkfilter")
    }
    
    @Test
    func `A direct child of the host ID resolves`() throws {
        #expect(try SystemExtensionIdentifier.resolve(rawValue: "\(host).networkfilter", hostBundleID: host) == "\(host).networkfilter")
        #expect(try SystemExtensionIdentifier.resolve(rawValue: "\(host).network-filter2", hostBundleID: host) == "\(host).network-filter2")
    }
    
    @Test(arguments: [
        nil,
        "",
        "$(NETWORK_FILTER_BUNDLE_ID)",
        "com.agnidia.wardaxis.$(SUFFIX)",
        "com.agnidia.wardaxis",
        "com.agnidia.wardaxis.",
        "com.agnidia.wardaxisevil.networkfilter",
        "com.example.wardaxis.networkfilter",
        "com.agnidia.wardaxis.networkfilter.nested",
        "com.agnidia.wardaxis.network filter",
        "com.agnidia.wardaxis.network/filter",
        "com.agnidia.wardaxis.netwörkfilter",
        "com.agnidia.wardaxis.networkfilter\u{0}",
        "com.agnidia.wardaxis." + String(repeating: "a", count: 300)
    ] as [String?])
    func `A malformed or foreign identifier fails closed`(rawValue: String?) {
        #expect(throws: SystemExtensionError.invalidIdentifier) {
            try SystemExtensionIdentifier.resolve(rawValue: rawValue, hostBundleID: host)
        }
    }
    
    @Test(arguments: [nil, ""] as [String?])
    func `A missing host bundle ID fails closed`(hostBundleID: String?) {
        #expect(throws: SystemExtensionError.invalidIdentifier) {
            try SystemExtensionIdentifier.resolve(rawValue: ".networkfilter", hostBundleID: hostBundleID)
        }
    }
}
