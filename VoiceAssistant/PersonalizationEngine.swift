import Foundation
import CryptoKit

/// Engine that learns user's preferred response styles and adapts interactions
/// while maintaining privacy with on-device learning
@MainActor
class PersonalizationEngine: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentPreferences: UserPreferences
    @Published var learningStatistics = LearningStats()
    @Published var isLearning = false
    
    // MARK: - Private Properties
    private let userDefaults: UserDefaults
    private let encryptionKey: SymmetricKey
    private let preferenceAnalyzer: PreferenceAnalyzer
    private let styleAdaptationEngine: StyleAdaptationEngine
    private let privacyProtector: PrivacyProtector
    
    // MARK: - Configuration
    private let maxInteractionHistory = 1000
    private let learningThreshold = 10 // Minimum interactions before strong adaptation
    private let adaptationStrength: Double = 0.3 // How quickly to adapt (0.0-1.0)
    
    // MARK: - Initialization
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.encryptionKey = PersonalizationEngine.getOrCreateEncryptionKey()
        self.preferenceAnalyzer = PreferenceAnalyzer()
        self.styleAdaptationEngine = StyleAdaptationEngine()
        self.privacyProtector = PrivacyProtector()
        
        // Load existing preferences or create defaults
        self.currentPreferences = PersonalizationEngine.loadPreferences(
            from: userDefaults,
            encryptionKey: encryptionKey
        ) ?? UserPreferences.default
        
        // Set up periodic learning updates
        setupPeriodicLearning()
    }
    
    // MARK: - Main Personalization Methods
    
    /// Personalizes a response based on learned user preferences
    func personalizeResponse(
        _ response: String,
        for preferences: UserPreferences
    ) async -> String {
        
        isLearning = true
        defer { isLearning = false }
        
        var personalizedResponse = response
        
        // Apply formality level adaptation
        personalizedResponse = styleAdaptationEngine.adaptFormality(
            personalizedResponse,
            to: preferences.formalityLevel
        )
        
        // Apply response length preference
        personalizedResponse = styleAdaptationEngine.adaptLength(
            personalizedResponse,
            to: preferences.responseLength
        )
        
        // Apply personality traits
        personalizedResponse = styleAdaptationEngine.applyPersonality(
            personalizedResponse,
            traits: preferences.personalityTraits
        )
        
        // Apply locale-specific adaptations
        if let locale = preferences.preferredLocale {
            personalizedResponse = styleAdaptationEngine.adaptForLocale(
                personalizedResponse,
                locale: locale
            )
        }
        
        // Apply time-of-day context
        personalizedResponse = styleAdaptationEngine.adaptForTimeContext(
            personalizedResponse,
            timeOfDay: getCurrentTimeOfDay(),
            preferences: preferences
        )
        
        return personalizedResponse
    }
    
    /// Records user interaction and updates learned preferences
    func recordInteraction(
        userQuery: String,
        response: String,
        userFeedback: UserFeedback?
    ) async {
        
        let interaction = UserInteraction(
            query: userQuery,
            response: response,
            feedback: userFeedback,
            timestamp: Date(),
            context: InteractionContext.current()
        )
        
        // Analyze interaction for learning opportunities
        let analysis = await preferenceAnalyzer.analyzeInteraction(interaction)
        
        // Update preferences based on analysis
        await updatePreferences(with: analysis)
        
        // Store interaction history (encrypted)
        await storeInteractionHistory(interaction)
        
        // Update learning statistics
        learningStatistics.totalInteractions += 1
        if userFeedback != nil {
            learningStatistics.feedbackReceived += 1
        }
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .personalizationUpdated, object: nil)
    }
    
    /// Learns user's preferred response styles from interaction patterns
    func learnFromInteractionPatterns() async {
        
        let interactions = await loadRecentInteractions()
        guard interactions.count >= learningThreshold else {
            return
        }
        
        isLearning = true
        defer { isLearning = false }
        
        // Analyze patterns across multiple dimensions
        let patterns = await preferenceAnalyzer.analyzePatterns(interactions)
        
        // Update preferences based on detected patterns
        var updatedPreferences = currentPreferences
        
        // Formality level learning
        if let detectedFormality = patterns.dominantFormality {
            updatedPreferences.formalityLevel = lerp(
                from: updatedPreferences.formalityLevel,
                to: detectedFormality,
                alpha: adaptationStrength
            )
        }
        
        // Response length preference
        if let preferredLength = patterns.preferredResponseLength {
            updatedPreferences.responseLength = preferredLength
        }
        
        // Time-based preferences
        if let timePrefs = patterns.timeBasedPreferences {
            updatedPreferences.timeBasedPreferences = timePrefs
        }
        
        // Personality trait adaptation
        if let traits = patterns.preferredPersonalityTraits {
            updatedPreferences.personalityTraits = adaptPersonalityTraits(
                current: updatedPreferences.personalityTraits,
                detected: traits
            )
        }
        
        // Measurement system preference
        if let measurementSystem = patterns.preferredMeasurementSystem {
            updatedPreferences.measurementSystem = measurementSystem
        }
        
        // Update current preferences
        currentPreferences = updatedPreferences
        
        // Persist changes
        await savePreferences()
        
        learningStatistics.lastLearningUpdate = Date()
        learningStatistics.adaptationsMade += 1
    }
    
    // MARK: - Formality Adaptation
    
    /// Adapts formality level based on user patterns
    func adaptFormalityLevel(basedOn feedback: UserFeedback, currentLevel: Double) -> Double {
        switch feedback {
        case .tooFormal:
            return max(0.0, currentLevel - 0.1)
        case .tooInformal:
            return min(1.0, currentLevel + 0.1)
        case .justRight:
            return currentLevel // No change needed
        case .positive:
            return currentLevel // Maintain current level
        case .negative:
            // Adjust based on current context
            return currentLevel > 0.5 ? currentLevel - 0.05 : currentLevel + 0.05
        }
    }
    
    // MARK: - Privacy and Preferences
    
    /// Maintains privacy with on-device learning
    func ensurePrivacyCompliance() async {
        // Remove old data beyond retention policy
        await privacyProtector.cleanupOldData(
            maxAge: TimeInterval(30 * 24 * 60 * 60) // 30 days
        )
        
        // Anonymize stored patterns
        await privacyProtector.anonymizePersonalData()
        
        // Ensure encryption keys are rotated periodically
        await privacyProtector.rotateEncryptionKeys()
    }
    
    /// Remembers user preferences across sessions
    func rememberPreference(key: PreferenceKey, value: Any) async {
        var prefs = currentPreferences
        
        switch key {
        case .measurementSystem:
            if let system = value as? MeasurementSystem {
                prefs.measurementSystem = system
            }
        case .formalityLevel:
            if let level = value as? Double {
                prefs.formalityLevel = max(0.0, min(1.0, level))
            }
        case .responseLength:
            if let length = value as? ResponseLength {
                prefs.responseLength = length
            }
        case .timeFormat:
            if let format = value as? TimeFormat {
                prefs.timeFormat = format
            }
        case .personality:
            if let traits = value as? PersonalityTraits {
                prefs.personalityTraits = traits
            }
        }
        
        currentPreferences = prefs
        await savePreferences()
    }
    
    // MARK: - Private Helper Methods
    
    private func updatePreferences(with analysis: InteractionAnalysis) async {
        var prefs = currentPreferences
        
        // Apply weighted updates based on confidence
        if analysis.confidence > 0.7 {
            if let suggestedFormality = analysis.suggestedFormality {
                prefs.formalityLevel = lerp(
                    from: prefs.formalityLevel,
                    to: suggestedFormality,
                    alpha: adaptationStrength * analysis.confidence
                )
            }
            
            if let suggestedLength = analysis.suggestedResponseLength {
                prefs.responseLength = suggestedLength
            }
            
            if let suggestedPersonality = analysis.suggestedPersonality {
                prefs.personalityTraits = adaptPersonalityTraits(
                    current: prefs.personalityTraits,
                    detected: suggestedPersonality
                )
            }
        }
        
        currentPreferences = prefs
        await savePreferences()
    }
    
    private func savePreferences() async {
        let encrypted = try? PersonalizationEngine.encryptPreferences(
            currentPreferences,
            key: encryptionKey
        )
        
        if let encryptedData = encrypted {
            userDefaults.set(encryptedData, forKey: "encrypted_user_preferences")
        }
    }
    
    private func storeInteractionHistory(_ interaction: UserInteraction) async {
        var history = await loadRecentInteractions()
        history.append(interaction)
        
        // Keep only recent interactions
        if history.count > maxInteractionHistory {
            history = Array(history.suffix(maxInteractionHistory))
        }
        
        // Encrypt and store
        if let encrypted = try? PersonalizationEngine.encryptInteractionHistory(
            history,
            key: encryptionKey
        ) {
            userDefaults.set(encrypted, forKey: "encrypted_interaction_history")
        }
    }
    
    private func loadRecentInteractions() async -> [UserInteraction] {
        guard let encryptedData = userDefaults.data(forKey: "encrypted_interaction_history"),
              let interactions = try? PersonalizationEngine.decryptInteractionHistory(
                encryptedData,
                key: encryptionKey
              ) else {
            return []
        }
        return interactions
    }
    
    private func adaptPersonalityTraits(
        current: PersonalityTraits,
        detected: PersonalityTraits
    ) -> PersonalityTraits {
        return PersonalityTraits(
            enthusiasm: lerp(from: current.enthusiasm, to: detected.enthusiasm, alpha: adaptationStrength),
            helpfulness: lerp(from: current.helpfulness, to: detected.helpfulness, alpha: adaptationStrength),
            friendliness: lerp(from: current.friendliness, to: detected.friendliness, alpha: adaptationStrength),
            professionalism: lerp(from: current.professionalism, to: detected.professionalism, alpha: adaptationStrength)
        )
    }
    
    private func lerp(from: Double, to: Double, alpha: Double) -> Double {
        return from + (to - from) * alpha
    }
    
    private func getCurrentTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
    
    private func setupPeriodicLearning() {
        // Learn from patterns every hour during active use
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.learnFromInteractionPatterns()
            }
        }
    }
    
    // MARK: - Static Helper Methods
    
    private static func getOrCreateEncryptionKey() -> SymmetricKey {
        let keyData = UserDefaults.standard.data(forKey: "personalization_encryption_key")
        
        if let existingKey = keyData {
            return SymmetricKey(data: existingKey)
        } else {
            let newKey = SymmetricKey(size: .bits256)
            UserDefaults.standard.set(newKey.withUnsafeBytes { Data($0) }, 
                                     forKey: "personalization_encryption_key")
            return newKey
        }
    }
    
    private static func loadPreferences(
        from userDefaults: UserDefaults,
        encryptionKey: SymmetricKey
    ) -> UserPreferences? {
        guard let encryptedData = userDefaults.data(forKey: "encrypted_user_preferences") else {
            return nil
        }
        
        return try? decryptPreferences(encryptedData, key: encryptionKey)
    }
    
    private static func encryptPreferences(
        _ preferences: UserPreferences,
        key: SymmetricKey
    ) throws -> Data {
        let data = try JSONEncoder().encode(preferences)
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined ?? Data()
    }
    
    private static func decryptPreferences(
        _ encryptedData: Data,
        key: SymmetricKey
    ) throws -> UserPreferences {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        return try JSONDecoder().decode(UserPreferences.self, from: decryptedData)
    }
    
    private static func encryptInteractionHistory(
        _ history: [UserInteraction],
        key: SymmetricKey
    ) throws -> Data {
        let data = try JSONEncoder().encode(history)
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined ?? Data()
    }
    
    private static func decryptInteractionHistory(
        _ encryptedData: Data,
        key: SymmetricKey
    ) throws -> [UserInteraction] {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        return try JSONDecoder().decode([UserInteraction].self, from: decryptedData)
    }
}

// MARK: - Supporting Types

struct UserPreferences: Codable {
    var formalityLevel: Double // 0.0 = very casual, 1.0 = very formal
    var responseLength: ResponseLength
    var measurementSystem: MeasurementSystem
    var timeFormat: TimeFormat
    var personalityTraits: PersonalityTraits
    var preferredLocale: Locale?
    var timeBasedPreferences: TimeBasedPreferences
    
    static let `default` = UserPreferences(
        formalityLevel: 0.5,
        responseLength: .medium,
        measurementSystem: .metric,
        timeFormat: .twelveHour,
        personalityTraits: PersonalityTraits.default,
        preferredLocale: Locale.current,
        timeBasedPreferences: TimeBasedPreferences.default
    )
}

enum ResponseLength: String, Codable, CaseIterable {
    case brief = "brief"
    case medium = "medium" 
    case detailed = "detailed"
}

enum MeasurementSystem: String, Codable, CaseIterable {
    case metric = "metric"
    case imperial = "imperial"
}

enum TimeFormat: String, Codable, CaseIterable {
    case twelveHour = "12h"
    case twentyFourHour = "24h"
}

struct PersonalityTraits: Codable {
    var enthusiasm: Double // 0.0 = reserved, 1.0 = enthusiastic
    var helpfulness: Double // 0.0 = direct, 1.0 = very helpful
    var friendliness: Double // 0.0 = professional, 1.0 = friendly
    var professionalism: Double // 0.0 = casual, 1.0 = professional
    
    static let `default` = PersonalityTraits(
        enthusiasm: 0.6,
        helpfulness: 0.8,
        friendliness: 0.7,
        professionalism: 0.5
    )
}

struct TimeBasedPreferences: Codable {
    var morningGreeting: String
    var afternoonGreeting: String
    var eveningGreeting: String
    var nightGreeting: String
    var morningFormality: Double
    var eveningFormality: Double
    
    static let `default` = TimeBasedPreferences(
        morningGreeting: "Good morning",
        afternoonGreeting: "Good afternoon", 
        eveningGreeting: "Good evening",
        nightGreeting: "Good evening",
        morningFormality: 0.4, // More casual in morning
        eveningFormality: 0.6  // Slightly more formal in evening
    )
}

enum UserFeedback: String, Codable {
    case positive = "positive"
    case negative = "negative"
    case tooFormal = "too_formal"
    case tooInformal = "too_informal"
    case justRight = "just_right"
}

enum PreferenceKey {
    case measurementSystem
    case formalityLevel
    case responseLength
    case timeFormat
    case personality
}

struct UserInteraction: Codable {
    let query: String
    let response: String
    let feedback: UserFeedback?
    let timestamp: Date
    let context: InteractionContext
}

enum TimeOfDay: String, Codable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"
}

struct InteractionContext: Codable {
    let timeOfDay: TimeOfDay
    let dayOfWeek: Int
    let isWeekend: Bool
    let appVersion: String
    
    static func current() -> InteractionContext {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let dayOfWeek = calendar.component(.weekday, from: now)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        
        let timeOfDay: TimeOfDay
        switch hour {
        case 5..<12: timeOfDay = .morning
        case 12..<17: timeOfDay = .afternoon
        case 17..<21: timeOfDay = .evening
        default: timeOfDay = .night
        }
        
        return InteractionContext(
            timeOfDay: timeOfDay,
            dayOfWeek: dayOfWeek,
            isWeekend: isWeekend,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        )
    }
}

struct LearningStats {
    var totalInteractions: Int = 0
    var feedbackReceived: Int = 0
    var adaptationsMade: Int = 0
    var lastLearningUpdate: Date?
    
    var feedbackRate: Double {
        totalInteractions > 0 ? Double(feedbackReceived) / Double(totalInteractions) : 0.0
    }
}

struct InteractionAnalysis {
    let confidence: Double
    let suggestedFormality: Double?
    let suggestedResponseLength: ResponseLength?
    let suggestedPersonality: PersonalityTraits?
}

struct InteractionPatterns {
    let dominantFormality: Double?
    let preferredResponseLength: ResponseLength?
    let preferredPersonalityTraits: PersonalityTraits?
    let timeBasedPreferences: TimeBasedPreferences?
    let preferredMeasurementSystem: MeasurementSystem?
}

// MARK: - Helper Classes

class PreferenceAnalyzer {
    func analyzeInteraction(_ interaction: UserInteraction) async -> InteractionAnalysis {
        // Analyze the interaction for personalization insights
        var suggestedFormality: Double?
        var suggestedLength: ResponseLength?
        var suggestedPersonality: PersonalityTraits?
        
        // Analyze feedback
        if let feedback = interaction.feedback {
            switch feedback {
            case .tooFormal:
                suggestedFormality = 0.3
            case .tooInformal:
                suggestedFormality = 0.8
            case .justRight:
                // Current settings are good
                break
            case .positive:
                // Reinforce current style
                break
            case .negative:
                // Need to analyze what went wrong
                break
            }
        }
        
        // Analyze response length preference from query patterns
        let queryLength = interaction.query.count
        if queryLength < 20 {
            suggestedLength = .brief
        } else if queryLength > 100 {
            suggestedLength = .detailed
        }
        
        return InteractionAnalysis(
            confidence: 0.7,
            suggestedFormality: suggestedFormality,
            suggestedResponseLength: suggestedLength,
            suggestedPersonality: suggestedPersonality
        )
    }
    
    func analyzePatterns(_ interactions: [UserInteraction]) async -> InteractionPatterns {
        // Analyze patterns across multiple interactions
        let formalityFeedback = interactions.compactMap { interaction in
            switch interaction.feedback {
            case .tooFormal: return 0.2
            case .tooInformal: return 0.8
            case .justRight: return 0.5
            default: return nil
            }
        }
        
        let avgFormality = formalityFeedback.isEmpty ? nil : 
            formalityFeedback.reduce(0, +) / Double(formalityFeedback.count)
        
        return InteractionPatterns(
            dominantFormality: avgFormality,
            preferredResponseLength: nil,
            preferredPersonalityTraits: nil,
            timeBasedPreferences: nil,
            preferredMeasurementSystem: nil
        )
    }
}

class StyleAdaptationEngine {
    func adaptFormality(_ response: String, to level: Double) -> String {
        // Adapt response formality
        if level < 0.3 {
            // Make more casual
            return response
                .replacingOccurrences(of: "Good morning", with: "Morning")
                .replacingOccurrences(of: "I would be happy to", with: "I can")
                .replacingOccurrences(of: "please", with: "")
        } else if level > 0.7 {
            // Make more formal
            return response
                .replacingOccurrences(of: "Hi", with: "Good day")
                .replacingOccurrences(of: "I can", with: "I would be happy to")
                .replacingOccurrences(of: "OK", with: "Certainly")
        }
        
        return response
    }
    
    func adaptLength(_ response: String, to length: ResponseLength) -> String {
        switch length {
        case .brief:
            // Shorten response, remove extra details
            let sentences = response.components(separatedBy: ". ")
            return sentences.prefix(1).joined(separator: ". ")
        case .detailed:
            // Could expand response with more context
            return response
        case .medium:
            return response
        }
    }
    
    func applyPersonality(_ response: String, traits: PersonalityTraits) -> String {
        var result = response
        
        // Apply enthusiasm
        if traits.enthusiasm > 0.7 {
            result = result.replacingOccurrences(of: "OK", with: "Great!")
            result = result.replacingOccurrences(of: "Done", with: "All set!")
        }
        
        // Apply friendliness
        if traits.friendliness > 0.7 {
            if !result.hasSuffix("!") && !result.hasSuffix(".") {
                result += "!"
            }
        }
        
        return result
    }
    
    func adaptForLocale(_ response: String, locale: Locale) -> String {
        // Adapt for locale-specific preferences
        return response
    }
    
    func adaptForTimeContext(
        _ response: String,
        timeOfDay: TimeOfDay,
        preferences: UserPreferences
    ) -> String {
        var result = response
        
        // Apply time-based adaptations
        switch timeOfDay {
        case .morning:
            if result.contains("Hello") {
                result = result.replacingOccurrences(of: "Hello", 
                                                   with: preferences.timeBasedPreferences.morningGreeting)
            }
        case .afternoon:
            if result.contains("Hello") {
                result = result.replacingOccurrences(of: "Hello", 
                                                   with: preferences.timeBasedPreferences.afternoonGreeting)
            }
        case .evening, .night:
            if result.contains("Hello") {
                result = result.replacingOccurrences(of: "Hello", 
                                                   with: preferences.timeBasedPreferences.eveningGreeting)
            }
        }
        
        return result
    }
}

class PrivacyProtector {
    func cleanupOldData(maxAge: TimeInterval) async {
        // Remove data older than maxAge
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        // Implementation would clean up old interactions
    }
    
    func anonymizePersonalData() async {
        // Remove or hash personal identifiers
        // Keep only patterns, not raw data
    }
    
    func rotateEncryptionKeys() async {
        // Periodically rotate encryption keys for added security
        // Re-encrypt data with new keys
    }
}