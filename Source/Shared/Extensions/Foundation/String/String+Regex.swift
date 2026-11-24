//
//  String+Regex.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import WardAxisTelemetry

/// An extension for `String` that provides methods for searching regular expression matches.
public extension String {
    private static let logger = Log(category: .application)
    
    /// Searches for all matches of a regular expression within the string.
    ///
    /// - Parameters:
    ///   - regex: The regular expression pattern to search for.
    ///
    /// - Returns: An array of `String` that represent the matches. Returns `nil` if the regular expression is invalid or no match is found.
    func matches(for regex: String) -> [String]? {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let nsString = self as NSString
            let results = regex.matches(in: self, range: NSRange(location: 0, length: nsString.length))
            
            return results.map { nsString.substring(with: $0.range(at: 0)) }
        } catch {
            Self.logger.warning("Invalid regex pattern: \(error.localizedDescription)")
            
            return nil
        }
    }
    
    /// Checks if the string contains any matches for a regular expression.
    ///
    /// - Parameters:
    ///   - regex: The regular expression pattern to search for.
    ///
    /// - Returns: `true` if at least one match is found, `false` otherwise. Returns `false` if the regular expression is invalid.
    func isMatches(for regex: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let nsString = self as NSString
            let results = regex.matches(in: self, range: NSRange(location: 0, length: nsString.length))
            
            return !results.isEmpty
        } catch {
            Self.logger.warning("Invalid regex pattern: \(error.localizedDescription)")
            
            return false
        }
    }
}
