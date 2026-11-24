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
        } else {
            EmptyView()
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

#if DEBUG

// Note: CustomLabel's `icon:` parameter is `ImageResource?` (asset-catalog-bound).
// This template ships only brand-asset imagesets, so the icon-only and title+icon
// variants cannot be rendered here without introducing a new asset (out of scope).
// The preview exercises the title-only and long-localized-title code paths; the
// icon code paths are visually validated by sibling controls (RowView, IconBadge)
// that already render `Image` instances under the same Topology tokens.
#Preview("Custom Label") {
    VStack(alignment: .leading, spacing: .spacing.xl) {
        CustomLabel(title: "Settings")
        
        CustomLabel(
            title: "A very long localized title that demonstrates how the label flows across available width"
        )
    }
    .padding(.padding.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.Background.primary)
}

#endif
