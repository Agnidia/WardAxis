//
//  AlertPresenter.swift
//
//  Created on 21.02.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

// MARK: - Alert Presenter View Modifier

/// View modifier that presents in-app alerts with slide-from-top animation.
///
/// Usage:
/// ```swift
/// ContentView()
///     .alertPresenter(alertManager: container.alertManager)
/// ```
struct AlertPresenterModifier: ViewModifier {
    @Bindable var alertManager: AlertManager
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top, content: { 
                alertContent
            })
            .animation(
                .spring(response: AnimationDuration.normal, dampingFraction: AnimationDuration.slow),
                value: alertManager.currentAlert?.id
            )
    }
    
    @ViewBuilder
    private var alertContent: some View {
        if let alert = alertManager.currentAlert {
            Group {
                switch alert {
                case .accent(let message, let isLoading):
                    AccentAlert(
                        message: message,
                        style: .accent,
                        isLoading: isLoading,
                        onTap: { alertManager.dismiss() }
                    )
                
                case .banner(let message, let type):
                    BannerAlert(
                        message: message,
                        type: type,
                        onTap: { alertManager.dismiss() }
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, .padding.xxl)
                    .padding(.top, .spacing.m)
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - View Extension

extension View {
    /// Presents in-app alerts from the given alert manager.
    ///
    /// Alerts slide in from the top with spring animation and can be
    /// dismissed by tapping or automatically after a timeout.
    ///
    /// - Parameter alertManager: The alert manager to observe
    /// - Returns: A view that presents alerts
    func alertPresenter(alertManager: AlertManager) -> some View {
        modifier(AlertPresenterModifier(alertManager: alertManager))
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Alert Presenter - Accent") {
    @Previewable @State var alertManager = AlertManager()
    
    VStack {
        Text("Content underneath")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.Background.primary)
    }
    .alertPresenter(alertManager: alertManager)
    .onAppear {
        alertManager.show(.accent(message: "Loading...", isLoading: true))
    }
    .background(Color.Background.primary)
}

#Preview("Alert Presenter - Banner") {
    @Previewable @State var alertManager = AlertManager()
    
    VStack {
        Text("Content underneath")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.Background.primary)
    }
    .alertPresenter(alertManager: alertManager)
    .onAppear {
        alertManager.show(.banner(message: "Profile updated successfully", type: .success))
    }
    .background(Color.Background.primary)
}

#Preview("Alert Presenter - Interactive") {
    @Previewable @State var alertManager = AlertManager()
    
    VStack(spacing: .spacing.xxxl) {
        Button("Show Accent Alert") {
            alertManager.show(.accent(message: "Processing...", isLoading: true))
        }
        .buttonStyle(.main())
        
        Button("Show Info Banner") {
            alertManager.show(.banner(message: "Item added", type: .info))
        }
        .buttonStyle(.main())
        
        Button("Show Error Banner") {
            alertManager.show(.banner(message: "Verification failed", type: .error))
        }
        .buttonStyle(.main())
        
        Button("Show Success Banner") {
            alertManager.show(.banner(message: "Profile updated", type: .success))
        }
        .buttonStyle(.main())
        
        Button("Dismiss") {
            alertManager.dismiss()
        }
        .buttonStyle(.main())
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.Background.primary)
    .alertPresenter(alertManager: alertManager)
}

#endif
