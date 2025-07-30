//
//  Constants.swift
//  VoiceAssistant
//
//  Created by Amit Störkel on 16.07.25.
//

import Foundation

struct Constants {
    struct API {
        static let baseURL = "https://floe.cognetica.de"
        // Simple backend endpoints
        static let chatProcessURL = "https://floe.cognetica.de/api/voice/process-text"
        static let audioProcessURL = "https://floe.cognetica.de/api/voice/process-audio"
        static let appleSignInURL = "https://floe.cognetica.de/api/auth/apple-signin"
        static let registerURL = "https://floe.cognetica.de/api/auth/register"
        static let loginURL = "https://floe.cognetica.de/api/auth/login"
        static let googleSignInURL = "https://floe.cognetica.de/api/auth/google-signin"
        static let profileURL = "https://floe.cognetica.de/api/auth/profile"
        static let verifyTokenURL = "https://floe.cognetica.de/api/auth/verify"
        static let healthURL = "https://floe.cognetica.de/health"
        // Legacy endpoints (kept for backward compatibility)
        static let webhookURL = "https://floe.cognetica.de/api/voice/process-audio"
        static let textProcessURL = "https://floe.cognetica.de/api/voice/process-text"
        static let devWebhookURL = "https://floe.cognetica.de/api/voice/dev/process-audio"
        static let apiBaseURL = "https://floe.cognetica.de/api"
        static let websocketURL = "wss://floe.cognetica.de/socket.io/"
        static let defaultVoiceId = "default"
        static let requestTimeout: TimeInterval = 90.0
        // SECURITY FIX: API key should be loaded from secure keychain or environment
        static let apiKey: String = {
            // Try to load from build configuration first
            if let key = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String, !key.isEmpty {
                return key
            }
            // TEMPORARY FIX: Use a valid API key for development
            // TODO: Replace with proper API key management
            #if DEBUG
            return "voice-assistant-api-key-2024"  // Must match production API_KEY_ENV
            #else
            return "voice-assistant-api-key-2024"  // Must match production API_KEY_ENV
            #endif
        }()
    }
    
    struct Audio {
        static let sampleRate: Double = 16000.0
        static let bitDepth: Int = 16
        static let channels: Int = 1
        static let audioFormat = "wav"
        static let maxRecordingDuration: TimeInterval = 60.0
    }
    
    struct StorageKeys {
        static let sessionId = "voice_assistant_session_id"
        static let webhookURL = "voice_assistant_webhook_url" // Legacy - to be removed
        static let selectedVoiceId = "voice_assistant_voice_id"
        static let isFirstLaunch = "voice_assistant_first_launch"
        static let accessToken = "voice_assistant_access_token"
        static let refreshToken = "voice_assistant_refresh_token"
    }
    
    struct AppGroup {
        static let identifier = "group.com.amitstoerkel.VoiceAssistant"
    }
}

extension Constants {
    static func generateSessionId() -> String {
        return UUID().uuidString.lowercased()
    }
    
    static func getCurrentSessionId() -> String {
        let defaults = UserDefaults.standard
        if let existingId = defaults.string(forKey: StorageKeys.sessionId) {
            return existingId
        }
        
        let newId = generateSessionId()
        defaults.set(newId, forKey: StorageKeys.sessionId)
        return newId
    }
}
