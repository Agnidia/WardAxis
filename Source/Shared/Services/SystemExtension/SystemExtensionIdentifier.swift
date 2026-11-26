//
//  SystemExtensionIdentifier.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation

/// Resolves the identifier of the NetworkFilter system extension from the app's Info.plist.
enum SystemExtensionIdentifier {
    /// Info.plist key that the build fills from `NETWORK_FILTER_BUNDLE_ID`.
    static let infoPlistKey = "WANetworkFilterBundleIdentifier"
    
    /// Upper bound for a bundle identifier, so a corrupt value cannot grow without limit.
    static let maxLength = 255
    
    /// Returns the identifier when it names a direct child of the host app's bundle ID.
    ///
    /// Fails closed (ADR 0006 D2): the OS activates only extensions embedded in the
    /// calling app, but the app still rejects any value outside its own namespace.
    /// The check catches a build-setting error before the OS sees it. Rejected:
    /// a missing, empty, oversize or unexpanded (`$(…)`) value; another prefix; a
    /// sibling such as `<host>evil.x`; nested segments; and characters outside
    /// `[A-Za-z0-9-]`.
    static func resolve(rawValue: String?, hostBundleID: String?) throws(SystemExtensionError) -> String {
        guard let rawValue, let hostBundleID, !hostBundleID.isEmpty,
              rawValue.utf8.count <= maxLength
        else {
            throw .invalidIdentifier
        }
        let prefix = hostBundleID + "."
        guard rawValue.hasPrefix(prefix) else {
            throw .invalidIdentifier
        }
        let segment = rawValue.dropFirst(prefix.count)
        guard !segment.isEmpty,
              segment.unicodeScalars.allSatisfy({ $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-") })
        else {
            throw .invalidIdentifier
        }
        return rawValue
    }
    
    /// Resolves the identifier from a bundle's Info.plist and bundle ID.
    static func resolve(in bundle: Bundle) throws(SystemExtensionError) -> String {
        try resolve(
            rawValue: bundle.object(forInfoDictionaryKey: infoPlistKey) as? String,
            hostBundleID: bundle.bundleIdentifier
        )
    }
}
