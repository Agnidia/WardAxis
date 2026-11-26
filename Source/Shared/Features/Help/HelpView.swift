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
        .accessibilityIdentifier(AccessibilityID.Screen.help)
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
                answer: "Open the Home tab. It shows the protection status and links to Help and Settings."
            ),
            FAQItem(
                question: "How do I change settings?",
                answer: "Open the Settings tab or tap the gear icon in the Home screen toolbar to access app settings."
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

#if PREVIEW_DEBUG
#Preview {
    NavigationStack {
        HelpView()
    }
}
#endif
