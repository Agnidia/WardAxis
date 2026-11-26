//
//  TagPill.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Tag Pill

struct TagPill: View {
    let tag: String
    
    var body: some View {
        Text(tag)
            .bodySmall()
            .foregroundStyle(Color.Text.white)
            .padding(.horizontal, .spacing.xl)
            .padding(.vertical, .spacing.m)
            .background(Color.Background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: .radius.xxxl))
    }
}

#if PREVIEW_DEBUG

#Preview {
    VStack {
        TagPill(tag: "Preview")
        
        TagPill(tag: "")
        
        TagPill(tag: "1")
    }
    .padding()
}

#endif
