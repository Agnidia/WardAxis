//
//  IconBadge.swift
//
//  Created on 05.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Icon Badge

/// Circular icon badge for empty states, status and feature highlights.
///
/// Displays an icon centered inside a tinted circle. Use convenience static
/// initialisers (`.small`, `.medium`, `.large`, `.hero`) for the standard sizes.
struct IconBadge: View {
    let color: Color
    let size: CGFloat
    
    private let content: IconContent
    
    private enum IconContent {
        case system(String)
        case resource(ImageResource)
    }
    
    init(
        icon: ImageResource,
        color: Color = .Label.primary,
        size: CGFloat = IconBadgeSize.l
    ) {
        content = .resource(icon)
        self.color = color
        self.size = size
    }
    
    init(
        systemName: String,
        color: Color = .Label.primary,
        size: CGFloat = IconBadgeSize.l
    ) {
        content = .system(systemName)
        self.color = color
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(.opacity.light))
                .frame(width: size, height: size)
            
            iconView
                .foregroundStyle(color)
        }
        .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private var iconView: some View {
        switch content {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.42))
        case .resource(let resource):
            Image(resource)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.42, height: size * 0.42)
        }
    }
}

// MARK: - Convenience Initializers

extension IconBadge {
    static func small(systemName: String, color: Color = .Label.primary) -> IconBadge {
        IconBadge(systemName: systemName, color: color, size: IconBadgeSize.s)
    }
    
    static func medium(systemName: String, color: Color = .Label.primary) -> IconBadge {
        IconBadge(systemName: systemName, color: color, size: IconBadgeSize.m)
    }
    
    static func large(systemName: String, color: Color = .Label.primary) -> IconBadge {
        IconBadge(systemName: systemName, color: color, size: IconBadgeSize.l)
    }
    
    static func hero(systemName: String, color: Color = .Label.primary) -> IconBadge {
        IconBadge(systemName: systemName, color: color, size: IconBadgeSize.xl)
    }
    
    static func small(icon: ImageResource, color: Color = .Label.primary) -> IconBadge {
        IconBadge(icon: icon, color: color, size: IconBadgeSize.s)
    }
    
    static func medium(icon: ImageResource, color: Color = .Label.primary) -> IconBadge {
        IconBadge(icon: icon, color: color, size: IconBadgeSize.m)
    }
    
    static func large(icon: ImageResource, color: Color = .Label.primary) -> IconBadge {
        IconBadge(icon: icon, color: color, size: IconBadgeSize.l)
    }
    
    static func hero(icon: ImageResource, color: Color = .Label.primary) -> IconBadge {
        IconBadge(icon: icon, color: color, size: IconBadgeSize.xl)
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Icon Badge Sizes") {
    VStack(spacing: .spacing.xxxl) {
        IconBadge.small(systemName: "checkmark")
        IconBadge.medium(systemName: "sparkles")
        IconBadge.large(systemName: "person.fill")
        IconBadge.hero(systemName: "heart.fill")
    }
    .padding()
    .background(Color.Background.primary)
}

#Preview("Icon Badge Colors") {
    HStack(spacing: 16) {
        IconBadge(systemName: "checkmark", color: .State.success)
        IconBadge(systemName: "xmark", color: .State.error)
        IconBadge(systemName: "exclamationmark.triangle.fill", color: .State.warning)
        IconBadge(systemName: "star.fill", color: .State.accent)
    }
    .padding()
    .background(Color.Background.primary)
}

#endif
