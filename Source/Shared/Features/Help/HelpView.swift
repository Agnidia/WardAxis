//
//  HelpView.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

/// Help and FAQ view showcasing expandable content.
///
/// Demonstrates:
/// - `L.Help.*` localized strings
/// - DisclosureGroup for FAQ items
/// - Accessibility for expandable content
@MainActor
struct HelpView: View {
    @State private var expandedFAQ: String?
    
    private let logger = Log(category: .ui)
    
    var body: some View {
        List {
            Section {
                placeholderContent
            }
            
            Section(L.Help.faq) {
                ForEach(faqItems, id: \.question) { item in
                    faqRow(item)
                }
            }
            
            Section(L.Help.contact) {
                Link(destination: URL(string: "mailto:support@example.com")!) {
                    Label(L.Help.emailSupport, systemImage: "envelope")
                }
                
                Link(destination: URL(string: "https://example.com/help")!) {
                    Label(L.Help.visitHelpCenter, systemImage: "safari")
                }
            }
        }
        .navigationTitle(L.Help.title)
        .onAppear {
            logger.debug("HelpView appeared")
        }
    }
    
    // MARK: - Subviews
    
    private var placeholderContent: some View {
        VStack(alignment: .leading, spacing: CGFloat.spacing.m) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: IconSize.xl))
                .foregroundStyle(.tint)
                .accessibleDecorativeImage()
            
            Text(L.Help.placeholder)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, CGFloat.spacing.s)
    }
    
    @ViewBuilder
    private func faqRow(_ item: FAQItem) -> some View {
#if os(tvOS)
        // tvOS has no DisclosureGroup; the focus engine reads a static pair well.
        VStack(alignment: .leading, spacing: CGFloat.spacing.s) {
            Text(item.question)
                .font(.headline)
            Text(item.answer)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .focusable()
#else
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedFAQ == item.question },
                set: { isExpanded in
                    expandedFAQ = isExpanded ? item.question : nil
                    if isExpanded {
                        AccessibilityAnnouncer.announce("Expanded: \(item.question)")
                    }
                }
            )
        ) {
            Text(item.answer)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, CGFloat.spacing.s)
        } label: {
            Text(item.question)
                .font(.headline)
        }
#endif
    }
    
    // MARK: - Data
    
    private var faqItems: [FAQItem] {
        [
            FAQItem(
                question: "How do I get started?",
                answer: "Tap the Home tab and explore the available features. Each section demonstrates different aspects of the app."
            ),
            FAQItem(
                question: "How do I change settings?",
                answer: "Open the Settings tab or tap the gear icon in the Home screen toolbar to access app settings."
            ),
            FAQItem(
                question: "How do I enable permissions?",
                answer: "Navigate to the Permissions demo from the Home screen. Tap the Allow button for each permission you want to grant."
            ),
            FAQItem(
                question: "How do I contact support?",
                answer: "Use the Email Support or Visit Help Center links in the Contact section below."
            )
        ]
    }
}

// MARK: - FAQ Item Model

private struct FAQItem {
    let question: String
    let answer: String
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HelpView()
    }
}
