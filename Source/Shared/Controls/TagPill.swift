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
            .chipPadding()
            .background(Color.Background.secondary)
            .clipShape(.pill)
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
