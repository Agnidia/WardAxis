//
//  ConfigStream.swift
//
//  Created on 27.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

/// The parts of the `GET /config/stream` WebSocket contract that the generator does not emit.
///
/// The server and the client both read these values, so a change reaches both
/// sides of the trust boundary at once (ADR 0019). `ContractConstantsTests`
/// checks each value against `openapi.yaml`.
public enum ConfigStream {
    /// Relative to the contract's `servers` path, with no leading slash.
    public static let path = "config/stream"
    
    /// Close code 1000 with this reason ends a stream at its lifetime cap.
    public static let lifetimeReason = "lifetime"
}

/// WebSocket close codes (RFC 6455 § 7.4.1) that the config stream uses, and what each one means.
public enum ConfigStreamCloseCode {
    /// The stream ended normally, for example at its lifetime cap. The client reconnects.
    public static let normalClosure: UInt16 = 1000
    
    /// No pong arrived in time. The client reconnects.
    public static let goingAway: UInt16 = 1001
    
    /// The client identity is not allowed. The client stops until the enrollment changes.
    public static let policyViolation: UInt16 = 1008
    
    /// The server cannot serve a consistent configuration. The client reconnects.
    public static let internalError: UInt16 = 1011
    
    /// The server is starting or the identity holds too many streams. The client backs off.
    public static let tryAgainLater: UInt16 = 1013
}

/// Bounds on one config-stream text frame.
///
/// The client refuses a larger or deeper frame before any JSON decoding starts.
/// The server refuses to send one, so the two sides agree on what is valid and
/// an oversized configuration cannot cause a reconnect loop.
public enum ConfigStreamLimits {
    /// Largest text frame, in bytes.
    public static let maximumFrameBytes = 256 * 1024
    
    /// Deepest array or object nesting in one frame, envelope included.
    public static let maximumNestingDepth = 32
    
    /// Most settings one configuration may hold.
    public static let maximumEntryCount = 1024
}
