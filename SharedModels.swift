//
//  SharedModels.swift
//  VoiceAssistant
//
//  Created by Amit Störkel on 16.07.25.
//
import Foundation

// Backend Response Models - matching exactly what the backend returns
public struct BackendVoiceResponse: Codable {
    public let success: Bool
    public let processingTime: Int?
    public let transcriptionMethod: String?
    public let text: String?
    public let intent: String?
    public let confidence: Double?
    public let agentUsed: String?
    public let executionTime: Double?
    public let response: ResponseData?
    public let audioResponse: AudioResponseData?
    public let actions: [String]?
    public let suggestions: [String]?
    public let sessionId: String?
    public let coordinatorSuccess: Bool?
    
    enum CodingKeys: String, CodingKey {
        case success, processingTime, transcriptionMethod, text, intent, confidence
        case agentUsed, executionTime, response, audioResponse, actions, suggestions
        case sessionId, coordinatorSuccess
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle success field that can be either Bool or String
        if let successBool = try? container.decode(Bool.self, forKey: .success) {
            print("📊 SUCCESS: Decoded as Bool: \(successBool)")
            self.success = successBool
        } else if let successString = try? container.decode(String.self, forKey: .success) {
            print("📊 SUCCESS: Decoded as String: '\(successString)'")
            self.success = successString.lowercased() == "true"
            print("📊 SUCCESS: Converted to Bool: \(self.success)")
        } else {
            print("📊 SUCCESS: Failed to decode, defaulting to false")
            self.success = false
        }
        
        // Handle coordinatorSuccess field that can be either Bool or String
        if let coordinatorSuccessBool = try? container.decodeIfPresent(Bool.self, forKey: .coordinatorSuccess) {
            self.coordinatorSuccess = coordinatorSuccessBool
        } else if let coordinatorSuccessString = try? container.decodeIfPresent(String.self, forKey: .coordinatorSuccess) {
            self.coordinatorSuccess = coordinatorSuccessString.lowercased() == "true"
        } else {
            self.coordinatorSuccess = nil
        }
        
        // Decode other fields normally
        self.processingTime = try container.decodeIfPresent(Int.self, forKey: .processingTime)
        self.transcriptionMethod = try container.decodeIfPresent(String.self, forKey: .transcriptionMethod)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.intent = try container.decodeIfPresent(String.self, forKey: .intent)
        self.confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        self.agentUsed = try container.decodeIfPresent(String.self, forKey: .agentUsed)
        self.executionTime = try container.decodeIfPresent(Double.self, forKey: .executionTime)
        self.response = try container.decodeIfPresent(ResponseData.self, forKey: .response)
        self.audioResponse = try container.decodeIfPresent(AudioResponseData.self, forKey: .audioResponse)
        self.actions = try container.decodeIfPresent([String].self, forKey: .actions)
        self.suggestions = try container.decodeIfPresent([String].self, forKey: .suggestions)
        self.sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
    }
}

public struct ResponseData: Codable {
    public let text: String
    public let audioUrl: String?
    public let hapticPattern: String?
}

public struct AudioResponseData: Codable {
    public let audioBase64: String?
    public let audioSize: Int?
    public let voiceConfig: VoiceConfig?
}

public struct VoiceConfig: Codable {
    public let name: String?
    public let languageCode: String?
}

// Legacy models for compatibility
public struct VoiceResponse: Codable {
    public let text: String
    public let success: Bool
    public let audioBase64: String?
    
    // Legacy initializer for Watch app compatibility
    public init(text: String, success: Bool, audioBase64: String?) {
        self.text = text
        self.success = success
        self.audioBase64 = audioBase64
    }
    
    // Convert from BackendVoiceResponse
    public init(from backendResponse: BackendVoiceResponse) {
        self.success = backendResponse.success
        self.text = backendResponse.response?.text ?? backendResponse.text ?? "No response"
        self.audioBase64 = backendResponse.audioResponse?.audioBase64
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
    
    // Convert from BackendVoiceResponse
    init(from backendResponse: BackendVoiceResponse) {
        self.success = backendResponse.success
        self.text = backendResponse.response?.text ?? backendResponse.text ?? "No response"
        self.audioBase64 = backendResponse.audioResponse?.audioBase64
        self.intent = backendResponse.intent
        self.confidence = backendResponse.confidence
        self.agentUsed = backendResponse.agentUsed
        self.executionTime = backendResponse.executionTime
        self.actions = backendResponse.actions
        self.suggestions = backendResponse.suggestions
    }
    
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
    let context: VoiceContext
    let platform: String
    
    init(text: String, sessionId: String, metadata: [String: String]? = nil, generateAudio: Bool = true, platform: String = "ios") {
        self.text = text
        self.platform = platform
        self.context = VoiceContext(sessionId: sessionId, metadata: metadata)
    }
}

struct EnhancedVoiceRequest: Codable {
    let text: String
    let context: VoiceContext
    let platform: String
    let integrations: OAuthIntegrationsStatus
    
    init(text: String, context: VoiceContext, platform: String, integrations: [String: Any]) {
        self.text = text
        self.context = context
        self.platform = platform
        self.integrations = OAuthIntegrationsStatus(from: integrations)
    }
}

struct OAuthIntegrationsStatus: Codable {
    let google: OAuthServiceStatus
    let airtable: OAuthServiceStatus
    
    init(from integrations: [String: Any]) {
        if let googleDict = integrations["google"] as? [String: Any] {
            self.google = OAuthServiceStatus(from: googleDict)
        } else {
            self.google = OAuthServiceStatus.disconnected()
        }
        
        if let airtableDict = integrations["airtable"] as? [String: Any] {
            self.airtable = OAuthServiceStatus(from: airtableDict)
        } else {
            self.airtable = OAuthServiceStatus.disconnected()
        }
    }
}

struct OAuthServiceStatus: Codable {
    let connected: Bool
    let scopes: [String]
    let lastUpdated: Double
    
    init(connected: Bool, scopes: [String], lastUpdated: Double) {
        self.connected = connected
        self.scopes = scopes
        self.lastUpdated = lastUpdated
    }
    
    init(from dict: [String: Any]) {
        self.connected = dict["connected"] as? Bool ?? false
        self.scopes = dict["scopes"] as? [String] ?? []
        self.lastUpdated = dict["lastUpdated"] as? Double ?? 0.0
    }
    
    static func disconnected() -> OAuthServiceStatus {
        return OAuthServiceStatus(connected: false, scopes: [], lastUpdated: 0.0)
    }
}

struct VoiceContext: Codable {
    let sessionId: String
    let languageCode: String
    let metadata: [String: String]?
    
    init(sessionId: String, metadata: [String: String]? = nil) {
        self.sessionId = sessionId
        self.languageCode = "en-US"
        self.metadata = metadata
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
    case authenticationExpired
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
        case .authenticationExpired: return "Authentication expired"
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
        case .authenticationRequired, .authenticationFailed, .authenticationExpired:
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

public struct ConversationMessage: Identifiable, Codable {
    public let id: UUID
    public let text: String
    public let isUser: Bool
    public let timestamp: Date
    public let audioBase64: String? // Store audio data for replay
    public let isTranscribed: Bool // Indicates if text was transcribed from audio
    
    // Enhanced fields from new backend
    public let intent: String?
    public let confidence: Double?
    public let agentUsed: String?
    public let executionTime: Double?
    public let actions: [String]?
    public let suggestions: [String]?
    
    public init(id: UUID = UUID(), text: String, isUser: Bool, timestamp: Date = Date(), audioBase64: String? = nil, isTranscribed: Bool = false, intent: String? = nil, confidence: Double? = nil, agentUsed: String? = nil, executionTime: Double? = nil, actions: [String]? = nil, suggestions: [String]? = nil) {
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
    let preferredName: String?
}

struct BasicUserPreferences: Codable {
    let preferredName: String?
    
    init(preferredName: String? = nil) {
        self.preferredName = preferredName
    }
}

struct UserPreferencesResponse: Codable {
    let success: Bool
    let preferences: BasicUserPreferences?
    let message: String?
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
