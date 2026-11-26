//
//  SizeClassAdaptiveView.swift
//
//  Created on 10.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// A horizontal size class that also exists on macOS.
///
/// SwiftUI's `UserInterfaceSizeClass` is unavailable on macOS, so the
/// override parameter of ``SizeClassAdaptiveView`` uses this type instead.
public enum AdaptiveSizeClass: Sendable {
    case compact
    case regular
}

/// Shows one of two layouts depending on the horizontal size class.
///
/// On macOS the view always shows the regular layout. On other platforms it
/// follows `horizontalSizeClass`; an unknown size class falls back to regular.
public struct SizeClassAdaptiveView<RegularContent: View, CompactContent: View>: View {
    private let sizeClassOverride: AdaptiveSizeClass?
    private let regular: () -> RegularContent
    private let compact: () -> CompactContent

#if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    /// - Parameters:
    ///   - sizeClass: Forces a layout, for example in previews. `nil` follows the environment.
    ///   - regular: The layout for the regular size class.
    ///   - compact: The layout for the compact size class.
    public init(
        sizeClass: AdaptiveSizeClass? = nil,
        @ViewBuilder regular: @escaping () -> RegularContent,
        @ViewBuilder compact: @escaping () -> CompactContent
    ) {
        sizeClassOverride = sizeClass
        self.regular = regular
        self.compact = compact
    }
    
    public var body: some View {
        if resolvedSizeClass == .compact {
            compact()
        } else {
            regular()
        }
    }
    
    private var resolvedSizeClass: AdaptiveSizeClass {
        if let sizeClassOverride {
            return sizeClassOverride
        }
#if os(macOS)
        return .regular
#else
        return horizontalSizeClass == .compact ? .compact : .regular
#endif
    }
}

#Preview("Regular") {
    SizeClassAdaptiveView(sizeClass: .regular) {
        Text(verbatim: "Regular")
    } compact: {
        Text(verbatim: "Compact")
    }
}

#Preview("Compact") {
    SizeClassAdaptiveView(sizeClass: .compact) {
        Text(verbatim: "Regular")
    } compact: {
        Text(verbatim: "Compact")
    }
}
