//
//  PermissionsView.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

/// Permission request showcase demonstrating localized strings and accessibility.
///
/// Demonstrates:
/// - `L.Permissions.*` localized strings including interpolated strings
/// - `AccessibilityID.Permissions` identifiers
/// - Haptic feedback integration
/// - Topology design tokens
@MainActor
struct PermissionsView: View {
    @Environment(\.appContainer) private var container
    
    @State private var cameraGranted = false
    @State private var microphoneGranted = false
    
    private let logger = Log(category: .ui)
    
    var body: some View {
        ScrollView {
            VStack(spacing: CGFloat.spacing.xxl) {
                headerView
                
                PermissionCard(
                    icon: "camera.fill",
                    title: L.Permissions.Camera.title,
                    description: L.Permissions.Camera.description,
                    isGranted: $cameraGranted,
                    permissionName: "Camera",
                    onAllow: {
                        handlePermissionGrant("Camera")
                        cameraGranted = true
                    }
                )
                
                PermissionCard(
                    icon: "mic.fill",
                    title: L.Permissions.Microphone.title,
                    description: L.Permissions.Microphone.description,
                    isGranted: $microphoneGranted,
                    permissionName: "Microphone",
                    onAllow: {
                        handlePermissionGrant("Microphone")
                        microphoneGranted = true
                    }
                )
                
                Spacer(minLength: CGFloat.spacing.xxl)
            }
            .padding(CGFloat.padding.l)
        }
        .onAppear {
            logger.debug("PermissionsView appeared")
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: CGFloat.spacing.m) {
            Image(systemName: "lock.shield")
                .font(.system(size: IconSize.xl))
                .foregroundStyle(.tint)
                .accessibleDecorativeImage()
            
            Text(L.Permissions.required)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding(.vertical, CGFloat.padding.m)
    }
    
    // MARK: - Actions
    
    private func handlePermissionGrant(_ permission: String) {
        logger.info("Permission granted: \(permission)")
        container.hapticFeedback.playSuccess()
        AccessibilityAnnouncer.announce("\(permission) access granted")
    }
}

// MARK: - Permission Card

private struct PermissionCard: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    @Binding var isGranted: Bool
    let permissionName: String
    let onAllow: () -> Void
    
    var body: some View {
        VStack(spacing: CGFloat.spacing.l) {
            HStack(spacing: CGFloat.spacing.l) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.m))
                    .foregroundStyle(isGranted ? Color.green : Color.accentColor)
                    .frame(width: IconSize.l, height: IconSize.l)
                    .background(
                        RoundedRectangle(cornerRadius: CGFloat.radius.m)
                            .fill(isGranted ? Color.green.opacity(.opacity.light) : Color.accentColor.opacity(.opacity.light))
                    )
                    .accessibilityIdentifier(AccessibilityID.Permissions.icon.id)
                    .accessibleImage(label: "\(permissionName) permission icon")
                
                VStack(alignment: .leading, spacing: CGFloat.spacing.xs) {
                    Text(title)
                        .font(.headline)
                        .accessibilityIdentifier(AccessibilityID.Permissions.title.id)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(AccessibilityID.Permissions.description.id)
                }
                
                Spacer()
                
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                        .accessibleImage(label: "Granted")
                }
            }
            
            if !isGranted {
                Button(action: onAllow) {
                    Text(L.Permissions.allowButton(permission: permissionName))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CGFloat.spacing.m)
                }
                .buttonStyle(.borderedProminent)
                .accessible(AccessibilityID.Permissions.allowButton)
            }
        }
        .padding(CGFloat.padding.m)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.radius.l)
                .fill(.background)
                .shadow(radius: 2, y: 1)
        )
        .accessibilityAnnounce(
            "\(permissionName) permission granted",
            when: isGranted
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    PermissionsView()
        .environment(\.appContainer, AppContainer.preview())
}
#endif
