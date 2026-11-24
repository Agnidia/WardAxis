//
//  ConfigurationWireTests.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
import WardAxisManagementTestSupport
@testable import WardAxisManagement

@Suite("Configuration feed wire format")
struct ConfigurationWireTests {
    /// Unvalidated, so the request builder's own refusals are reached.
    private static func configuration(_ raw: String) -> APIConfiguration {
        APIConfiguration(baseURL: URL(string: raw)!)
    }
    
    /// A configuration as the app builds it, so the stream path carries the contract prefix.
    private static func resolved(_ raw: String, requiresHTTPS: Bool) throws -> APIConfiguration {
        try APIConfiguration.resolve(rawValue: raw, requiresHTTPS: requiresHTTPS)
    }
    
    // MARK: - Upgrade request
    
    @Test(arguments: [
        ("https://api.example.com", "wss://api.example.com/v1/config/stream"),
        ("https://api.example.com/", "wss://api.example.com/v1/config/stream")
    ])
    func `https becomes wss, /v1/config/stream is appended, and no credential header is sent`(base: String, expected: String) throws {
        let configuration = try Self.resolved(base, requiresHTTPS: true)
        let request = try #require(ConfigurationStreamRequest.make(configuration: configuration))
        
        #expect(request.url?.absoluteString == expected)
        #expect(request.url?.query == nil)
        #expect(request.httpMethod == "GET")
        #expect(request.allHTTPHeaderFields?.isEmpty ?? true)
    }
    
    @Test(arguments: [
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://[::1]:8080",
        "http://api.example.com"
    ])
    func `Cleartext is refused for every host, loopback included`(base: String) {
        #expect(ConfigurationStreamRequest.make(configuration: Self.configuration(base)) == nil)
    }
    
    @Test
    func `No configuration builds no request`() {
        #expect(ConfigurationStreamRequest.make(configuration: nil) == nil)
    }
    
    // MARK: - Frames
    
    @Test
    func `The spec's example frames decode`() {
        let decoder = ConfigurationFrameDecoder()
        
        #expect(decoder.decode(Data(#"{"type":"snapshot","version":41,"values":{"theme":"dark","maxItems":20}}"#.utf8))
            == .snapshot(ManagedConfiguration(version: 41, values: ["theme": .string("dark"), "maxItems": .integer(20)])))
        #expect(decoder.decode(Data(#"{"type":"delta","version":42,"changed":{"maxItems":25},"removed":["theme"]}"#.utf8))
            == .delta(version: 42, changed: ["maxItems": .integer(25)], removed: ["theme"]))
        #expect(decoder.decode(Data(#"{"type":"heartbeat","version":42}"#.utf8)) == .heartbeat(version: 42))
    }
    
    @Test
    func `Every JSON value kind keeps its kind through the generated container`() {
        let frame = #"{"type":"snapshot","version":1,"values":{"n":null,"b":false,"i":7,"w":3.0,"d":2.5,"s":"x","a":[1,"y",true],"o":{"k":-1}}}"#
        
        let decoded = ConfigurationFrameDecoder().decode(Data(frame.utf8))
        
        #expect(decoded == .snapshot(ManagedConfiguration(version: 1, values: [
            "n": .null,
            "b": .bool(false),
            "i": .integer(7),
            "w": .integer(3),
            "d": .number(2.5),
            "s": .string("x"),
            "a": .array([.integer(1), .string("y"), .bool(true)]),
            "o": .object(["k": .integer(-1)])
        ])))
    }
    
    @Test(arguments: [
        "not json",
        #"{"type":"rollback","version":40}"#,
        #"{"type":"heartbeat"}"#,
        #"{"type":"delta","version":2,"changed":{}}"#
    ])
    func `A payload that does not decode, or has an unknown type, yields no frame`(payload: String) {
        #expect(ConfigurationFrameDecoder().decode(Data(payload.utf8)) == nil)
    }
    
    // MARK: - Close routing
    
    @Test(arguments: [
        (ConfigurationStreamClose.closeCode(1008), ConfigurationCloseRoute.identityRejected),
        (.clientCertificateRejected, .identityRejected),
        (.handshakeRejected(statusCode: 401), .identityRejected),
        (.handshakeRejected(statusCode: 403), .identityRejected),
        (.closeCode(1013), .backOff),
        (.handshakeRejected(statusCode: 400), .backOff),
        (.handshakeRejected(statusCode: 404), .backOff),
        (.closeCode(1011), .reconnect),
        (.closeCode(1001), .reconnect),
        (.closeCode(1000), .reconnect),
        (.closeCode(4000), .backOff),
        (.connectionFailed, .backOff)
    ])
    func `Each close maps to its route`(close: ConfigurationStreamClose, route: ConfigurationCloseRoute) {
        #expect(ConfigurationCloseRoute.route(for: close) == route)
    }
    
    @Test
    func `A close code wins; otherwise a non-101 status is a refused handshake`() throws {
        let url = try #require(URL(string: "wss://api.example.com/v1/config/stream"))
        let refused = HTTPURLResponse(url: url, statusCode: 400, httpVersion: "HTTP/1.1", headerFields: nil)
        let switched = HTTPURLResponse(url: url, statusCode: 101, httpVersion: "HTTP/1.1", headerFields: nil)
        
        #expect(URLSessionWebSocketTransport.close(closeCode: .policyViolation, response: switched) == .closeCode(1008))
        #expect(URLSessionWebSocketTransport.close(closeCode: .invalid, response: refused) == .handshakeRejected(statusCode: 400))
        #expect(URLSessionWebSocketTransport.close(closeCode: .invalid, response: switched) == .connectionFailed)
        #expect(URLSessionWebSocketTransport.close(closeCode: .invalid, response: nil) == .connectionFailed)
    }
    
    @Test(arguments: [
        URLError.Code.clientCertificateRejected,
        .clientCertificateRequired
    ])
    func `A TLS failure over the client certificate maps to a rejected identity`(code: URLError.Code) {
        let close = URLSessionWebSocketTransport.close(closeCode: .invalid, response: nil, error: URLError(code))
        #expect(close == .clientCertificateRejected)
    }
    
    @Test
    func `Other TLS failures are an ordinary failed connection`() {
        let close = URLSessionWebSocketTransport.close(closeCode: .invalid, response: nil, error: URLError(.serverCertificateUntrusted))
        #expect(close == .connectionFailed)
    }
    
    // MARK: - Authentication challenges
    
    @Test
    func `A client-certificate challenge gets the device identity`() {
        let identity = ClientIdentity(testCredential: URLCredential(user: "test", password: "test", persistence: .none))
        let (disposition, credential) = URLSessionWebSocketTransport.disposition(
            for: NSURLAuthenticationMethodClientCertificate,
            identity: identity
        )
        #expect(disposition == .useCredential)
        #expect(credential === identity.credential)
    }
    
    @Test
    func `Server trust goes to the system evaluation`() {
        let identity = ClientIdentity(testCredential: URLCredential(user: "test", password: "test", persistence: .none))
        let (disposition, credential) = URLSessionWebSocketTransport.disposition(
            for: NSURLAuthenticationMethodServerTrust,
            identity: identity
        )
        #expect(disposition == .performDefaultHandling)
        #expect(credential == nil)
    }
    
    @Test(arguments: [
        NSURLAuthenticationMethodHTTPBasic,
        NSURLAuthenticationMethodHTTPDigest,
        NSURLAuthenticationMethodNTLM,
        NSURLAuthenticationMethodNegotiate,
        NSURLAuthenticationMethodDefault
    ])
    func `Every other challenge is cancelled, so no other credential is ever offered`(method: String) {
        let identity = ClientIdentity(testCredential: URLCredential(user: "test", password: "test", persistence: .none))
        let (disposition, credential) = URLSessionWebSocketTransport.disposition(for: method, identity: identity)
        #expect(disposition == .cancelAuthenticationChallenge)
        #expect(credential == nil)
    }
    
    // MARK: - Hostile nesting (SR0 T2)
    
    private static func nestedFrame(depth: Int) -> Data {
        let value = String(repeating: "[", count: depth) + String(repeating: "]", count: depth)
        return Data(#"{"type":"snapshot","version":1,"values":{"deep":\#(value)}}"#.utf8)
    }
    
    @Test
    @MainActor
    func `A frame nested far past the JSON decoder limit is skipped, never a crash`() {
        #expect(ConfigurationFrameDecoder().decode(Self.nestedFrame(depth: 5000)) == nil)
        // QA0 round 0 repro: this depth decoded on the main actor, then crashed FileConfigurationCache.save.
        #expect(ConfigurationFrameDecoder().decode(Self.nestedFrame(depth: 480)) == nil)
    }
    
    @Test
    func `A frame one level past the depth limit is skipped`() {
        #expect(ConfigurationFrameDecoder().decode(Self.nestedFrame(depth: 30)) != nil)
        #expect(ConfigurationFrameDecoder().decode(Self.nestedFrame(depth: 31)) == nil)
    }
    
    @Test
    func `UTF-16, UTF-32, an unchecked Unicode escape and a NUL byte never reach the decoder`() {
        for payload in HostilePayloads.all(envelope: #""type":"snapshot","version":1"#) {
            #expect(!ConfigurationLimits.isWithinBounds(payload.data), "\(payload.name)")
            #expect(ConfigurationFrameDecoder().decode(payload.data) == nil, "\(payload.name)")
        }
    }
    
    @Test(arguments: [
        #"[{"type":"heartbeat","version":1}]"#,
        #" {"type":"heartbeat","version":1}"#,
        #"{"type":"heartbeat","version":1}}{"#,
        #"{"type":"heartbeat","version":1"#,
        #"{"type":"heartbeat","s":"\q","version":1}"#,
        #"{"type":"heartbeat","s":"open"#
    ])
    func `Malformed structure fails the pre-scan`(payload: String) {
        #expect(!ConfigurationLimits.isWithinBounds(Data(payload.utf8)))
    }
    
    @Test
    func `Valid escapes pass the pre-scan`() {
        let frame = #"{"type":"snapshot","version":1,"values":{"s":"a\"b\\c\/d\b\f\n\r\t\u00e9\uD83D\uDE00"}}"#
        
        #expect(ConfigurationFrameDecoder().decode(Data(frame.utf8)) != nil)
    }
    
    @Test
    func `A binary frame carries no payload; a text frame carries its UTF-8 bytes`() {
        let json = ConfigFrames.heartbeat(1)
        
        #expect(URLSessionWebSocketTransport.payload(of: .data(Data(json.utf8))) == nil)
        #expect(URLSessionWebSocketTransport.payload(of: .string(json)) == Data(json.utf8))
    }
    
    @Test
    func `Decoding a value nested past the limit throws even without the pre-scan`() {
        let deep = String(repeating: "[", count: 40) + String(repeating: "]", count: 40)
        
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ConfigurationValue.self, from: Data(deep.utf8))
        }
    }
    
    @Test
    func `Brackets inside strings do not count toward the depth`() {
        let text = String(repeating: "[{", count: 100) + #"\"]"#
        let frame = #"{"type":"snapshot","version":1,"values":{"s":"\#(text)"}}"#
        
        #expect(ConfigurationFrameDecoder().decode(Data(frame.utf8)) != nil)
    }
    
    @Test
    func `A frame with more entries than the limit, or larger than the size limit, is skipped`() {
        func snapshot(entries: Int) -> Data {
            let pairs = (0..<entries).map { #""k\#($0)":\#($0)"# }.joined(separator: ",")
            return Data(#"{"type":"snapshot","version":1,"values":{\#(pairs)}}"#.utf8)
        }
        let padding = String(repeating: "x", count: ConfigurationLimits.maximumMessageSize)
        let oversized = Data(#"{"type":"snapshot","version":1,"values":{"s":"\#(padding)"}}"#.utf8)
        
        #expect(ConfigurationFrameDecoder().decode(snapshot(entries: ConfigurationLimits.maximumEntryCount)) != nil)
        #expect(ConfigurationFrameDecoder().decode(snapshot(entries: ConfigurationLimits.maximumEntryCount + 1)) == nil)
        #expect(ConfigurationFrameDecoder().decode(oversized) == nil)
    }
    
    @Test
    @MainActor
    func `A moderately nested frame decodes and survives a cache save and reload on a background thread`() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "ConfigurationWireTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = FileConfigurationCache(directory: root.appending(path: FileConfigurationCache.directoryName, directoryHint: .isDirectory))
        
        // The envelope and `values` take two of the 32 levels.
        for depth in [1, 16, 30] {
            let frame = ConfigurationFrameDecoder().decode(Self.nestedFrame(depth: depth))
            guard case .snapshot(let configuration)? = frame else {
                Issue.record("depth \(depth) did not decode")
                continue
            }
            try await cache.save(configuration)
            let reloaded = await Task.detached { await cache.load() }.value
            #expect(reloaded == configuration)
        }
    }
}
