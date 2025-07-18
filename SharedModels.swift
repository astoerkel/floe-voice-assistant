//
//  SharedModels.swift
//  VoiceAssistant
//
//  Created by Amit Störkel on 16.07.25.
//
import Foundation

struct VoiceResponse: Codable {
    let text: String
    let success: Bool
    let audioBase64: String?
    
    enum CodingKeys: String, CodingKey {
        case text, success
        case audioBase64 = "audioBase64"
    }
}

struct EnhancedVoiceResponse: Codable {
    let text: String
    let success: Bool
    let audioBase64: String?
    let intent: String?
    let confidence: Double?
    let agentUsed: String?
    let executionTime: Double?
    let actions: [String]?
    let suggestions: [String]?
    
    // Convert to basic VoiceResponse for compatibility
    var voiceResponse: VoiceResponse {
        return VoiceResponse(
            text: text,
            success: success,
            audioBase64: audioBase64
        )
    }
}

struct VoiceRequest: Codable {
    let text: String
    let sessionId: String
    let metadata: [String: String]?
    let generateAudio: Bool
    
    init(text: String, sessionId: String, metadata: [String: String]? = nil, generateAudio: Bool = true) {
        self.text = text
        self.sessionId = sessionId
        self.metadata = metadata
        self.generateAudio = generateAudio
    }
}

enum VoiceAssistantStatus: String, Codable, CaseIterable {
    case idle = "idle"
    case recording = "recording"
    case transcribing = "transcribing"
    case processing = "processing"
    case playing = "playing"
    case error = "error"
}

enum VoiceAssistantError: LocalizedError {
    case recordingFailed
    case transcriptionFailed
    case networkError
    case audioPlaybackFailed
    case watchConnectivityFailed
    case invalidResponse
    case authenticationRequired
    case authenticationFailed
    case webSocketConnectionFailed
    case webSocketAuthenticationFailed
    case tokenExpired
    case tokenRefreshFailed
    case backendUnavailable
    case audioEncodingFailed
    case audioDecodingFailed
    case voiceProcessingFailed
    case sessionExpired
    case rateLimitExceeded
    case invalidAudioFormat
    case microphonePermissionDenied
    case serverError(Int)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .recordingFailed: return "Failed to record audio"
        case .transcriptionFailed: return "Failed to transcribe speech"
        case .networkError: return "Network connection failed"
        case .audioPlaybackFailed: return "Failed to play audio response"
        case .watchConnectivityFailed: return "Watch connection failed"
        case .invalidResponse: return "Invalid response from server"
        case .authenticationRequired: return "Authentication required"
        case .authenticationFailed: return "Authentication failed"
        case .webSocketConnectionFailed: return "WebSocket connection failed"
        case .webSocketAuthenticationFailed: return "WebSocket authentication failed"
        case .tokenExpired: return "Access token expired"
        case .tokenRefreshFailed: return "Failed to refresh access token"
        case .backendUnavailable: return "Backend service is unavailable"
        case .audioEncodingFailed: return "Failed to encode audio"
        case .audioDecodingFailed: return "Failed to decode audio"
        case .voiceProcessingFailed: return "Voice processing failed"
        case .sessionExpired: return "Session expired"
        case .rateLimitExceeded: return "Rate limit exceeded"
        case .invalidAudioFormat: return "Invalid audio format"
        case .microphonePermissionDenied: return "Microphone permission denied"
        case .serverError(let code): return "Server error: \(code)"
        case .unknownError(let message): return "Unknown error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .authenticationRequired, .authenticationFailed:
            return "Please sign in with Apple ID"
        case .tokenExpired, .tokenRefreshFailed:
            return "Please sign in again"
        case .networkError, .backendUnavailable:
            return "Check your internet connection and try again"
        case .webSocketConnectionFailed, .webSocketAuthenticationFailed:
            return "Connection lost. Trying to reconnect..."
        case .microphonePermissionDenied:
            return "Please enable microphone permission in Settings"
        case .rateLimitExceeded:
            return "Please wait a moment before trying again"
        case .serverError(let code) where code >= 500:
            return "Server is experiencing issues. Please try again later"
        case .invalidAudioFormat:
            return "Please try recording again"
        default:
            return "Please try again"
        }
    }
}

struct ConversationMessage: Identifiable, Codable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    let audioBase64: String? // Store audio data for replay
    let isTranscribed: Bool // Indicates if text was transcribed from audio
    
    // Enhanced fields from new backend
    let intent: String?
    let confidence: Double?
    let agentUsed: String?
    let executionTime: Double?
    let actions: [String]?
    let suggestions: [String]?
    
    init(id: UUID = UUID(), text: String, isUser: Bool, timestamp: Date = Date(), audioBase64: String? = nil, isTranscribed: Bool = false, intent: String? = nil, confidence: Double? = nil, agentUsed: String? = nil, executionTime: Double? = nil, actions: [String]? = nil, suggestions: [String]? = nil) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.audioBase64 = audioBase64
        self.isTranscribed = isTranscribed
        self.intent = intent
        self.confidence = confidence
        self.agentUsed = agentUsed
        self.executionTime = executionTime
        self.actions = actions
        self.suggestions = suggestions
    }
}

// MARK: - Backend API Models

struct AuthResponse: Codable {
    let success: Bool
    let user: User?
    let accessToken: String
    let refreshToken: String
}

struct User: Codable {
    let id: String
    let email: String?
    let name: String?
    let profilePicture: String?
}

struct BackendVoiceResponse: Codable {
    let success: Bool
    let transcription: Transcription?
    let response: String?
    let audioResponse: AudioResponse?
    let intent: String?
    let confidence: Double?
    let agentUsed: String?
    let executionTime: Double?
    let actions: [String]?
    let suggestions: [String]?
    let sessionId: String?
}

struct Transcription: Codable {
    let text: String
    let confidence: Double?
    let language: String?
}

struct AudioResponse: Codable {
    let audioBase64: String
    let audioSize: Int?
    let voiceConfig: VoiceConfig?
}

struct VoiceConfig: Codable {
    let languageCode: String?
    let name: String?
    let ssmlGender: String?
}

// MARK: - Calendar Models

struct CalendarEvent: Identifiable, Codable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let location: String?
    let isAllDay: Bool
    let attendees: [String]
    let description: String?
    
    init(id: String, title: String, startTime: Date, endTime: Date, location: String? = nil, isAllDay: Bool = false, attendees: [String] = [], description: String? = nil) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.isAllDay = isAllDay
        self.attendees = attendees
        self.description = description
    }
}

// MARK: - QuickAction for iOS and Watch
struct QuickAction: Identifiable, Codable {
    let id: String
    let title: String
    let icon: String
    let voiceCommand: String
    let color: String // Store as string for Codable compatibility
    
    init(id: String, title: String, icon: String, voiceCommand: String, color: String) {
        self.id = id
        self.title = title
        self.icon = icon
        self.voiceCommand = voiceCommand
        self.color = color
    }
}
