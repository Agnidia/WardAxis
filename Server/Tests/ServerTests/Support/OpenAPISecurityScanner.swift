//
//  OpenAPISecurityScanner.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Reads the `servers` URL and each operation's path, method, `operationId` and `security`
/// from the contract's YAML text.
///
/// A line scanner for the layout the contract uses (2-space indents, paths under
/// `paths:`, one relative `servers` URL), so the contract checks need no YAML package. It
/// reads nothing else.
enum OpenAPISecurityScanner {
    enum Security: Equatable {
        /// `security: []`: no credential.
        case open
        /// The schemes a non-empty `security` list names.
        case schemes([String])
        /// A list with `{}` beside the named schemes: a call may come without a credential,
        /// and a credential it does send must fit one of the schemes.
        case optional([String])
        /// No `security` key: the operation would inherit a global default.
        case unspecified
    }

    struct Operation: Equatable {
        /// The path key, without the `servers` prefix.
        let path: String
        let method: String
        let operationID: String
        let security: Security
        /// The `servers` path the operation is served under; `/` adds no prefix.
        let serverPath: String

        /// The path a client sends: the `servers` path, then the path key.
        var requestPath: String {
            serverPath == "/" ? path : serverPath + path
        }
    }

    private static let methods: Set<String> = ["get", "put", "post", "delete", "patch", "head", "options", "trace"]

    /// The canonical contract, located from this file so the test runs from any directory.
    static var shippedSpecURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Support
            .deletingLastPathComponent() // ServerTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Server
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("Packages/WardAxisManagementAPI/Sources/WardAxisAPIServer/openapi.yaml")
    }

    static func shippedSpec() throws -> String {
        try String(contentsOf: shippedSpecURL, encoding: .utf8)
    }

    /// The first `servers` URL, or `/` when the contract has none, as OpenAPI specifies.
    static func serverPath(in spec: String) -> String {
        var inServers = false
        for rawLine in spec.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let indent = line.prefix { $0 == " " }.count
            let content = line.trimmingCharacters(in: .whitespaces)
            if content.isEmpty || content.hasPrefix("#") {
                continue
            }
            if indent == 0 {
                inServers = content == "servers:"
                continue
            }
            if inServers, indent == 2, content.hasPrefix("- url:") {
                return content.dropFirst("- url:".count).trimmingCharacters(in: .whitespaces)
            }
        }
        return "/"
    }

    static func operations(in spec: String) -> [Operation] {
        let serverPath = serverPath(in: spec)
        var operations: [Operation] = []
        var inPaths = false
        var path: String?
        var method: String?
        var operationID: String?
        var security: Security = .unspecified
        var readingSchemes = false
        // `{}` can sit anywhere in the list, so it is folded in only once the operation ends.
        var allowsAnonymous = false

        func flush() {
            if let path, let method, let operationID {
                var scanned = security
                if allowsAnonymous, case let .schemes(names) = security {
                    scanned = .optional(names)
                }
                operations.append(Operation(path: path, method: method, operationID: operationID, security: scanned, serverPath: serverPath))
            }
            operationID = nil
            security = .unspecified
            readingSchemes = false
            allowsAnonymous = false
        }

        for rawLine in spec.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let indent = line.prefix { $0 == " " }.count
            let content = line.trimmingCharacters(in: .whitespaces)
            if content.isEmpty || content.hasPrefix("#") {
                continue
            }

            if indent == 0 {
                flush()
                method = nil
                path = nil
                inPaths = content == "paths:"
                continue
            }
            guard inPaths else { continue }

            switch indent {
            case 2 where content.hasPrefix("/") && content.hasSuffix(":"):
                flush()
                method = nil
                path = String(content.dropLast())
            case 4 where content.hasSuffix(":") && methods.contains(String(content.dropLast())):
                flush()
                method = String(content.dropLast())
            case 6 where content.hasPrefix("operationId:"):
                operationID = content.dropFirst("operationId:".count).trimmingCharacters(in: .whitespaces)
                readingSchemes = false
            case 6 where content == "security: []":
                security = .open
                readingSchemes = false
                allowsAnonymous = false
            case 6 where content == "security:":
                security = .schemes([])
                readingSchemes = true
                allowsAnonymous = false
            case 6:
                readingSchemes = false
            // `- { }` is the same empty requirement as `- {}`.
            case 8 where readingSchemes && content.replacingOccurrences(of: " ", with: "") == "-{}":
                allowsAnonymous = true
            case 8 where readingSchemes && content.hasPrefix("- "):
                let scheme = content.dropFirst(2).split(separator: ":").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
                if case let .schemes(names) = security {
                    security = .schemes(names + [scheme])
                }
            default:
                break
            }
        }
        flush()
        return operations
    }
}
