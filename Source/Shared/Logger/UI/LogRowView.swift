//
//  LogRowView.swift
//
//  Created on 04.05.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import WardAxisTelemetry

#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// Single row in the Logs viewer list.
///
/// Layout:
/// `[Level chip] [HH:mm:ss.SSS] [category emoji] message`
///
/// `.raw` entries render as full-width monospaced text with a subtle
/// "raw" badge so unparseable lines remain inspectable.
///
/// Tapping the row toggles between truncated (2-line) and expanded
/// (full text) presentation of long messages. Long-pressing copies
/// `entry.rawLine` to the system pasteboard with a brief visual flash
/// (background tint + centred copy glyph that fades in/out).
struct LogRowView: View {
    private enum Constants {
        static let longPressDuration: Double = 0.4
        static let copyFeedbackDisplayDuration: Duration = .seconds(1.2)
    }
    
    let entry: LogEntry
    
    @State private var isExpanded: Bool = false
    @State private var isCopied: Bool = false
    
    private static let timestampFormatter = LogDateFormat.posixFormatter(LogDateFormat.timeWithMilliseconds)
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: AnimationDuration.fast)) {
                isExpanded.toggle()
            }
        } label: {
            content
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            copyFeedbackOverlay
        }
        .animation(.easeInOut(duration: AnimationDuration.normal), value: isCopied)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: Constants.longPressDuration)
                .onEnded { _ in copyRawLine() }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAction(named: Text(L.Settings.Logs.copyAction)) {
            copyRawLine()
        }
    }
    
    private var copyFeedbackOverlay: some View {
        Image(systemName: "doc.on.doc.fill")
            .font(.system(size: IconSize.s))
            .foregroundStyle(.tint)
            .padding(.spacing.s)
            .background(.regularMaterial, in: Circle())
            .opacity(isCopied ? .opacity.opaque : .opacity.transparent)
            .scaleEffect(isCopied ? Scale.base : Scale.x0_75)
            .allowsHitTesting(false)
    }
    
    private func copyRawLine() {
        writeToPasteboard(entry.rawLine)
        triggerHapticFeedback()
        isCopied = true
        Task { @MainActor in
            try? await Task.sleep(for: Constants.copyFeedbackDisplayDuration)
            isCopied = false
        }
    }
    
    /// Cross-platform pasteboard write. UIPasteboard on iOS / iPadOS / visionOS,
    /// NSPasteboard on macOS, no-op on tvOS / watchOS.
    private func writeToPasteboard(_ string: String) {
#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        UIPasteboard.general.string = string
#elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
#else
        // tvOS / watchOS — no pasteboard surface; copy is a no-op.
        _ = string
#endif
    }
    
    /// Tactile feedback on copy. iOS/iPadOS/visionOS only; no-op elsewhere.
    private func triggerHapticFeedback() {
#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
#endif
    }
    
    @ViewBuilder
    private var content: some View {
        switch entry.kind {
        case .parsed(let parsed): parsedRow(parsed)
        case .raw(let text): rawRow(text)
        }
    }
    
    // MARK: - Parsed row
    
    private func parsedRow(_ parsed: LogEntry.Parsed) -> some View {
        VStack(alignment: .leading, spacing: .spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: .spacing.m) {
                Text(parsed.category.prefix)
                    .font(.body)
                
                LogLevelBadge(level: parsed.level)
                
                Text(timestampText(parsed.timestamp))
                    .bodySmall()
                    .foregroundStyle(.secondary)
                
                Spacer(minLength: .spacing.s)
            }
            
            Text(parsed.message)
                .bodySmall()
                .foregroundStyle(.primary)
                .lineLimit(isExpanded ? nil : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let info = parsed.info, !info.isEmpty {
                Text(info)
                    .bodyMono()
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .logRowContainer(isHighlighted: isCopied)
    }
    
    // MARK: - Raw row
    
    private func rawRow(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: .spacing.xs) {
            Text(L.Settings.Logs.rawBadge)
                .labelSmall()
                .foregroundStyle(.secondary)
                .padding(.horizontal, .spacing.m)
                .padding(.vertical, .spacing.xs)
                .background(Color.gray.opacity(.opacity.subtle))
                .clipShape(Capsule())
            
            Text(text)
                .bodyMono()
                .foregroundStyle(.primary)
                .lineLimit(isExpanded ? nil : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .logRowContainer(isHighlighted: isCopied)
    }
    
    // MARK: - Helpers
    
    private func timestampText(_ date: Date?) -> String {
        guard let date else { return "—" }
        return Self.timestampFormatter.string(from: date)
    }
    
    private var accessibilityLabel: String {
        switch entry.kind {
        case .parsed(let parsed):
            let timestamp = timestampText(parsed.timestamp)
            let levelName = Log.Level.name(parsed.level)
            return "\(levelName), \(timestamp), \(parsed.category.rawValue), \(parsed.message)"
        case .raw(let text):
            return "Raw entry: \(text)"
        }
    }
}

// MARK: - Row container

private extension View {
    /// Shared visual container for parsed and raw log rows. Centralises the
    /// padding / background / clipping so both row kinds stay visually
    /// consistent. When `isHighlighted` is `true` the background tint deepens
    /// — used to flash the row on long-press copy.
    func logRowContainer(isHighlighted: Bool = false) -> some View {
        padding(.vertical, .spacing.m)
            .padding(.horizontal, .padding.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.gray
                    .opacity(isHighlighted ? .opacity.subtle : .opacity.faint)
            )
            .clipShape(RoundedRectangle(cornerRadius: .radius.s))
    }
}

// MARK: - Level Badge

/// Compact level chip: color swatch + uppercase letter token.
///
/// Color is paired with text (rather than color-only) to remain legible for
/// users with color-vision deficiencies. Colour and short-name lookups live
/// on `Log.Level` (see `Log.Level+UI.swift`).
struct LogLevelBadge: View {
    let level: Log.Level
    
    var body: some View {
        HStack(spacing: .spacing.xs) {
            Circle()
                .fill(level.stateColor)
                .frame(width: IconSize.xs / 2, height: IconSize.xs / 2)
            
            Text(level.shortName)
                .labelSmall()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, .spacing.m)
        .padding(.vertical, .spacing.xs)
        .background(level.stateColor.opacity(.opacity.faint))
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#if PREVIEW_DEBUG

#Preview("Parsed entries") {
    VStack(spacing: .spacing.m) {
        LogRowView(entry: LogEntry(
            id: UUID(),
            kind: .parsed(LogEntry.Parsed(
                timestamp: Date(),
                level: .error,
                category: .ui,
                message: "Tab switch failed: NSError 42",
                info: "session=ABC, retry=3"
            )),
            rawLine: "[ui] [error] Tab switch failed: NSError 42 | session=ABC, retry=3"
        ))
        
        LogRowView(entry: LogEntry(
            id: UUID(),
            kind: .parsed(LogEntry.Parsed(
                timestamp: Date(),
                level: .info,
                category: .application,
                message: "App started",
                info: nil
            )),
            rawLine: "[application] [info] App started"
        ))
        
        LogRowView(entry: LogEntry(
            id: UUID(),
            kind: .raw("This is a raw line that did not parse"),
            rawLine: "This is a raw line that did not parse"
        ))
    }
    .padding(.padding.m)
}

#endif
