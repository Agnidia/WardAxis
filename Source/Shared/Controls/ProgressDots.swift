//
//  ProgressDots.swift
//
//  Created on 05.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Progress Dots

/// Horizontal progress dots indicator for multi-step flows.
///
/// Steps up to and including `currentStep` are highlighted with `activeColor`;
/// later steps are dimmed with `inactiveColor`.
struct ProgressDots<Step: CaseIterable & RawRepresentable & Hashable>: View where Step.RawValue: Comparable & Hashable {
    let currentStep: Step
    let activeColor: Color
    let inactiveColor: Color
    
    init(
        currentStep: Step,
        activeColor: Color = .Brand.primary,
        inactiveColor: Color = .Label.secondary
    ) {
        self.currentStep = currentStep
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    }
    
    var body: some View {
        HStack(spacing: .spacing.m) {
            ForEach(Array(Step.allCases), id: \.rawValue) { step in
                Circle()
                    .fill(isActive(step) ? activeColor : inactiveColor.opacity(.opacity.subtle))
                    .frame(width: IconSize.xs, height: IconSize.xs)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
    
    private func isActive(_ step: Step) -> Bool {
        step.rawValue <= currentStep.rawValue
    }
    
    private var accessibilityLabel: String {
        let allSteps = Array(Step.allCases)
        guard let currentIndex = allSteps.firstIndex(where: {
            "\($0.rawValue)" == "\(currentStep.rawValue)"
        }) else {
            return ""
        }
        return "Step \(currentIndex + 1) of \(allSteps.count)"
    }
}

// MARK: - Simple Progress Dots

/// Integer-based progress indicator alternative to `ProgressDots`.
struct SimpleProgressDots: View {
    let totalSteps: Int
    let currentStep: Int
    let activeColor: Color
    let inactiveColor: Color
    
    init(
        totalSteps: Int,
        currentStep: Int,
        activeColor: Color = .Brand.primary,
        inactiveColor: Color = .Label.secondary
    ) {
        self.totalSteps = totalSteps
        self.currentStep = currentStep
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    }
    
    var body: some View {
        HStack(spacing: .spacing.m) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? activeColor : inactiveColor.opacity(.opacity.subtle))
                    .frame(width: IconSize.xs, height: IconSize.xs)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Progress Dots") {
    VStack(spacing: 24) {
        SimpleProgressDots(totalSteps: 5, currentStep: 0)
        SimpleProgressDots(totalSteps: 5, currentStep: 2)
        SimpleProgressDots(totalSteps: 5, currentStep: 4)
    }
    .padding()
    .background(Color.Background.primary)
}

#endif
