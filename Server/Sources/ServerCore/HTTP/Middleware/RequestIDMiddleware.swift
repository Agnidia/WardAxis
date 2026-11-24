//
//  RequestIDMiddleware.swift
//
//  Created on 11.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import HTTPTypes
import Hummingbird
import Logging

/// Gives every request an ID, puts it in the request logger's metadata and echoes it
/// in the `X-Request-ID` response header, error responses included.
///
/// An inbound `X-Request-ID` is kept for cross-proxy correlation only when it is a
/// short token of `[A-Za-z0-9._-]`; anything else is replaced, so a client cannot
/// write arbitrary text into the logs.
package struct RequestIDMiddleware: RouterMiddleware {
    package typealias Context = AppRequestContext
    
    package static let headerName: HTTPField.Name = .requestID
    package static let metadataKey: String = "request.id"
    package static let maximumLength: Int = 128
    
    package init() {}
    
    package func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        let requestID = Self.acceptedID(request.headers[Self.headerName]) ?? UUID().uuidString.lowercased()
        var context = context
        context.logger[metadataKey: Self.metadataKey] = .string(requestID)
        context.requestID = requestID
        
        var response: Response
        do {
            response = try await next(request, context)
        } catch let error as any HTTPResponseError {
            response = try error.response(from: request, context: context)
        } catch {
            // Converted here rather than by the server so the 500 still carries the ID.
            // The type only: an error description can carry request or driver details.
            context.logger.error("Unhandled error", metadata: ["error.type": "\(type(of: error))"])
            response = Response(status: .internalServerError)
        }
        response.headers[Self.headerName] = requestID
        return response
    }
    
    /// Returns `value` when it is a safe inbound ID, otherwise `nil`.
    package static func acceptedID(_ value: String?) -> String? {
        guard let value, (1...maximumLength).contains(value.utf8.count) else { return nil }
        let isSafe = value.utf8.allSatisfy { byte in
            switch byte {
            case UInt8(ascii: "A")...UInt8(ascii: "Z"),
                 UInt8(ascii: "a")...UInt8(ascii: "z"),
                 UInt8(ascii: "0")...UInt8(ascii: "9"),
                 UInt8(ascii: "."), UInt8(ascii: "_"), UInt8(ascii: "-"):
                true
            default:
                false
            }
        }
        return isSafe ? value : nil
    }
}

// MARK: - HTTPField.Name

extension HTTPField.Name {
    /// The literal is a valid token, so the failable initializer cannot return nil.
    static let requestID: HTTPField.Name = .init("X-Request-ID")!
}
