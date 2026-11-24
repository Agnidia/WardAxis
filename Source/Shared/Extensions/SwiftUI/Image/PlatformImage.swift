//
//  PlatformImage.swift
//
//  Created on 05.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import SwiftUI

// MARK: - Platform Image

#if canImport(UIKit)
/// Cross-platform image type alias.
///
/// Resolves to `UIImage` on iOS, iPadOS, tvOS, watchOS, and visionOS, and to
/// `NSImage` on macOS. Use this alias when authoring shared image-handling
/// code that must compile on every Apple platform without `#if` branches at
/// the call site.
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
/// Cross-platform image type alias.
///
/// Resolves to `UIImage` on iOS, iPadOS, tvOS, watchOS, and visionOS, and to
/// `NSImage` on macOS. Use this alias when authoring shared image-handling
/// code that must compile on every Apple platform without `#if` branches at
/// the call site.
public typealias PlatformImage = NSImage
#endif

// MARK: - SwiftUI Image Bridge

public extension Image {
    /// Creates a SwiftUI `Image` from a ``PlatformImage``.
    ///
    /// Bridges to `Image(uiImage:)` on UIKit-bearing platforms and to
    /// `Image(nsImage:)` on AppKit. Letting callers stay platform-agnostic
    /// when displaying decoded image data sourced from disk, network, or
    /// any other ``PlatformImage`` producer.
    ///
    /// - Parameter platformImage: A decoded ``PlatformImage`` instance.
    init(platformImage: PlatformImage) {
#if canImport(UIKit)
        self.init(uiImage: platformImage)
#elseif canImport(AppKit)
        self.init(nsImage: platformImage)
#endif
    }
}
