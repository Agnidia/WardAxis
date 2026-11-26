//
//  LogPrivacyTests.swift
//
//  Created on 24.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Testing
@testable import WardAxisTelemetry

@Suite("Log privacy defaults")
struct LogPrivacyTests {
    @Test
    func `A message without a privacy label is logged as private`() {
        let spy = PrivacySpy()
        spy.debug("host=example.com")
        spy.info("host=example.com")
        spy.warning("host=example.com")
        spy.error("host=example.com")
        #expect(spy.labels == [.private, .private, .private, .private])
    }
    
    @Test(
        arguments: [
            "/Applications/WardAxis.app/Contents/PlugIns/URLFilter.appex",
            "/Applications/WardAxis.app/Contents/Library/SystemExtensions/com.agnidia.wardaxis.filter.systemextension",
            "/Applications/WardAxis.app/Contents/XPCServices/Helper.xpc"
        ]
    )
    func `Extension bundles never get the plain-text file sink`(path: String) {
        #expect(!Log.isAppBundle(path: path))
    }
    
    @Test
    func `The containing app may write the file sink`() {
        #expect(Log.isAppBundle(path: "/Applications/WardAxis.app"))
    }
}

private final class PrivacySpy: LogProtocol, @unchecked Sendable {
    /// Single-threaded test use only.
    private(set) var labels: [Log.Privacy] = []
    
    var isEnabled: Bool {
        true
    }
    
    func debug(_: String, privacy: Log.Privacy) {
        labels.append(privacy)
    }
    
    func info(_: String, privacy: Log.Privacy) {
        labels.append(privacy)
    }
    
    func warning(_: String, privacy: Log.Privacy) {
        labels.append(privacy)
    }
    
    func error(_: String, privacy: Log.Privacy) {
        labels.append(privacy)
    }
}
