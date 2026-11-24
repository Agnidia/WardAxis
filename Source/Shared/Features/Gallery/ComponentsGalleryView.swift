//
//  ComponentsGalleryView.swift
//
//  Created on 05.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

// Developer showcase only: never compiled into a shipped build.
#if DEBUG

// MARK: - Components Gallery

/// Runtime showcase of every shared design-system control.
///
/// Renders one or more live instances of each control under the project's
/// Topology tokens and semantic colors. Useful as a visual smoke test when
/// porting the design system or auditing accessibility coverage.
@MainActor
struct ComponentsGalleryView: View {
    // MARK: - State
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText: String = ""
    @State private var formText: String = ""
    @State private var selectedChip: String?
    @State private var toggleValue: Bool = true
    
    private let logger = Log(category: .ui)
    
    private let chipOptions: [String] = ["All", "Featured", "New", "Sale"]
    private let flowTags: [String] = [
        "Sale", "New", "Hot", "Trending", "Limited",
        "Exclusive", "Featured", "Recommended", "Bestseller", "Editor's Pick"
    ]
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacing.xxl) {
                badgesAndPillsSection
                inputsSection
                displaySection
                layoutSection
                feedbackSection
            }
            .padding(.padding.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.Background.primary)
        .navigationTitle("Components")
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton(accessibility: GalleryBackAccessibility()) {
                    dismiss()
                }
            }
#else
            ToolbarItem(placement: .automatic) {
                BackButton(accessibility: GalleryBackAccessibility()) {
                    dismiss()
                }
            }
#endif
        }
        .onAppear {
            logger.debug("ComponentsGalleryView appeared")
        }
    }
    
    // MARK: - Sections
    
    private var badgesAndPillsSection: some View {
        VStack(alignment: .leading, spacing: .spacing.m) {
            sectionHeader("Badges & Pills")
            
            // IconBadge — 2 sizes / 2 semantic colors
            HStack(spacing: .spacing.xl) {
                IconBadge.medium(systemName: "checkmark", color: .State.success)
                IconBadge.medium(systemName: "exclamationmark.triangle.fill", color: .State.warning)
            }
            
            // TagPill — 3 tags
            HStack(spacing: .spacing.m) {
                TagPill(tag: "New")
                TagPill(tag: "Hot")
                TagPill(tag: "Featured")
            }
            
            // ErrorTag — sample message
            ErrorTag(message: "Sample error message")
            
            // SelectableChip — single-select among 4
            HStack(spacing: .spacing.m) {
                ForEach(chipOptions, id: \.self) { option in
                    SelectableChip(
                        title: LocalizedStringKey(option),
                        isSelected: selectedChip == option,
                        accessibility: GalleryChipAccessibility()
                    ) {
                        selectedChip = (selectedChip == option) ? nil : option
                        logger.debug("Chip tapped: \(option)")
                    }
                }
            }
        }
    }
    
    private var inputsSection: some View {
        VStack(alignment: .leading, spacing: .spacing.m) {
            sectionHeader("Inputs")
            
            FormTextField(
                label: "Form Field",
                placeholder: "Enter value",
                text: $formText,
                accessibility: GalleryFormFieldAccessibility()
            )
            
            SearchField(
                placeholder: "Search components",
                text: $searchText,
                accessibility: GallerySearchAccessibility()
            )
        }
    }
    
    private var displaySection: some View {
        VStack(alignment: .leading, spacing: .spacing.m) {
            sectionHeader("Display")
            
            // CustomLabel — title only and long-title variants
            CustomLabel(title: "Settings")
            CustomLabel(
                title: "A long localized title that flows across available width"
            )
            
        }
    }
    
    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: .spacing.m) {
            sectionHeader("Layout")
            
            // RowView — 2 rows: simple + chevron + leading icon
            VStack(spacing: .spacing.s) {
                RowView(
                    label: "Simple Row",
                    backgroundColor: Color.Background.secondary,
                    accessibility: GalleryRowAccessibility()
                ) {
                    logger.debug("Simple row tapped")
                }
                
                RowView(
                    label: "Privacy",
                    backgroundColor: Color.Background.secondary,
                    accessibility: GalleryRowAccessibility(),
                    action: {
                        logger.debug("Privacy row tapped")
                    },
                    leading: {
                        Image(systemName: "lock")
                            .frame(width: IconSize.s, height: IconSize.s)
                            .padding(.trailing, .padding.s)
                            .foregroundStyle(Color.Label.primary)
                    },
                    trailing: {
                        Image(systemName: "chevron.right")
                            .frame(width: IconSize.s, height: IconSize.s)
                            .foregroundStyle(Color.Label.primary)
                    }
                )
            }
            
            // FlowLayout — wrap 10 TagPills
            FlowLayout(spacing: .spacing.s) {
                ForEach(flowTags, id: \.self) { tag in
                    TagPill(tag: tag)
                }
            }
        }
    }
    
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: .spacing.m) {
            sectionHeader("Feedback")
            
            // ProgressDots — animated/active
            SimpleProgressDots(totalSteps: 5, currentStep: 2)

            
            // AccentAlert — inline static instance
            AccentAlert(
                message: "Loading content",
                style: .accent,
                isLoading: true
            )
            
            // BannerAlert — inline static info
            BannerAlert(
                message: "Limited stock — capped at 5 per order",
                type: .info
            )
            
            // ToggleRow — bound state
            ToggleRow(
                label: "Notifications",
                isOn: $toggleValue,
                showDivider: false,
                accessibility: GalleryToggleAccessibility()
            )
        }
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .labelBold()
            .foregroundStyle(Color.Label.primary)
    }
}

// MARK: - Accessibility Helpers

private struct GalleryBackAccessibility: AccessibilityProtocol {
    var label: String {
        "Back"
    }
    
    var hint: String {
        "Double tap to navigate back"
    }
    
    var id: String {
        "gallery.back"
    }
}

private struct GalleryChipAccessibility: AccessibilityProtocol {
    var label: String {
        "Filter"
    }
    
    var hint: String {
        "Double tap to toggle"
    }
    
    var id: String {
        "gallery.chip"
    }
}

private struct GalleryFormFieldAccessibility: AccessibilityProtocol {
    var label: String {
        "Gallery field"
    }
    
    var hint: String {
        "Enter text"
    }
    
    var id: String {
        "gallery.form"
    }
}

private struct GallerySearchAccessibility: AccessibilityProtocol {
    var label: String {
        "Search components"
    }
    
    var hint: String {
        "Enter search query"
    }
    
    var id: String {
        "gallery.search"
    }
}

private struct GalleryRowAccessibility: AccessibilityProtocol {
    var label: String {
        "Gallery row"
    }
    
    var hint: String {
        "Double tap to select"
    }
    
    var id: String {
        "gallery.row"
    }
}

private struct GalleryToggleAccessibility: AccessibilityProtocol {
    var label: String {
        "Notifications toggle"
    }
    
    var hint: String {
        "Double tap to toggle"
    }
    
    var id: String {
        "gallery.toggle"
    }
}

// MARK: - Preview

#if DEBUG

#Preview {
    NavigationStack {
        ComponentsGalleryView()
    }
}

#endif
#endif
