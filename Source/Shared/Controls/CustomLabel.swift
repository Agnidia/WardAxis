//
//  CustomLabel.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// A SwiftUI view that displays a `Label` with a resizable image icon that scales to fit
/// alongside a localized title.
///
/// This component is useful when your asset's intrinsic size is larger than the intended
/// icon size and you want the icon to scale proportionally within the label's icon space.
///
/// Usage:
/// ```swift
/// CustomLabel(title: "Settings", imageName: "settings_icon")
/// ```
struct CustomLabel: View {
    /// The localized title displayed next to the icon.
    var title: LocalizedStringKey?
    
    /// The name of the icon asset to use for the label's icon.
    var icon: ImageResource?
    
    var iconSize: CGFloat = IconSize.s
    
    /// The content and behavior of the view.
    ///
    /// The icon image is made resizable and scaled to fit to avoid clipping and preserve
    /// aspect ratio within the label's icon area.
    var body: some View {
        if let title, let icon {
            Label {
                titleView(title)
            } icon: {
                imageView(icon)
            }
            .labelStyle(.titleAndIcon)
        } else if let title {
            titleView(title)
        } else if let icon {
            imageView(icon)
        }
    }
    
    private func titleView(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .scaledToFill()
    }
    
    private func imageView(_ image: ImageResource) -> some View {
        Image(image)
            .resizable()
            .frame(width: iconSize, height: iconSize)
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

/// Preview-only helper to fabricate an ImageResource from a system symbol name
/// so we can exercise icon code paths without shipping extra assets.
private extension ImageResource {
    static var preview: ImageResource {
        .gear
    }
}

#Preview("Custom Label") {
    VStack(alignment: .leading, spacing: .spacing.xxxl) {
        CustomLabel(title: "Settings")
        
        CustomLabel(
            title: "A very long localized title that demonstrates how the label flows across available width"
        )
    }
    .padding(.padding.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.Background.secondary)
}

#Preview("Custom Label – Title + Icon") {
    VStack(alignment: .leading, spacing: .spacing.xxxl) {
        CustomLabel(title: "Settings", icon: .preview)
        CustomLabel(title: "Long title with icon that wraps to the next line", icon: .preview)
    }
    .padding(.padding.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.Background.secondary)
}

#Preview("Custom Label – Icon Only") {
    HStack(spacing: .spacing.xl) {
        CustomLabel(icon: .preview)
        CustomLabel(icon: .preview, iconSize: IconSize.m)
        CustomLabel(icon: .preview, iconSize: IconSize.l)
    }
    .padding(.padding.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.Background.secondary)
}

#endif
