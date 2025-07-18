//
//  HapticManager.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import UIKit
import CoreHaptics

class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // Core Haptics engine for more complex patterns
    private var hapticEngine: CHHapticEngine?
    
    init() {
        setupHapticEngine()
        prepareHapticGenerators()
    }
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("Haptic engine not supported on this device")
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    private func prepareHapticGenerators() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Voice Interaction Haptics
    
    func voiceStarted() {
        mediumImpact.impactOccurred()
    }
    
    func voiceStopped() {
        lightImpact.impactOccurred()
    }
    
    func voiceListening() {
        // Gentle pulse pattern for listening state
        playCustomPattern(intensity: 0.5, sharpness: 0.3, duration: 0.1)
    }
    
    func voiceProcessing() {
        // Subtle processing pattern
        playProcessingPattern()
    }
    
    // MARK: - Command Result Haptics
    
    func commandSuccess() {
        notificationFeedback.notificationOccurred(.success)
    }
    
    func commandError() {
        notificationFeedback.notificationOccurred(.error)
    }
    
    func commandWarning() {
        notificationFeedback.notificationOccurred(.warning)
    }
    
    // MARK: - Action-Specific Haptics
    
    func calendarEventCreated() {
        // Double tap for calendar events
        playDoubleImpactPattern()
    }
    
    func emailSent() {
        // Medium impact for email actions
        mediumImpact.impactOccurred()
    }
    
    func taskCompleted() {
        // Light impact for task completion
        lightImpact.impactOccurred()
    }
    
    func taskCreated() {
        // Light impact for task creation
        lightImpact.impactOccurred()
    }
    
    func reminderSet() {
        // Gentle reminder pattern
        playReminderPattern()
    }
    
    // MARK: - UI Interaction Haptics
    
    func buttonPressed() {
        lightImpact.impactOccurred()
    }
    
    func buttonLongPress() {
        mediumImpact.impactOccurred()
    }
    
    func menuOpened() {
        lightImpact.impactOccurred()
    }
    
    func pageChanged() {
        lightImpact.impactOccurred()
    }
    
    func cardTapped() {
        lightImpact.impactOccurred()
    }
    
    func quickActionTapped() {
        lightImpact.impactOccurred()
    }
    
    // MARK: - Connection Status Haptics
    
    func watchConnected() {
        // Two quick light taps
        lightImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.lightImpact.impactOccurred()
        }
    }
    
    func watchDisconnected() {
        // Single medium impact
        mediumImpact.impactOccurred()
    }
    
    func networkError() {
        // Heavy impact for network errors
        heavyImpact.impactOccurred()
    }
    
    // MARK: - Authentication Haptics
    
    func authenticationSuccess() {
        notificationFeedback.notificationOccurred(.success)
    }
    
    func authenticationFailed() {
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Custom Haptic Patterns
    
    private func playCustomPattern(intensity: Float, sharpness: Float, duration: TimeInterval) {
        guard let hapticEngine = hapticEngine else { return }
        
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0,
                duration: duration
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play custom haptic pattern: \(error)")
        }
    }
    
    private func playProcessingPattern() {
        guard let hapticEngine = hapticEngine else { return }
        
        do {
            var events: [CHHapticEvent] = []
            
            // Create a gentle pulsing pattern
            for i in 0..<3 {
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: TimeInterval(i) * 0.2
                )
                events.append(event)
            }
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play processing pattern: \(error)")
        }
    }
    
    private func playDoubleImpactPattern() {
        lightImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.lightImpact.impactOccurred()
        }
    }
    
    private func playReminderPattern() {
        guard let hapticEngine = hapticEngine else { return }
        
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: 0,
                duration: 0.2
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play reminder pattern: \(error)")
        }
    }
    
    // MARK: - Onboarding Haptics
    
    func onboardingStepCompleted() {
        lightImpact.impactOccurred()
    }
    
    func onboardingCompleted() {
        notificationFeedback.notificationOccurred(.success)
    }
    
    // MARK: - Dashboard Haptics
    
    func dashboardRefreshed() {
        lightImpact.impactOccurred()
    }
    
    func cardDataLoaded() {
        // Very subtle feedback for data loading
        playCustomPattern(intensity: 0.2, sharpness: 0.1, duration: 0.05)
    }
    
    // MARK: - Settings Haptics
    
    func settingToggled() {
        lightImpact.impactOccurred()
    }
    
    func settingsSaved() {
        lightImpact.impactOccurred()
    }
    
    // MARK: - Utility Methods
    
    func playHapticFeedback(for feedbackType: HapticFeedbackType) {
        switch feedbackType {
        case .light:
            lightImpact.impactOccurred()
        case .medium:
            mediumImpact.impactOccurred()
        case .heavy:
            heavyImpact.impactOccurred()
        case .success:
            notificationFeedback.notificationOccurred(.success)
        case .error:
            notificationFeedback.notificationOccurred(.error)
        case .warning:
            notificationFeedback.notificationOccurred(.warning)
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        hapticEngine?.stop()
    }
}

// MARK: - Haptic Feedback Types

enum HapticFeedbackType {
    case light
    case medium
    case heavy
    case success
    case error
    case warning
}

// MARK: - Context-Aware Haptic Patterns

extension HapticManager {
    
    /// Plays context-aware haptic feedback based on voice command type
    func playContextualFeedback(for commandType: VoiceCommandType) {
        switch commandType {
        case .calendar:
            calendarEventCreated()
        case .email:
            emailSent()
        case .task:
            taskCreated()
        case .weather:
            buttonPressed()
        case .general:
            buttonPressed()
        }
    }
    
    /// Plays adaptive haptic feedback based on app state
    func playAdaptiveFeedback(for appState: VoiceAssistantStatus) {
        switch appState {
        case .idle:
            break // No haptic for idle state
        case .recording:
            voiceStarted()
        case .transcribing:
            voiceListening()
        case .processing:
            voiceProcessing()
        case .playing:
            commandSuccess()
        case .error:
            commandError()
        }
    }
    
    /// Plays intensity-based haptic feedback
    func playIntensityFeedback(intensity: Float) {
        let clampedIntensity = max(0.0, min(1.0, intensity))
        
        if clampedIntensity < 0.3 {
            lightImpact.impactOccurred()
        } else if clampedIntensity < 0.7 {
            mediumImpact.impactOccurred()
        } else {
            heavyImpact.impactOccurred()
        }
    }
}