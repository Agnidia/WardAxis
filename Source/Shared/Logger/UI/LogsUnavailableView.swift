//
//  LogsUnavailableView.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// Placeholder shown on tvOS / watchOS / visionOS where the full Logs viewer
/// is intentionally not implemented in Phase 1. Keeps the build green across
/// all five platforms without leaking iOS/macOS-only APIs into other targets.
struct LogsUnavailableView: View {
    var body: some View {
        VStack(spacing: .spacing.l) {
            Image(systemName: Symbol.logs)
                .font(.system(size: IconSize.l))
                .foregroundStyle(.secondary)
            
            Text(L.Settings.Logs.unsupportedPlatform)
                .bodyLarge()
                .placeholderMessage()
        }
        .padding(.padding.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(L.Settings.Logs.title)
    }
}

#if PREVIEW_DEBUG

#Preview {
    LogsUnavailableView()
}

#endif
