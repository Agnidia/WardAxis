//
//  RawWebSocketClient.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import HummingbirdWSClient
import NIOCore
import NIOPosix
import NIOSSL
import NIOWebSocket

/// A WebSocket client for the live tests that reads the handshake response and every
/// frame from one byte stream.
///
/// WSClient upgrades through swift-nio's HTTP client pipeline, which loses a close frame
/// and the end of input that arrive in the same read as the `101` response: on end of
/// input `HTTPDecoder.decodeLast` drops its leftover bytes, and the `inputClosed` event
/// passes the pipeline before the WebSocket handlers are added. That client then waits for
/// a close frame that never comes. The server sends exactly this sequence when it closes a
/// stream before any frame (1008, 1011, 1013), so under load those tests timed out. This
/// client never switches pipelines, so nothing can fall between the handshake and the
/// frames.
enum RawWebSocketClient {
    enum ProtocolError: Error {
        case truncatedFrame
        case maskedServerFrame
        case frameTooLong
    }
    
    private enum Opcode {
        static let continuation: UInt8 = 0x0
        static let text: UInt8 = 0x1
        static let binary: UInt8 = 0x2
        static let close: UInt8 = 0x8
        static let ping: UInt8 = 0x9
        static let pong: UInt8 = 0xA
    }
    
    /// Runs one connection until the server's close frame or the end of the stream.
    ///
    /// Answers pings unless `answerPings` is `false`, as WSClient does while its inbound
    /// stream is read. After `onText` returns `true` the client sends close 1000 and waits
    /// for the server's reply.
    ///
    /// - Parameters:
    ///   - tlsConfiguration: Runs the connection over TLS with this client configuration,
    ///     host name `localhost`; `nil` speaks plain TCP.
    ///   - extraHeaders: Raw header lines added to the handshake, such as a spoofed identity.
    /// - Returns: The code of the server's close frame, 1005 when that frame has no code,
    ///   and `nil` when the stream ended without a close frame.
    /// - Throws: `WebSocketClientError.webSocketUpgradeFailed` when the response is not `101`,
    ///   and the TLS error when the server refuses the handshake.
    static func run(
        port: Int,
        path: String,
        tlsConfiguration: TLSConfiguration?,
        extraHeaders: [String] = [],
        answerPings: Bool = true,
        onText: @escaping @Sendable (String) async throws -> Bool
    ) async throws -> WebSocketErrorCode? {
        let sslContext = try tlsConfiguration.map { try NIOSSLContext(configuration: $0) }
        let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            // Keeps the output open after the server's end of output, to answer its close.
            .channelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
            .connect(host: "localhost", port: port) { channel in
                channel.eventLoop.makeCompletedFuture {
                    if let sslContext {
                        try channel.pipeline.syncOperations.addHandler(NIOSSLClientHandler(context: sslContext, serverHostname: "localhost"))
                    }
                    return try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                }
            }
        return try await channel.executeThenClose { inbound, outbound in
            var reader = ByteReader(inbound.makeAsyncIterator())
            try await outbound.write(ByteBuffer(string: handshake(port: port, path: path, extraHeaders: extraHeaders)))
            guard try await reader.readResponseStatus() == 101 else {
                throw WebSocketClientError.webSocketUpgradeFailed
            }
            var closing = false
            var message = ByteBuffer()
            var messageIsText = false
            while let frame = try await reader.readFrame() {
                switch frame.opcode {
                case Opcode.text, Opcode.binary, Opcode.continuation:
                    guard !closing else { continue }
                    if frame.opcode != Opcode.continuation {
                        messageIsText = frame.opcode == Opcode.text
                        message.clear()
                    }
                    var payload = frame.payload
                    message.writeBuffer(&payload)
                    guard frame.fin, messageIsText else { continue }
                    if try await onText(String(buffer: message)) {
                        var normal = ByteBuffer()
                        normal.writeInteger(UInt16(1000))
                        try await outbound.write(clientFrame(opcode: Opcode.close, payload: normal))
                        closing = true
                    }
                case Opcode.ping:
                    guard !closing, answerPings else { continue }
                    try await outbound.write(clientFrame(opcode: Opcode.pong, payload: frame.payload))
                case Opcode.close:
                    let code = frame.payload.getInteger(at: frame.payload.readerIndex, as: UInt16.self)
                    if !closing, let echo = frame.payload.getSlice(at: frame.payload.readerIndex, length: code == nil ? 0 : 2) {
                        // The server may already be gone; its close frame is what the test needs.
                        try? await outbound.write(clientFrame(opcode: Opcode.close, payload: echo))
                    }
                    return WebSocketErrorCode(codeNumber: code.map(Int.init) ?? 1005)
                default:
                    continue
                }
            }
            return nil
        }
    }
    
    private static func handshake(port: Int, path: String, extraHeaders: [String]) -> String {
        let key = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) }).base64EncodedString()
        var lines = [
            "GET \(path) HTTP/1.1",
            "Host: localhost:\(port)",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Key: \(key)",
            "Sec-WebSocket-Version: 13"
        ]
        lines.append(contentsOf: extraHeaders)
        return lines.joined(separator: "\r\n") + "\r\n\r\n"
    }
    
    /// A masked frame, as RFC 6455 requires of a client. The client sends control frames
    /// only, whose payload is at most 125 bytes.
    private static func clientFrame(opcode: UInt8, payload: ByteBuffer) -> ByteBuffer {
        let bytes = Array(payload.readableBytesView)
        precondition(bytes.count < 126, "Control frame payloads are at most 125 bytes")
        let mask = (0..<4).map { _ in UInt8.random(in: .min ... .max) }
        var frame = ByteBuffer()
        frame.writeInteger(0x80 | opcode)
        frame.writeInteger(0x80 | UInt8(bytes.count))
        frame.writeBytes(mask)
        frame.writeBytes(bytes.enumerated().map { $0.element ^ mask[$0.offset % 4] })
        return frame
    }
}

private struct ServerFrame {
    let fin: Bool
    let opcode: UInt8
    let payload: ByteBuffer
}

/// Buffers inbound bytes so the response head and the frames can span chunk boundaries.
private struct ByteReader {
    private var iterator: NIOAsyncChannelInboundStream<ByteBuffer>.AsyncIterator
    private var buffer = ByteBuffer()
    
    init(_ iterator: NIOAsyncChannelInboundStream<ByteBuffer>.AsyncIterator) {
        self.iterator = iterator
    }
    
    /// The status code of the response head; `nil` when the stream ends first or the
    /// status line is malformed.
    mutating func readResponseStatus() async throws -> Int? {
        while true {
            if let length = headLength() {
                let head = buffer.readString(length: length) ?? ""
                let statusLine = head.prefix { $0 != "\r" }.split(separator: " ")
                return statusLine.count >= 2 ? Int(statusLine[1]) : nil
            }
            guard try await readChunk() else { return nil }
        }
    }
    
    /// The next server frame; `nil` when the stream ends between frames.
    mutating func readFrame() async throws -> ServerFrame? {
        guard try await fill(2) else {
            guard buffer.readableBytes == 0 else { throw RawWebSocketClient.ProtocolError.truncatedFrame }
            return nil
        }
        let first = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) ?? 0
        let second = buffer.getInteger(at: buffer.readerIndex + 1, as: UInt8.self) ?? 0
        guard second & 0x80 == 0 else { throw RawWebSocketClient.ProtocolError.maskedServerFrame }
        let extendedLengthBytes = switch second & 0x7F {
        case 126: 2
        case 127: 8
        default: 0
        }
        guard try await fill(2 + extendedLengthBytes) else { throw RawWebSocketClient.ProtocolError.truncatedFrame }
        buffer.moveReaderIndex(forwardBy: 2)
        let length: Int? = switch extendedLengthBytes {
        case 2: buffer.readInteger(as: UInt16.self).map(Int.init)
        case 8: buffer.readInteger(as: UInt64.self).flatMap { Int(exactly: $0) }
        default: Int(second & 0x7F)
        }
        guard let length else { throw RawWebSocketClient.ProtocolError.frameTooLong }
        guard try await fill(length), let payload = buffer.readSlice(length: length) else {
            throw RawWebSocketClient.ProtocolError.truncatedFrame
        }
        return ServerFrame(fin: first & 0x80 != 0, opcode: first & 0x0F, payload: payload)
    }
    
    /// Reads until `count` bytes are buffered; `false` when the stream ends first.
    private mutating func fill(_ count: Int) async throws -> Bool {
        while buffer.readableBytes < count {
            guard try await readChunk() else { return false }
        }
        return true
    }
    
    private mutating func readChunk() async throws -> Bool {
        guard var chunk = try await iterator.next() else { return false }
        buffer.writeBuffer(&chunk)
        return true
    }
    
    /// The length of the response head including its blank line, once it is buffered.
    private func headLength() -> Int? {
        let bytes = Array(buffer.readableBytesView)
        let terminator: [UInt8] = [13, 10, 13, 10]
        guard bytes.count >= terminator.count else { return nil }
        for start in 0...bytes.count - terminator.count where bytes[start..<start + terminator.count].elementsEqual(terminator) {
            return start + terminator.count
        }
        return nil
    }
}
