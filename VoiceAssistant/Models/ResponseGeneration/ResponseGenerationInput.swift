import Foundation
import CoreML

/// Input structure for Core ML response generation model
class ResponseGenerationInput: NSObject, MLFeatureProvider {
    
    // MARK: - Input Properties
    let query: String
    let context: ConversationContext
    let responseType: ResponseType
    let userPreferences: UserPreferences
    let conversationHistory: [String]
    let timeContext: TimeContext
    
    // MARK: - Additional Context
    let deviceType: DeviceType
    let appVersion: String
    let sessionId: String
    
    // MARK: - Initialization
    init(
        query: String,
        context: ConversationContext,
        responseType: ResponseType,
        userPreferences: UserPreferences,
        conversationHistory: [String] = [],
        timeContext: TimeContext = TimeContext.current()
    ) {
        self.query = query
        self.context = context
        self.responseType = responseType
        self.userPreferences = userPreferences
        self.conversationHistory = conversationHistory
        self.timeContext = timeContext
        
        // Auto-populate device and app context
        #if os(iOS)
        self.deviceType = .iPhone
        #elseif os(watchOS)
        self.deviceType = .appleWatch
        #else
        self.deviceType = .other
        #endif
        
        self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        self.sessionId = UUID().uuidString
    }
    
    // MARK: - MLFeatureProvider Protocol
    
    /// Feature names required by the Core ML model
    var featureNames: Set<String> {
        return Set([
            "query", "response_type", "conversation_turn", "time_of_day",
            "is_weekend", "hour", "formality_level", "response_length",
            "enthusiasm", "helpfulness", "friendliness", "professionalism",
            "history_length", "recent_history", "device_type", "app_version"
        ])
    }
    
    /// Returns feature value for given name
    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "query":
            return MLFeatureValue(string: query)
        case "response_type":
            return MLFeatureValue(string: responseType.rawValue)
        case "conversation_turn":
            return MLFeatureValue(int64: Int64(context.conversationTurn))
        case "time_of_day":
            return MLFeatureValue(string: timeContext.timeOfDay.rawValue)
        case "is_weekend":
            return MLFeatureValue(int64: timeContext.isWeekend ? 1 : 0)
        case "hour":
            return MLFeatureValue(int64: Int64(timeContext.hour))
        case "formality_level":
            return MLFeatureValue(double: userPreferences.formalityLevel)
        case "response_length":
            return MLFeatureValue(string: userPreferences.responseLength.rawValue)
        case "enthusiasm":
            return MLFeatureValue(double: userPreferences.personalityTraits.enthusiasm)
        case "helpfulness":
            return MLFeatureValue(double: userPreferences.personalityTraits.helpfulness)
        case "friendliness":
            return MLFeatureValue(double: userPreferences.personalityTraits.friendliness)
        case "professionalism":
            return MLFeatureValue(double: userPreferences.personalityTraits.professionalism)
        case "history_length":
            return MLFeatureValue(int64: Int64(conversationHistory.count))
        case "recent_history":
            return MLFeatureValue(string: conversationHistory.suffix(3).joined(separator: " | "))
        case "device_type":
            return MLFeatureValue(string: deviceType.rawValue)
        case "app_version":
            return MLFeatureValue(string: appVersion)
        default:
            return nil
        }
    }
    
    // MARK: - Preprocessing Methods
    
    /// Preprocessed query text ready for model input
    var preprocessedQuery: String {
        return query
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    /// Context summary for model input
    var contextSummary: String {
        var summary = "Turn \(context.conversationTurn), \(timeContext.timeOfDay.rawValue)"
        
        if timeContext.isWeekend {
            summary += ", weekend"
        }
        
        if let lastResponseType = context.lastResponseType {
            summary += ", after \(lastResponseType)"
        }
        
        return summary
    }
    
    /// User preference summary
    var preferenceSummary: String {
        let formality = userPreferences.formalityLevel > 0.7 ? "formal" : 
                       userPreferences.formalityLevel < 0.3 ? "casual" : "balanced"
        let length = userPreferences.responseLength.rawValue
        
        return "\(formality), \(length) responses"
    }
}

// MARK: - Supporting Types

enum DeviceType: String, CaseIterable {
    case iPhone = "iphone"
    case appleWatch = "apple_watch"
    case other = "other"
}

// MARK: - TimeOfDay Extension

extension TimeOfDay: CustomStringConvertible {
    var description: String {
        switch self {
        case .morning: return "morning"
        case .afternoon: return "afternoon"
        case .evening: return "evening"
        case .night: return "night"
        }
    }
    
    var rawValue: String {
        return description
    }
}