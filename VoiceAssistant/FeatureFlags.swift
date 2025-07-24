//
//  FeatureFlags.swift
//  VoiceAssistant
//
//  Created on 2025-07-24.
//

import Foundation

/// Central configuration for feature flags in the VoiceAssistant app
/// All flags default to false for safety and gradual rollout
struct FeatureFlags {
    
    // MARK: - Core Features
    
    /// Enables the new conversation UI with enhanced animations and layout
    static let enableNewConversationUI = false
    
    /// Enables advanced speech recognition with noise cancellation
    static let enableAdvancedSpeechRecognition = false
    
    /// Enables real-time transcription display while speaking
    static let enableRealTimeTranscription = false
    
    // MARK: - Watch Features
    
    /// Enables haptic feedback on the Apple Watch for various interactions
    static let enableWatchHapticFeedback = false
    
    /// Enables watch complications for quick access to voice assistant
    static let enableWatchComplications = false
    
    /// Enables offline mode for basic watch functionality
    static let enableWatchOfflineMode = false
    
    // MARK: - AI/ML Features
    
    /// Enables on-device Core ML processing for faster responses
    static let enableOnDeviceML = false
    
    /// Enables multi-language support for speech recognition
    static let enableMultiLanguageSupport = false
    
    /// Enables context-aware responses based on conversation history
    static let enableContextAwareResponses = false
    
    // MARK: - Backend Features
    
    /// Enables WebSocket connections for real-time communication
    static let enableWebSocketConnection = false
    
    /// Enables caching of AI responses for offline access
    static let enableResponseCaching = false
    
    /// Enables analytics tracking for usage patterns
    static let enableAnalytics = false
    
    // MARK: - Experimental Features
    
    /// Enables voice cloning for personalized responses
    static let enableVoiceCloning = false
    
    /// Enables augmented reality integration for visual responses
    static let enableARIntegration = false
    
    /// Enables beta features that are still in testing
    static let enableBetaFeatures = false
    
    // MARK: - Performance Features
    
    /// Enables aggressive performance optimizations
    static let enablePerformanceMode = false
    
    /// Enables battery optimization mode with reduced functionality
    static let enableBatteryOptimization = false
    
    /// Enables debug logging for development
    static let enableDebugLogging = false
    
    // MARK: - Debug Functions
    
    /// Prints the current state of all feature flags to the console
    static func printCurrentFlags() {
        print("=== VoiceAssistant Feature Flags ===")
        print("Core Features:")
        print("  - New Conversation UI: \(enableNewConversationUI)")
        print("  - Advanced Speech Recognition: \(enableAdvancedSpeechRecognition)")
        print("  - Real-time Transcription: \(enableRealTimeTranscription)")
        
        print("\nWatch Features:")
        print("  - Haptic Feedback: \(enableWatchHapticFeedback)")
        print("  - Complications: \(enableWatchComplications)")
        print("  - Offline Mode: \(enableWatchOfflineMode)")
        
        print("\nAI/ML Features:")
        print("  - On-device ML: \(enableOnDeviceML)")
        print("  - Multi-language Support: \(enableMultiLanguageSupport)")
        print("  - Context-aware Responses: \(enableContextAwareResponses)")
        
        print("\nBackend Features:")
        print("  - WebSocket Connection: \(enableWebSocketConnection)")
        print("  - Response Caching: \(enableResponseCaching)")
        print("  - Analytics: \(enableAnalytics)")
        
        print("\nExperimental Features:")
        print("  - Voice Cloning: \(enableVoiceCloning)")
        print("  - AR Integration: \(enableARIntegration)")
        print("  - Beta Features: \(enableBetaFeatures)")
        
        print("\nPerformance Features:")
        print("  - Performance Mode: \(enablePerformanceMode)")
        print("  - Battery Optimization: \(enableBatteryOptimization)")
        print("  - Debug Logging: \(enableDebugLogging)")
        print("===================================")
    }
    
    /// Returns a dictionary representation of all feature flags
    static func allFlags() -> [String: Bool] {
        return [
            "enableNewConversationUI": enableNewConversationUI,
            "enableAdvancedSpeechRecognition": enableAdvancedSpeechRecognition,
            "enableRealTimeTranscription": enableRealTimeTranscription,
            "enableWatchHapticFeedback": enableWatchHapticFeedback,
            "enableWatchComplications": enableWatchComplications,
            "enableWatchOfflineMode": enableWatchOfflineMode,
            "enableOnDeviceML": enableOnDeviceML,
            "enableMultiLanguageSupport": enableMultiLanguageSupport,
            "enableContextAwareResponses": enableContextAwareResponses,
            "enableWebSocketConnection": enableWebSocketConnection,
            "enableResponseCaching": enableResponseCaching,
            "enableAnalytics": enableAnalytics,
            "enableVoiceCloning": enableVoiceCloning,
            "enableARIntegration": enableARIntegration,
            "enableBetaFeatures": enableBetaFeatures,
            "enablePerformanceMode": enablePerformanceMode,
            "enableBatteryOptimization": enableBatteryOptimization,
            "enableDebugLogging": enableDebugLogging
        ]
    }
    
    /// Checks if any experimental features are enabled
    static var hasExperimentalFeaturesEnabled: Bool {
        return enableVoiceCloning || enableARIntegration || enableBetaFeatures
    }
    
    /// Checks if any performance features are enabled
    static var hasPerformanceFeaturesEnabled: Bool {
        return enablePerformanceMode || enableBatteryOptimization
    }
}

// MARK: - Usage Examples

/*
 Usage in your code:
 
 // Check if a feature is enabled
 if FeatureFlags.enableNewConversationUI {
     // Use new UI implementation
 } else {
     // Use existing UI implementation
 }
 
 // Debug print all flags
 #if DEBUG
 FeatureFlags.printCurrentFlags()
 #endif
 
 // Check for experimental features
 if FeatureFlags.hasExperimentalFeaturesEnabled {
     // Show experimental features warning
 }
 */