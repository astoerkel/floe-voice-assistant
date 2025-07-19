//
//  Constants.swift
//  VoiceAssistant
//
//  Created by Amit Störkel on 16.07.25.
//

import Foundation

struct Constants {
    struct API {
        static let baseURL = "https://voice-assistant-backend-899362685715.us-central1.run.app"
        static let webhookURL = "https://voice-assistant-backend-899362685715.us-central1.run.app/api/voice/process-audio"
        static let devWebhookURL = "https://voice-assistant-backend-899362685715.us-central1.run.app/api/voice/dev/process-audio"
        static let apiBaseURL = "https://voice-assistant-backend-899362685715.us-central1.run.app/api"
        static let websocketURL = "wss://voice-assistant-backend-899362685715.us-central1.run.app"
        static let defaultVoiceId = "default"
        static let requestTimeout: TimeInterval = 30.0
        static let apiKey = "voice-assistant-api-key-secure-2024"
    }
    
    struct Audio {
        static let sampleRate: Double = 16000.0
        static let bitDepth: Int = 16
        static let channels: Int = 1
        static let audioFormat = "m4a"
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
