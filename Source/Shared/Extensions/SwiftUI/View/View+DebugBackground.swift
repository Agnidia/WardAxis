//
//  View+DebugBackground.swift
//
//  Created on 26.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// A view modifier that overlays a randomly colored semi-transparent background on a view in debug builds.
///
/// This is useful for visually debugging view layouts by showing the bounds of each view with a distinct color.
/// The background color is randomly generated each time the view is rendered, making it easy to distinguish
/// between different views in the hierarchy.
struct ViewDebugBackground: ViewModifier {        
    /// Applies the modifier to the given content, overlaying a random semi-transparent background color in debug builds.
    ///
    /// - Parameter content: The view content to modify.
    /// - Returns: The modified view with a debug background in debug builds.
    func body(content: Content) -> some View {
        content
#if DEBUG
            .background(GeometryReader { _ -> Color in
                Color(
                    red: .random(in: 0...1),
                    green: .random(in: 0...1),
                    blue: .random(in: 0...1),
                    opacity: 0.3
                )
            })
            .overlay(
                GeometryReader { proxy in
                    let width = Int(proxy.size.width.rounded())
                    let height = Int(proxy.size.height.rounded())
                    ZStack {
                        Text("\(width)x\(height)")
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .padding(2)
                            .background(Color.clear)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }
            )
#endif
    }
}

extension View {
    /// Overlays a randomly colored semi-transparent background on the view in debug builds.
    func debugBackground() -> some View {
        modifier(ViewDebugBackground())
    }
}
