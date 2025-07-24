//
//  SharedTypes.swift  
//  VoiceAssistant
//
//  Created by Claude Code on 2025-07-24.
//  Shared types used across the application to avoid conflicts
//

import Foundation

// MARK: - Time and Context Types

public enum TimeOfDay: String, Codable, CaseIterable {
    case morning = "morning"
    case afternoon = "afternoon"  
    case evening = "evening"
    case night = "night"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

public struct ConversationContext: Codable {
    public var conversationTurn: Int
    public var lastResponseType: String?
    public let sessionDuration: TimeInterval
    public var recentMessages: [ConversationMessage]
    public var lastResponseConfidence: Double
    public var userPreferences: UserPreferences?
    public var timeContext: TimeContext
    
    public init(conversationTurn: Int = 1, lastResponseType: String? = nil, sessionDuration: TimeInterval = 0, recentMessages: [ConversationMessage] = [], lastResponseConfidence: Double = 0.0, userPreferences: UserPreferences? = nil, timeContext: TimeContext = TimeContext.current()) {
        self.conversationTurn = conversationTurn
        self.lastResponseType = lastResponseType
        self.sessionDuration = sessionDuration
        self.recentMessages = recentMessages
        self.lastResponseConfidence = lastResponseConfidence
        self.userPreferences = userPreferences
        self.timeContext = timeContext
    }
    
    public var contextSummary: String {
        let messageCount = recentMessages.count
        let lastType = lastResponseType ?? "none"
        return "\(messageCount)_\(lastType)_\(conversationTurn)"
    }
}

public struct UserPreferences: Codable {
    public var formalityLevel: Double
    public var responseLength: ResponseLength
    public var personalityTraits: PersonalityTraits
    public var measurementSystem: MeasurementSystem
    public var timeFormat: TimeFormat
    public var preferredLocaleIdentifier: String?
    public var timeBasedPreferences: TimeBasedPreferences
    
    public init(formalityLevel: Double = 0.5, responseLength: ResponseLength = .medium, personalityTraits: PersonalityTraits = PersonalityTraits(), measurementSystem: MeasurementSystem = .metric, timeFormat: TimeFormat = .twentyFourHour, preferredLocaleIdentifier: String? = nil, timeBasedPreferences: TimeBasedPreferences = TimeBasedPreferences()) {
        self.formalityLevel = formalityLevel
        self.responseLength = responseLength
        self.personalityTraits = personalityTraits
        self.measurementSystem = measurementSystem
        self.timeFormat = timeFormat
        self.preferredLocaleIdentifier = preferredLocaleIdentifier
        self.timeBasedPreferences = timeBasedPreferences
    }
    
    public static let `default` = UserPreferences()
}

public enum ResponseLength: String, Codable, CaseIterable {
    case short = "short"
    case medium = "medium"
    case long = "long"
    case brief = "brief"
    case detailed = "detailed"
}

public struct PersonalityTraits: Codable {
    public let enthusiasm: Double
    public let helpfulness: Double
    public let friendliness: Double
    public let professionalism: Double
    
    public init(enthusiasm: Double = 0.7, helpfulness: Double = 0.9, friendliness: Double = 0.8, professionalism: Double = 0.6) {
        self.enthusiasm = enthusiasm
        self.helpfulness = helpfulness
        self.friendliness = friendliness
        self.professionalism = professionalism
    }
}

public struct TimeContext: Codable {
    public let timeOfDay: TimeOfDay
    public let isWeekend: Bool
    public let hour: Int
    public let dayOfWeek: Int
    
    public init(timeOfDay: TimeOfDay, isWeekend: Bool, hour: Int, dayOfWeek: Int) {
        self.timeOfDay = timeOfDay
        self.isWeekend = isWeekend
        self.hour = hour
        self.dayOfWeek = dayOfWeek
    }
    
    public static func current() -> TimeContext {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let dayOfWeek = calendar.component(.weekday, from: now)
        let isWeekend = calendar.isDateInWeekend(now)
        
        let timeOfDay: TimeOfDay
        switch hour {
        case 5..<12: timeOfDay = .morning
        case 12..<17: timeOfDay = .afternoon
        case 17..<21: timeOfDay = .evening
        default: timeOfDay = .night
        }
        
        return TimeContext(timeOfDay: timeOfDay, isWeekend: isWeekend, hour: hour, dayOfWeek: dayOfWeek)
    }
}

// MARK: - Response Types

public enum ResponseType: String, CaseIterable {
    case greeting = "greeting"
    case confirmation = "confirmation"
    case clarification = "clarification"
    case error = "error"
    case information = "information"
    case suggestion = "suggestion"
    case calendar = "calendar"
    case email = "email"
    case task = "task"
    case weather = "weather"
    case timeDate = "timeDate"
    case general = "general"
}

// MARK: - Device Types

public enum DeviceType: String, CaseIterable {
    case iPhone = "iphone"
    case appleWatch = "apple_watch"
    case other = "other"
}

// MARK: - Additional Preference Types

public enum MeasurementSystem: String, Codable, CaseIterable {
    case metric = "metric"
    case imperial = "imperial"
}

public enum TimeFormat: String, Codable, CaseIterable {
    case twelveHour = "12h"
    case twentyFourHour = "24h"
}

public struct TimeBasedPreferences: Codable {
    public var morningGreeting: String
    public var afternoonGreeting: String
    public var eveningGreeting: String
    public var nightGreeting: String
    public var morningFormality: Double
    public var eveningFormality: Double
    
    public init(morningGreeting: String = "Good morning", afternoonGreeting: String = "Good afternoon", eveningGreeting: String = "Good evening", nightGreeting: String = "Good evening", morningFormality: Double = 0.4, eveningFormality: Double = 0.6) {
        self.morningGreeting = morningGreeting
        self.afternoonGreeting = afternoonGreeting
        self.eveningGreeting = eveningGreeting
        self.nightGreeting = nightGreeting
        self.morningFormality = morningFormality
        self.eveningFormality = eveningFormality
    }
}