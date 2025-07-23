import Foundation
import NaturalLanguage

/// Engine for applying variations to responses to avoid repetition and add personality
class ResponseVariationEngine {
    
    // MARK: - Variation History
    private var recentVariations: [String: VariationHistory] = [:]
    private let maxHistorySize = 50
    private let repetitionThreshold = 3
    
    // MARK: - Personality Mappings
    private let personalityModifiers: [PersonalityType: PersonalityModifier]
    private let contextualModifiers: [TimeOfDay: ContextModifier]
    private let variationStrategies: [VariationStrategy]
    
    // MARK: - NL Processing
    private let tagger = NLTagger(tagSchemes: [.tokenType, .lexicalClass, .sentimentScore])
    
    // MARK: - Initialization
    init() {
        self.personalityModifiers = ResponseVariationEngine.createPersonalityModifiers()
        self.contextualModifiers = ResponseVariationEngine.createContextualModifiers()
        self.variationStrategies = ResponseVariationEngine.createVariationStrategies()
    }
    
    // MARK: - Main Variation Methods
    
    /// Applies variations to a response to avoid repetition and match personality
    func applyVariation(
        to response: String,
        context: ConversationContext,
        preferences: UserPreferences
    ) async -> String {
        
        let responseSignature = generateResponseSignature(response)
        
        // Check if we need variation to avoid repetition
        let needsVariation = shouldApplyVariation(
            signature: responseSignature,
            context: context
        )
        
        var variedResponse = response
        
        if needsVariation {
            // Apply structural variations first
            variedResponse = await applyStructuralVariations(variedResponse, context: context)
            
            // Apply vocabulary variations
            variedResponse = await applyVocabularyVariations(variedResponse, preferences: preferences)
        }
        
        // Always apply personality and contextual variations
        variedResponse = await applyPersonalityVariations(variedResponse, preferences: preferences)
        variedResponse = await applyContextualVariations(variedResponse, context: context)
        variedResponse = await applySuggestionVariations(variedResponse, context: context)
        
        // Record this variation
        recordVariation(signature: responseSignature, variation: variedResponse)
        
        return variedResponse
    }
    
    // MARK: - Repetition Avoidance
    
    private func shouldApplyVariation(
        signature: String,
        context: ConversationContext
    ) -> Bool {
        
        guard let history = recentVariations[signature] else {
            return false // First time using this response
        }
        
        // Check recent usage frequency
        let recentUsage = history.usageTimestamps.filter { 
            Date().timeIntervalSince($0) < 3600 // Within last hour
        }.count
        
        return recentUsage >= repetitionThreshold
    }
    
    private func recordVariation(signature: String, variation: String) {
        if var history = recentVariations[signature] {
            history.usageTimestamps.append(Date())
            history.variations.append(variation)
            
            // Keep only recent history
            let cutoffTime = Date().addingTimeInterval(-7200) // 2 hours
            history.usageTimestamps = history.usageTimestamps.filter { $0 > cutoffTime }
            
            if history.variations.count > 10 {
                history.variations = Array(history.variations.suffix(10))
            }
            
            recentVariations[signature] = history
        } else {
            recentVariations[signature] = VariationHistory(
                usageTimestamps: [Date()],
                variations: [variation]
            )
        }
        
        // Clean up old entries
        if recentVariations.count > maxHistorySize {
            let oldKeys = Array(recentVariations.keys).prefix(10)
            for key in oldKeys {
                recentVariations.removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - Structural Variations
    
    private func applyStructuralVariations(
        _ response: String,
        context: ConversationContext
    ) async -> String {
        
        // Try different structural variation strategies
        for strategy in variationStrategies {
            if let varied = strategy.apply(response, context) {
                return varied
            }
        }
        
        return response
    }
    
    // MARK: - Vocabulary Variations
    
    private func applyVocabularyVariations(
        _ response: String,
        preferences: UserPreferences
    ) async -> String {
        
        var result = response
        
        // Synonym replacement based on formality level
        result = await applySynonymReplacements(result, formality: preferences.formalityLevel)
        
        // Intensity modulation
        result = await applyIntensityModulation(result, preferences: preferences)
        
        // Connector word variations
        result = await applyConnectorVariations(result)
        
        return result
    }
    
    private func applySynonymReplacements(
        _ response: String,
        formality: Double
    ) async -> String {
        
        var result = response
        
        // Define synonym groups by formality level
        let synonymGroups: [String: [Double: String]] = [
            "great": [0.2: "awesome", 0.5: "great", 0.8: "excellent"],
            "ok": [0.2: "cool", 0.5: "okay", 0.8: "certainly"],
            "done": [0.2: "got it", 0.5: "done", 0.8: "completed"],
            "help": [0.2: "help out", 0.5: "help", 0.8: "assist"],
            "sure": [0.2: "yep", 0.5: "sure", 0.8: "of course"],
            "perfect": [0.2: "nice", 0.5: "perfect", 0.8: "excellent"],
            "hi": [0.2: "hey", 0.5: "hello", 0.8: "good day"]
        ]
        
        for (baseWord, variants) in synonymGroups {
            if result.lowercased().contains(baseWord.lowercased()) {
                // Find closest formality match
                let closestLevel = variants.keys.min { abs($0 - formality) < abs($1 - formality) }
                if let level = closestLevel, let replacement = variants[level] {
                    result = result.replacingOccurrences(
                        of: baseWord,
                        with: replacement,
                        options: .caseInsensitive
                    )
                }
            }
        }
        
        return result
    }
    
    private func applyIntensityModulation(
        _ response: String,
        preferences: UserPreferences
    ) async -> String {
        
        let enthusiasmLevel = preferences.personalityTraits.enthusiasm
        var result = response
        
        if enthusiasmLevel > 0.7 {
            // Add enthusiasm
            result = result.replacingOccurrences(of: "!", with: "!")
            result = result.replacingOccurrences(of: ".", with: "!")
            
            // Add intensifiers
            let intensifiers = ["really", "definitely", "absolutely", "totally"]
            let randomIntensifier = intensifiers.randomElement() ?? "really"
            
            if !result.contains(randomIntensifier) && arc4random_uniform(3) == 0 {
                result = result.replacingOccurrences(
                    of: "I can",
                    with: "I can \(randomIntensifier)"
                )
            }
        } else if enthusiasmLevel < 0.3 {
            // Reduce enthusiasm
            result = result.replacingOccurrences(of: "!", with: ".")
            result = result.replacingOccurrences(of: "Great", with: "Okay")
            result = result.replacingOccurrences(of: "Perfect", with: "Alright")
        }
        
        return result
    }
    
    private func applyConnectorVariations(_ response: String) async -> String {
        var result = response
        
        let connectorVariations: [String: [String]] = [
            "and": ["and", "plus", "also"],
            "but": ["but", "however", "though"],
            "so": ["so", "therefore", "thus"],
            "also": ["also", "additionally", "as well"],
            "now": ["now", "currently", "at the moment"]
        ]
        
        for (original, variations) in connectorVariations {
            if result.contains(original), let replacement = variations.randomElement() {
                result = result.replacingOccurrences(of: original, with: replacement)
            }
        }
        
        return result
    }
    
    // MARK: - Personality Variations
    
    private func applyPersonalityVariations(
        _ response: String,
        preferences: UserPreferences
    ) async -> String {
        
        let traits = preferences.personalityTraits
        var result = response
        
        // Apply enthusiasm modifications
        if let modifier = personalityModifiers[.enthusiastic] {
            result = modifier.apply(to: result, intensity: traits.enthusiasm)
        }
        
        // Apply helpfulness modifications
        if let modifier = personalityModifiers[.helpful] {
            result = modifier.apply(to: result, intensity: traits.helpfulness)
        }
        
        // Apply friendliness modifications
        if let modifier = personalityModifiers[.friendly] {
            result = modifier.apply(to: result, intensity: traits.friendliness)
        }
        
        // Apply professionalism modifications
        if let modifier = personalityModifiers[.professional] {
            result = modifier.apply(to: result, intensity: traits.professionalism)
        }
        
        return result
    }
    
    // MARK: - Contextual Variations
    
    private func applyContextualVariations(
        _ response: String,
        context: ConversationContext
    ) async -> String {
        
        var result = response
        
        // Apply time-of-day contextual modifications
        if let modifier = contextualModifiers[context.timeContext.timeOfDay] {
            result = modifier.apply(to: result, context: context)
        }
        
        // Apply conversation length variations
        if context.conversationTurn > 5 {
            result = applyFamiliarityVariations(result)
        }
        
        return result
    }
    
    private func applyFamiliarityVariations(_ response: String) -> String {
        // Make responses slightly more casual in longer conversations
        return response
            .replacingOccurrences(of: "I would be happy to", with: "I'll")
            .replacingOccurrences(of: "How may I assist you?", with: "What else can I help with?")
            .replacingOccurrences(of: "Certainly", with: "Sure thing")
    }
    
    // MARK: - Suggestion Variations
    
    private func applySuggestionVariations(
        _ response: String,
        context: ConversationContext
    ) async -> String {
        
        // Add contextual follow-up suggestions
        let timeOfDay = context.timeContext.timeOfDay
        let suggestions = generateContextualSuggestions(response: response, timeOfDay: timeOfDay)
        
        if !suggestions.isEmpty && arc4random_uniform(3) == 0 { // 33% chance
            let randomSuggestion = suggestions.randomElement()!
            return "\(response) \(randomSuggestion)"
        }
        
        return response
    }
    
    private func generateContextualSuggestions(
        response: String,
        timeOfDay: TimeOfDay
    ) -> [String] {
        
        var suggestions: [String] = []
        
        // Time-based suggestions
        switch timeOfDay {
        case .morning:
            if response.contains("calendar") || response.contains("meeting") {
                suggestions.append("Would you like me to brief you on today's schedule?")
            }
        case .afternoon:
            if response.contains("task") {
                suggestions.append("Need help prioritizing your remaining tasks?")
            }
        case .evening:
            if response.contains("email") {
                suggestions.append("Should I help you clear your inbox?")
            }
        case .night:
            suggestions.append("Anything else before you wrap up for the day?")
        }
        
        // Content-based suggestions
        if response.contains("weather") {
            suggestions.append("Need recommendations based on the weather?")
        }
        
        if response.contains("meeting") {
            suggestions.append("Would you like me to prepare meeting notes?")
        }
        
        return suggestions
    }
    
    // MARK: - Utility Methods
    
    private func generateResponseSignature(_ response: String) -> String {
        // Create a signature based on response structure and key content
        let words = response.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let contentWords = words.filter { !stopWords.contains($0) && $0.count > 2 }
        let keyWords = Array(contentWords.prefix(5))
        return keyWords.joined(separator: "_")
    }
    
    private let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
        "is", "are", "was", "were", "be", "been", "have", "has", "had", "do", "does", "did",
        "will", "would", "could", "should", "can", "may", "might", "i", "you", "he", "she",
        "it", "we", "they", "me", "him", "her", "us", "them", "my", "your", "his", "her",
        "its", "our", "their"
    ]
    
    // MARK: - Static Initialization Methods
    
    private static func createPersonalityModifiers() -> [PersonalityType: PersonalityModifier] {
        return [
            .enthusiastic: PersonalityModifier { response, intensity in
                guard intensity > 0.6 else { return response }
                return response
                    .replacingOccurrences(of: "Done", with: "Fantastic!")
                    .replacingOccurrences(of: "OK", with: "Perfect!")
                    .replacingOccurrences(of: "Sure", with: "Absolutely!")
            },
            
            .helpful: PersonalityModifier { response, intensity in
                guard intensity > 0.7 else { return response }
                let helpfulAdditions = [
                    "Let me know if you need anything else!",
                    "I'm here if you have more questions.",
                    "Feel free to ask if you need more help."
                ]
                
                if arc4random_uniform(4) == 0, let addition = helpfulAdditions.randomElement() {
                    return "\(response) \(addition)"
                }
                return response
            },
            
            .friendly: PersonalityModifier { response, intensity in
                guard intensity > 0.6 else { return response }
                return response
                    .replacingOccurrences(of: "Hi", with: "Hey there")
                    .replacingOccurrences(of: "Hello", with: "Hi there")
                    .replacingOccurrences(of: "Good", with: "Hope you're having a good")
            },
            
            .professional: PersonalityModifier { response, intensity in
                guard intensity > 0.7 else { return response }
                return response
                    .replacingOccurrences(of: "Hey", with: "Hello")
                    .replacingOccurrences(of: "Yeah", with: "Yes")
                    .replacingOccurrences(of: "OK", with: "Certainly")
                    .replacingOccurrences(of: "Great", with: "Excellent")
            }
        ]
    }
    
    private static func createContextualModifiers() -> [TimeOfDay: ContextModifier] {
        return [
            .morning: ContextModifier { response, context in
                if response.contains("Hello") && arc4random_uniform(3) == 0 {
                    return response.replacingOccurrences(of: "Hello", with: "Good morning")
                }
                return response
            },
            
            .afternoon: ContextModifier { response, context in
                if response.contains("Hello") && arc4random_uniform(3) == 0 {
                    return response.replacingOccurrences(of: "Hello", with: "Good afternoon")
                }
                return response
            },
            
            .evening: ContextModifier { response, context in
                if response.contains("Hello") && arc4random_uniform(3) == 0 {
                    return response.replacingOccurrences(of: "Hello", with: "Good evening")
                }
                // More relaxed tone in evening
                return response.replacingOccurrences(of: "I would", with: "I'd")
            },
            
            .night: ContextModifier { response, context in
                // Keep it brief and casual at night
                return response
                    .replacingOccurrences(of: "How can I help you today?", with: "What can I help with?")
                    .replacingOccurrences(of: "Is there anything else?", with: "Need anything else?")
            }
        ]
    }
    
    private static func createVariationStrategies() -> [VariationStrategy] {
        return [
            // Sentence reordering strategy
            VariationStrategy { response, context in
                let sentences = response.components(separatedBy: ". ")
                guard sentences.count > 1 else { return nil }
                
                // Randomly reorder sentences (simple variation)
                if arc4random_uniform(4) == 0 {
                    var shuffled = sentences
                    shuffled.shuffle()
                    return shuffled.joined(separator: ". ")
                }
                
                return nil
            },
            
            // Question to statement conversion
            VariationStrategy { response, context in
                if response.hasSuffix("?") && arc4random_uniform(3) == 0 {
                    let statement = String(response.dropLast())
                    return "\(statement)."
                }
                return nil
            },
            
            // Add transitional phrases
            VariationStrategy { response, context in
                let transitions = ["Well, ", "So, ", "Alright, ", "Let me see... "]
                
                if arc4random_uniform(5) == 0, let transition = transitions.randomElement() {
                    return "\(transition)\(response.lowercaseFirst)"
                }
                
                return nil
            }
        ]
    }
}

// MARK: - Supporting Types

struct VariationHistory {
    var usageTimestamps: [Date]
    var variations: [String]
}

enum PersonalityType {
    case enthusiastic
    case helpful
    case friendly
    case professional
}

struct PersonalityModifier {
    let apply: (String, Double) -> String
    
    init(apply: @escaping (String, Double) -> String) {
        self.apply = apply
    }
}

struct ContextModifier {
    let apply: (String, ConversationContext) -> String
    
    init(apply: @escaping (String, ConversationContext) -> String) {
        self.apply = apply
    }
}

struct VariationStrategy {
    let apply: (String, ConversationContext) -> String?
    
    init(apply: @escaping (String, ConversationContext) -> String?) {
        self.apply = apply
    }
}

// MARK: - String Extensions

extension String {
    var lowercaseFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).lowercased() + dropFirst()
    }
    
    var uppercaseFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }
}