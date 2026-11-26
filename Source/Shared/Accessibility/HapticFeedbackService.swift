//
//  HapticFeedbackService.swift
//
//  Created on 30.01.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if canImport(UIKit)
import CoreHaptics
import UIKit
import WardAxisTelemetry
#endif

/// Direction cues for haptic feedback.
enum HapticDirection: Sendable {
    case left
    case right
    case center
}

/// Protocol for haptic feedback during accessibility flows.
///
/// Haptic feedback provides non-visual cues for VoiceOver users,
/// especially useful for real-time guidance during face scanning.
@MainActor
protocol HapticFeedbackServiceProtocol: Sendable {
    /// Plays a success feedback pattern.
    func playSuccess()
    
    /// Plays an error feedback pattern.
    func playError()
    
    /// Plays a warning feedback pattern.
    func playWarning()
    
    /// Plays a progress feedback with variable intensity.
    ///
    /// - Parameter intensity: Progress intensity from 0.0 to 1.0.
    func playProgress(intensity: Float)
    
    /// Plays a directional cue for face scan guidance.
    ///
    /// - Parameter direction: The direction to indicate.
    func playDirectionCue(direction: HapticDirection)
    
    /// Plays a selection feedback for interactive elements.
    func playSelection()
}

// tvOS has no haptic hardware and no feedback generators; it takes the no-op branch.
#if os(iOS)
/// Implementation of haptic feedback service using UIKit feedback generators.
@MainActor
final class HapticFeedbackService: HapticFeedbackServiceProtocol {
    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool
    
    private let logger = Log(category: .application)
    
    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if supportsHaptics {
            prepareHapticEngine()
        }
    }
    
    private func prepareHapticEngine() {
        do {
            engine = try CHHapticEngine()
            engine?.playsHapticsOnly = true
            
            // Handle engine resets
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.restartEngine()
                }
            }
            
            // Handle engine stopped
            engine?.stoppedHandler = { reason in
                self.logger.debug("Haptic engine stopped: \(String(describing: reason))")
            }
            
            try engine?.start()
            logger.debug("Haptic engine started")
        } catch {
            logger.error("Failed to create haptic engine: \(error)")
            engine = nil
        }
    }
    
    private func restartEngine() {
        do {
            try engine?.start()
            logger.debug("Haptic engine restarted")
        } catch {
            logger.error("Failed to restart haptic engine: \(error)")
        }
    }
    
    // MARK: - HapticFeedbackServiceProtocol
    
    func playSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    func playError() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    func playWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    func playProgress(intensity: Float) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: CGFloat(min(max(intensity, 0), 1)))
    }
    
    func playDirectionCue(direction: HapticDirection) {
        guard supportsHaptics, let engine else {
            // Fallback to simple impact
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            return
        }
        
        do {
            let pattern = try createDirectionPattern(direction: direction)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.error("Failed to play direction cue: \(error)")
            // Fallback
            playSelection()
        }
    }
    
    func playSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    // MARK: - Custom Haptic Patterns
    
    private func createDirectionPattern(direction: HapticDirection) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        switch direction {
        case .left:
            // Two quick taps for left
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0.1
                )
            ]
        
        case .right:
            // Two quick taps with higher sharpness for right
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0.1
                )
            ]
        
        case .center:
            // Single centered tap
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                    ],
                    relativeTime: 0
                )
            ]
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
}
#else
/// Stub implementation of haptic feedback service for macOS (no haptics support).
@MainActor
final class HapticFeedbackService: HapticFeedbackServiceProtocol {
    init() {}
    
    func playSuccess() {}
    func playError() {}
    func playWarning() {}
    func playProgress(intensity _: Float) {}
    func playDirectionCue(direction _: HapticDirection) {}
    func playSelection() {}
}
#endif

// MARK: - Preview / Mock Implementation

/// Mock haptic feedback service for previews and testing.
@MainActor
final class MockHapticFeedbackService: HapticFeedbackServiceProtocol {
    var lastPlayedFeedback: String?
    
    func playSuccess() {
        lastPlayedFeedback = "success"
    }
    
    func playError() {
        lastPlayedFeedback = "error"
    }
    
    func playWarning() {
        lastPlayedFeedback = "warning"
    }
    
    func playProgress(intensity: Float) {
        lastPlayedFeedback = "progress(\(intensity))"
    }
    
    func playDirectionCue(direction: HapticDirection) {
        lastPlayedFeedback = "direction(\(direction))"
    }
    
    func playSelection() {
        lastPlayedFeedback = "selection"
    }
}
