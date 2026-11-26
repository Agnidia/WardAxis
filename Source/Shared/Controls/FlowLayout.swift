//
//  FlowLayout.swift
//
//  Created on 05.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Flow Layout

/// Wraps subviews onto subsequent lines when they overflow the available width.
///
/// Use as a `Layout` for tag clouds, filter chips, or any other content that
/// should reflow rather than scroll horizontally.
struct FlowLayout: Layout {
    var spacing: CGFloat = .spacing.m
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        arrangeSubviews(proposal: proposal, subviews: subviews).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = .zero
        var currentY: CGFloat = .zero
        var lineHeight: CGFloat = .zero
        var maxX: CGFloat = .zero
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > .zero {
                currentX = .zero
                currentY += lineHeight + spacing
                lineHeight = .zero
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }
        
        return (
            size: CGSize(width: maxX, height: currentY + lineHeight),
            positions: positions
        )
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Flow Layout") {
    let shortTags = ["Sale", "New", "Hot"]
    let longTags = [
        "Sale", "New", "Hot", "Trending", "Limited", "Exclusive",
        "Featured", "Recommended", "Bestseller", "Editor's Pick",
        "Free Shipping", "Member Only"
    ]
    let singleTag = ["Solo"]
    
    return VStack(alignment: .leading, spacing: .spacing.xxl) {
        FlowLayout(spacing: .spacing.m) {
            ForEach(shortTags, id: \.self) { tag in
                TagPill(tag: tag)
            }
        }
        
        FlowLayout(spacing: .spacing.m) {
            ForEach(longTags, id: \.self) { tag in
                TagPill(tag: tag)
            }
        }
        
        FlowLayout(spacing: .spacing.m) {
            ForEach(singleTag, id: \.self) { tag in
                TagPill(tag: tag)
            }
        }
    }
    .padding(.padding.l)
    .frame(width: 320, alignment: .leading)
    .background(Color.Background.primary)
}

#endif
