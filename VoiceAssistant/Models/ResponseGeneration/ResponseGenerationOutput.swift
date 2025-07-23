import Foundation
import CoreML

/// Output structure for Core ML response generation model
class ResponseGenerationOutput: NSObject, MLFeatureProvider {
    
    // MARK: - Primary Output
    let generatedText: String
    let confidence: Double
    
    // MARK: - Additional Metadata
    let responseCategory: ResponseCategory
    let emotionalTone: EmotionalTone
    let suggestedFollowups: [String]
    let processingMetrics: ProcessingMetrics
    let metadata: [String: Any]
    
    // MARK: - Initialization
    init(
        generatedText: String,
        confidence: Double,
        responseCategory: ResponseCategory = .general,
        emotionalTone: EmotionalTone = .neutral,
        suggestedFollowups: [String] = [],
        processingMetrics: ProcessingMetrics = ProcessingMetrics(),
        metadata: [String: Any] = [:]
    ) {
        self.generatedText = generatedText
        self.confidence = confidence
        self.responseCategory = responseCategory
        self.emotionalTone = emotionalTone
        self.suggestedFollowups = suggestedFollowups
        self.processingMetrics = processingMetrics
        self.metadata = metadata
    }
    
    // MARK: - MLFeatureProvider Protocol
    
    var featureNames: Set<String> {
        return Set([
            "generated_text", "confidence", "response_category", "emotional_tone",
            "suggested_followups", "processing_time", "model_version"
        ])
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "generated_text":
            return MLFeatureValue(string: generatedText)
        case "confidence":
            return MLFeatureValue(double: confidence)
        case "response_category":
            return MLFeatureValue(string: responseCategory.rawValue)
        case "emotional_tone":
            return MLFeatureValue(string: emotionalTone.rawValue)
        case "suggested_followups":
            // MLFeatureValue doesn't support string arrays directly, use multiArray
            return nil
        case "processing_time":
            return MLFeatureValue(double: processingMetrics.processingTime)
        case "model_version":
            return MLFeatureValue(string: processingMetrics.modelVersion)
        default:
            return nil
        }
    }
    
    /// Creates output from Core ML feature provider
    static func from(featureProvider: MLFeatureProvider) -> ResponseGenerationOutput? {
        // Extract primary response
        guard let generatedText = featureProvider.featureValue(for: "generated_text")?.stringValue,
              let confidence = featureProvider.featureValue(for: "confidence")?.doubleValue else {
            return nil
        }
        
        // Extract optional metadata
        let categoryString = featureProvider.featureValue(for: "response_category")?.stringValue ?? "general"
        let responseCategory = ResponseCategory(rawValue: categoryString) ?? .general
        
        let toneString = featureProvider.featureValue(for: "emotional_tone")?.stringValue ?? "neutral"
        let emotionalTone = EmotionalTone(rawValue: toneString) ?? .neutral
        
        // Extract followup suggestions
        let followupsString = featureProvider.featureValue(for: "suggested_followups")?.stringValue ?? ""
        let suggestedFollowups = followupsString.isEmpty ? [] : 
            followupsString.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Extract processing metrics
        let processingTime = featureProvider.featureValue(for: "processing_time_ms")?.doubleValue ?? 0.0
        let tokensGenerated = featureProvider.featureValue(for: "tokens_generated")?.int64Value ?? 0
        let temperatureUsed = featureProvider.featureValue(for: "temperature_used")?.doubleValue ?? 0.5
        
        let processingMetrics = ProcessingMetrics(
            processingTimeMs: processingTime,
            tokensGenerated: Int(tokensGenerated),
            temperatureUsed: temperatureUsed
        )
        
        // Collect all additional metadata
        var metadata: [String: Any] = [:]
        metadata["responseType"] = responseCategory.rawValue
        metadata["emotionalTone"] = emotionalTone.rawValue
        metadata["tokenCount"] = generatedText.components(separatedBy: .whitespacesAndNewlines).count
        metadata["characterCount"] = generatedText.count
        metadata["hasQuestions"] = generatedText.contains("?")
        metadata["hasExclamations"] = generatedText.contains("!")
        metadata["sentenceCount"] = generatedText.components(separatedBy: CharacterSet(charactersIn: ".!?")).count
        
        return ResponseGenerationOutput(
            generatedText: generatedText,
            confidence: confidence,
            responseCategory: responseCategory,
            emotionalTone: emotionalTone,
            suggestedFollowups: suggestedFollowups,
            processingMetrics: processingMetrics,
            metadata: metadata
        )
    }
    
    // MARK: - Validation and Quality Checks
    
    /// Validates the generated response for quality and appropriateness
    var isValid: Bool {
        // Basic validation checks
        guard !generatedText.isEmpty,
              generatedText.count >= 3,
              generatedText.count <= 1000,
              confidence >= 0.0 && confidence <= 1.0 else {
            return false
        }
        
        // Content quality checks
        guard !containsInappropriateContent,
              !isGibberish,
              hasCompleteThoughts else {
            return false
        }
        
        return true
    }
    
    /// Checks if response contains inappropriate or harmful content
    private var containsInappropriateContent: Bool {
        let inappropriateWords = [
            "hate", "offensive", "inappropriate", "harmful", "dangerous",
            "illegal", "violent", "discriminatory"
        ]
        
        let lowercaseText = generatedText.lowercased()
        return inappropriateWords.contains { lowercaseText.contains($0) }
    }
    
    /// Checks if response appears to be gibberish or malformed
    private var isGibberish: Bool {
        let words = generatedText.components(separatedBy: .whitespacesAndNewlines)
        let validWords = words.filter { $0.count > 2 && $0.allSatisfy { $0.isLetter } }
        
        // If less than 50% of words appear valid, consider it gibberish
        return Double(validWords.count) / Double(words.count) < 0.5
    }
    
    /// Checks if response contains complete thoughts
    private var hasCompleteThoughts: Bool {
        let sentences = generatedText.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Must have at least one sentence with reasonable length
        return sentences.contains { $0.count >= 10 }
    }
    
    // MARK: - Response Analysis
    
    /// Analyzes the sentiment of the generated response
    var sentimentAnalysis: SentimentAnalysis {
        let positiveWords = ["great", "excellent", "perfect", "wonderful", "amazing", "fantastic", "good"]
        let negativeWords = ["sorry", "unfortunately", "error", "problem", "issue", "failed", "wrong"]
        
        let lowercaseText = generatedText.lowercased()
        let positiveCount = positiveWords.filter { lowercaseText.contains($0) }.count
        let negativeCount = negativeWords.filter { lowercaseText.contains($0) }.count
        
        let netSentiment = positiveCount - negativeCount
        
        let sentiment: Sentiment
        if netSentiment > 0 {
            sentiment = .positive
        } else if netSentiment < 0 {
            sentiment = .negative
        } else {
            sentiment = .neutral
        }
        
        let intensity = min(abs(netSentiment), 3) / 3.0 // Normalize to 0-1
        
        return SentimentAnalysis(sentiment: sentiment, intensity: intensity)
    }
    
    /// Estimates the reading difficulty/complexity of the response
    var complexityLevel: ComplexityLevel {
        let words = generatedText.components(separatedBy: .whitespacesAndNewlines)
        let avgWordLength = words.map { $0.count }.reduce(0, +) / max(words.count, 1)
        
        let sentences = generatedText.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let avgSentenceLength = words.count / max(sentences.count, 1)
        
        // Simple complexity scoring
        let complexityScore = Double(avgWordLength) * 0.3 + Double(avgSentenceLength) * 0.7
        
        if complexityScore < 8 {
            return .simple
        } else if complexityScore < 15 {
            return .moderate
        } else {
            return .complex
        }
    }
    
    /// Suggests improvements for the generated response
    var improvementSuggestions: [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []
        
        if confidence < 0.6 {
            suggestions.append(.lowConfidence)
        }
        
        if generatedText.count < 20 {
            suggestions.append(.tooShort)
        } else if generatedText.count > 300 {
            suggestions.append(.tooLong)
        }
        
        if !generatedText.contains(" ") {
            suggestions.append(.lacksDetail)
        }
        
        if complexityLevel == .complex {
            suggestions.append(.simplifyLanguage)
        }
        
        if suggestedFollowups.isEmpty && responseCategory != .error {
            suggestions.append(.addFollowups)
        }
        
        return suggestions
    }
}

// MARK: - Supporting Types

enum ResponseCategory: String, CaseIterable {
    case general = "general"
    case informational = "informational"
    case actionable = "actionable"
    case conversational = "conversational"
    case error = "error"
    case confirmation = "confirmation"
}

enum EmotionalTone: String, CaseIterable {
    case neutral = "neutral"
    case positive = "positive"
    case enthusiastic = "enthusiastic"
    case professional = "professional"
    case casual = "casual"
    case empathetic = "empathetic"
    case urgent = "urgent"
}

struct ProcessingMetrics {
    let processingTimeMs: Double
    let tokensGenerated: Int
    let temperatureUsed: Double
    let timestamp: Date
    
    init(
        processingTimeMs: Double = 0.0,
        tokensGenerated: Int = 0,
        temperatureUsed: Double = 0.5
    ) {
        self.processingTimeMs = processingTimeMs
        self.tokensGenerated = tokensGenerated
        self.temperatureUsed = temperatureUsed
        self.timestamp = Date()
    }
    
    var tokensPerSecond: Double {
        guard processingTimeMs > 0 else { return 0 }
        return Double(tokensGenerated) / (processingTimeMs / 1000.0)
    }
}

struct SentimentAnalysis {
    let sentiment: Sentiment
    let intensity: Double // 0.0 to 1.0
    
    var description: String {
        let intensityDesc = intensity > 0.7 ? "strong" : intensity > 0.3 ? "moderate" : "weak"
        return "\(intensityDesc) \(sentiment.rawValue)"
    }
}

enum Sentiment: String {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
}

enum ComplexityLevel: String {
    case simple = "simple"
    case moderate = "moderate"
    case complex = "complex"
    
    var description: String {
        switch self {
        case .simple: return "Easy to read and understand"
        case .moderate: return "Moderately complex language"
        case .complex: return "Complex language and structure"
        }
    }
}

enum ImprovementSuggestion: String, CaseIterable {
    case lowConfidence = "Consider regenerating - low confidence score"
    case tooShort = "Response could be more detailed"
    case tooLong = "Response could be more concise"
    case lacksDetail = "Consider adding more specific information"
    case simplifyLanguage = "Use simpler language for better accessibility"
    case addFollowups = "Consider adding follow-up suggestions"
    case improveClarity = "Response could be clearer"
    case addPersonality = "Response could be more personalized"
    
    var priority: Int {
        switch self {
        case .lowConfidence: return 1
        case .improveClarity: return 2
        case .simplifyLanguage: return 3
        case .lacksDetail: return 4
        case .tooShort, .tooLong: return 5
        case .addFollowups, .addPersonality: return 6
        }
    }
}