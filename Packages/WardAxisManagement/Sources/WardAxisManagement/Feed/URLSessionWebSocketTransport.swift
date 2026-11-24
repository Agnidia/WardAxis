//
//  URLSessionWebSocketTransport.swift
//
//  Created on 13.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Synchronization

/// ``ConfigurationStreamTransport`` over `URLSessionWebSocketTask`.
///
/// Each connection gets its own ephemeral session, because a session retains
/// its delegate until it is invalidated, and the delegate here belongs to one
/// connection.
public struct URLSessionWebSocketTransport: ConfigurationStreamTransport {
    public init() {}
    
    public func open(_ request: URLRequest, identity: ClientIdentity) -> AsyncStream<ConfigurationStreamEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: ConfigurationStreamEvent.self, bufferingPolicy: .unbounded)
        let connection = WebSocketConnection(continuation: continuation, identity: identity)
        let session = URLSession(configuration: .ephemeral, delegate: connection, delegateQueue: nil)
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = ConfigurationLimits.maximumMessageSize
        continuation.onTermination = { _ in
            task.cancel(with: .normalClosure, reason: nil)
            session.invalidateAndCancel()
        }
        task.resume()
        connection.receiveNext(on: task)
        return stream
    }
    
    /// The payload of a text frame. The contract sends text frames only, and a
    /// binary frame could carry encodings the strict pre-scan was not built for.
    static func payload(of message: URLSessionWebSocketTask.Message) -> Data? {
        switch message {
        case let .string(text):
            Data(text.utf8)
        case .data:
            nil
        @unknown default:
            nil
        }
    }
    
    /// Maps how a task ended to one close reason. A refused handshake surfaces as
    /// a task error with the HTTP response, not as a close code.
    static func close(closeCode: URLSessionWebSocketTask.CloseCode, response: URLResponse?, error: any Error? = nil) -> ConfigurationStreamClose {
        if closeCode != .invalid {
            return .closeCode(closeCode.rawValue)
        }
        if let code = (error as? URLError)?.code, clientCertificateFailures.contains(code) {
            return .clientCertificateRejected
        }
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 101 {
            return .handshakeRejected(statusCode: status)
        }
        return .connectionFailed
    }
    
    static let clientCertificateFailures: Set<URLError.Code> = [.clientCertificateRejected, .clientCertificateRequired]
    
    /// Only two challenges are answered: the server's trust goes to the system
    /// evaluation (ATS rules included), and a client-certificate request gets the
    /// device identity. Anything else, such as HTTP Basic, is cancelled, so no
    /// other credential can ever be offered on this socket.
    static func disposition(
        for method: String,
        identity: ClientIdentity
    ) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        switch method {
        case NSURLAuthenticationMethodServerTrust:
            (.performDefaultHandling, nil)
        case NSURLAuthenticationMethodClientCertificate:
            (.useCredential, identity.credential)
        default:
            (.cancelAuthenticationChallenge, nil)
        }
    }
}

/// The delegate and receive loop of one connection. Yields exactly one
/// `.closed`, whichever callback reports the end first.
private final class WebSocketConnection: NSObject, URLSessionWebSocketDelegate, Sendable {
    private let continuation: AsyncStream<ConfigurationStreamEvent>.Continuation
    private let identity: ClientIdentity
    private let isClosed = Mutex(false)
    
    init(continuation: AsyncStream<ConfigurationStreamEvent>.Continuation, identity: ClientIdentity) {
        self.continuation = continuation
        self.identity = identity
    }
    
    /// Keeps one receive outstanding at all times: the task answers the server's
    /// pings only while a receive is pending, and the server drops a client that
    /// misses pongs.
    func receiveNext(on task: URLSessionWebSocketTask) {
        task.receive { [self] result in
            switch result {
            case let .success(message):
                if let payload = URLSessionWebSocketTransport.payload(of: message) {
                    continuation.yield(.message(payload))
                }
                receiveNext(on: task)
            case .failure:
                // The close callbacks below carry the reason; the task always ends with one.
                break
            }
        }
    }
    
    func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didOpenWithProtocol _: String?) {
        continuation.yield(.opened)
    }
    
    func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason _: Data?
    ) {
        finish(.closeCode(closeCode.rawValue))
    }
    
    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: any Error?) {
        let closeCode = (task as? URLSessionWebSocketTask)?.closeCode ?? .invalid
        finish(URLSessionWebSocketTransport.close(closeCode: closeCode, response: task.response, error: error))
    }
    
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let (disposition, credential) = URLSessionWebSocketTransport.disposition(
            for: challenge.protectionSpace.authenticationMethod,
            identity: identity
        )
        completionHandler(disposition, credential)
    }
    
    /// A redirect would present the device identity to the host the `Location` names.
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
    
    private func finish(_ close: ConfigurationStreamClose) {
        let isFirst = isClosed.withLock { isClosed in
            defer { isClosed = true }
            return !isClosed
        }
        guard isFirst else { return }
        continuation.yield(.closed(close))
        // Runs onTermination, which cancels the task and invalidates the session.
        continuation.finish()
    }
}
