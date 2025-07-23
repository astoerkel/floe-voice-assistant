//
//  IntentClassifier.swift
//  VoiceAssistant
//
//  Created by Claude Code on 2025-07-22.
//  High-level intent classifier that coordinates with Core ML models and fallback processing
//

import Foundation
import CoreML
import Combine
import OSLog

// MARK: - Intent Classification Result
public struct IntentClassificationResult {
    let intent: VoiceIntent
    let confidence: Float
    let processingTime: TimeInterval
    let processingMethod: ClassificationMethod
    let alternativeIntents: [(VoiceIntent, Float)]
    let extractedEntities: [String: Any]
    let shouldRouteToServer: Bool
    let routingExplanation: String
}

// MARK: - Classification Method
public enum ClassificationMethod {
    case onDevice
    case rulesBased
    case hybrid
    case serverFallback
}

// MARK: - Intent Classification Configuration
public struct IntentClassificationConfig {
    var confidenceThreshold: Float
    let fallbackThreshold: Float
    let enableRulesBased: Bool
    let enableEntityExtraction: Bool
    let maxProcessingTime: TimeInterval
    let enableLogging: Bool
    
    public static let `default` = IntentClassificationConfig(
        confidenceThreshold: 0.7,
        fallbackThreshold: 0.5,
        enableRulesBased: true,
        enableEntityExtraction: true,
        maxProcessingTime: 2.0,
        enableLogging: true
    )
}

// MARK: - Intent Classification Error
public enum IntentClassificationError: Error, LocalizedError {
    case modelNotAvailable
    case processingTimeout
    case invalidInput
    case configurationError
    
    public var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "Intent classification model is not available"
        case .processingTimeout:
            return "Intent classification timed out"
        case .invalidInput:
            return "Invalid input for intent classification"
        case .configurationError:
            return "Intent classifier configuration error"
        }
    }
}

// MARK: - Intent Classifier
@MainActor
public class IntentClassifier: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isProcessing = false
    @Published public private(set) var lastResult: IntentClassificationResult?
    @Published public private(set) var statistics: ClassificationStatistics
    @Published public var config: IntentClassificationConfig {
        didSet { saveConfiguration() }
    }
    
    // MARK: - Private Properties
    private let coreMLManager = CoreMLManager.shared
    private let configManager = ModelConfigurationManager.shared
    private let logger = Logger(subsystem: "com.voiceassistant", category: "IntentClassifier")
    
    // Pattern matching for rule-based classification
    private let intentPatterns: [VoiceIntent: [String]] = [
        .calendar: [
            "schedule", "meeting", "calendar", "appointment", "book", "reserve",
            "when is", "what time", "agenda", "availability", "free time",
            "next meeting", "today's schedule", "tomorrow's meetings"
        ],
        .email: [
            "email", "mail", "send", "compose", "write", "check inbox",
            "unread", "reply", "forward", "delete", "search email"
        ],
        .task: [
            "task", "todo", "reminder", "note", "list", "create task",
            "add to list", "remind me", "don't forget", "mark complete",
            "finish task", "project"
        ],
        .weather: [
            "weather", "temperature", "forecast", "rain", "sunny", "cloudy",
            "hot", "cold", "humidity", "wind", "storm", "snow"
        ],
        .general: [
            "hello", "hi", "help", "what can you do", "how are you",
            "good morning", "good evening", "thanks", "thank you"
        ]
    ]
    
    // Entity extraction patterns
    private let entityPatterns: [String: NSRegularExpression] = {
        var patterns: [String: NSRegularExpression] = [:]
        
        do {
            // Date patterns
            patterns["date"] = try NSRegularExpression(
                pattern: "\\b(tomorrow|today|yesterday|next week|next month|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b",
                options: [.caseInsensitive]
            )
            
            // Time patterns
            patterns["time"] = try NSRegularExpression(
                pattern: "\\b(\\d{1,2}:\\d{2}\\s*(am|pm)?|\\d{1,2}\\s*(am|pm))\\b",
                options: [.caseInsensitive]
            )
            
            // Email patterns
            patterns["email"] = try NSRegularExpression(
                pattern: "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b",
                options: []
            )
            
            // Number patterns
            patterns["number"] = try NSRegularExpression(
                pattern: "\\b\\d+\\b",
                options: []
            )
        } catch {
            print("Failed to create entity patterns: \(error)")
        }
        
        return patterns
    }()
    
    // MARK: - Classification Statistics
    public struct ClassificationStatistics {
        var totalClassifications: Int = 0
        var onDeviceClassifications: Int = 0
        var rulesBasedClassifications: Int = 0
        var serverFallbackClassifications: Int = 0
        var averageConfidence: Float = 0.0
        var averageProcessingTime: TimeInterval = 0.0
        var intentDistribution: [VoiceIntent: Int] = [:]
        
        var onDevicePercentage: Float {
            guard totalClassifications > 0 else { return 0 }
            return Float(onDeviceClassifications) / Float(totalClassifications)
        }
        
        var rulesBasedPercentage: Float {
            guard totalClassifications > 0 else { return 0 }
            return Float(rulesBasedClassifications) / Float(totalClassifications)
        }
    }
    
    // MARK: - Initialization
    public init(config: IntentClassificationConfig = .default) {
        self.config = config
        self.statistics = ClassificationStatistics()
        
        loadConfiguration()
        loadStatistics()
    }
    
    // MARK: - Main Classification Interface
    public func classifyIntent(
        text: String,
        context: [String: Any]? = nil,
        previousIntent: VoiceIntent? = nil
    ) async throws -> IntentClassificationResult {
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw IntentClassificationError.invalidInput
        }
        
        isProcessing = true
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            isProcessing = false
        }
        
        if config.enableLogging {
            logger.info("Classifying intent for text: '\(text.prefix(50))'")
        }
        
        do {
            let result = try await performClassification(
                text: text,
                context: context,
                previousIntent: previousIntent,
                startTime: startTime
            )
            
            lastResult = result
            updateStatistics(result)
            
            if config.enableLogging {
                logger.info("Intent classified as '\(result.intent.rawValue)' with confidence \(result.confidence)")
            }
            
            return result
            
        } catch {
            logger.error("Intent classification failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Classification Methods
    private func performClassification(
        text: String,
        context: [String: Any]?,
        previousIntent: VoiceIntent?,
        startTime: CFAbsoluteTime
    ) async throws -> IntentClassificationResult {
        
        let timeout = config.maxProcessingTime
        
        return try await withThrowingTaskGroup(of: IntentClassificationResult.self) { group in
            
            // Try Core ML model first
            group.addTask {
                try await self.classifyWithCoreML(
                    text: text,
                    context: context,
                    previousIntent: previousIntent,
                    startTime: startTime
                )
            }
            
            // Fallback to rules-based classification
            if config.enableRulesBased {
                group.addTask {
                    try await self.classifyWithRules(
                        text: text,
                        context: context,
                        previousIntent: previousIntent,
                        startTime: startTime
                    )
                }
            }
            
            // Wait for first successful result with timeout
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw IntentClassificationError.processingTimeout
            }
            
            defer { timeoutTask.cancel() }
            
            for try await result in group {
                timeoutTask.cancel()
                group.cancelAll()
                return result
            }
            
            throw IntentClassificationError.modelNotAvailable
        }
    }
    
    private func classifyWithCoreML(
        text: String,
        context: [String: Any]?,
        previousIntent: VoiceIntent?,
        startTime: CFAbsoluteTime
    ) async throws -> IntentClassificationResult {
        
        do {
            let model = try await coreMLManager.getIntentClassificationModel()
            
            let input = IntentClassificationInput(
                text: text,
                context: context,
                previousIntent: previousIntent
            )
            
            let output: IntentClassificationOutput = try await model.predict(input: input)
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            
            let shouldRouteToServer = output.confidence < config.confidenceThreshold
            let routingExplanation = shouldRouteToServer 
                ? "Low confidence (\(output.confidence)) - routing to server for better accuracy"
                : "High confidence (\(output.confidence)) - processing on device"
            
            return IntentClassificationResult(
                intent: output.intent,
                confidence: output.confidence,
                processingTime: processingTime,
                processingMethod: .onDevice,
                alternativeIntents: output.alternativeIntents,
                extractedEntities: output.extractedEntities,
                shouldRouteToServer: shouldRouteToServer,
                routingExplanation: routingExplanation
            )
            
        } catch {
            if config.enableLogging {
                logger.warning("Core ML classification failed: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    private func classifyWithRules(
        text: String,
        context: [String: Any]?,
        previousIntent: VoiceIntent?,
        startTime: CFAbsoluteTime
    ) async throws -> IntentClassificationResult {
        
        let lowercasedText = text.lowercased()
        var bestMatch: VoiceIntent = .general
        var bestScore: Float = 0.0
        var matchedPatterns: [String] = []
        
        // Pattern matching with scoring
        for (intent, patterns) in intentPatterns {
            var score: Float = 0.0
            var currentPatterns: [String] = []
            
            for pattern in patterns {
                if lowercasedText.contains(pattern.lowercased()) {
                    let patternScore = Float(pattern.count) / Float(text.count)
                    score += patternScore
                    currentPatterns.append(pattern)
                }
            }
            
            // Boost score if matches previous intent (conversation context)
            if let previousIntent = previousIntent, intent == previousIntent {
                score *= 1.2
            }
            
            // Apply context boost
            if let context = context {
                score += calculateContextBoost(for: intent, context: context)
            }
            
            if score > bestScore {
                bestScore = score
                bestMatch = intent
                matchedPatterns = currentPatterns
            }
        }
        
        // Fallback to unknown if no good matches
        if bestScore < 0.1 {
            bestMatch = .unknown
            bestScore = 0.3
        }
        
        // Normalize confidence score
        let confidence = min(max(bestScore, 0.0), 1.0)
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Generate alternative intents
        let alternatives = generateAlternatives(
            text: text,
            excludingPrimary: bestMatch,
            patterns: intentPatterns
        )
        
        // Extract entities
        let entities = config.enableEntityExtraction 
            ? extractEntities(from: text) 
            : [:]
        
        let shouldRouteToServer = confidence < config.fallbackThreshold
        let routingExplanation = shouldRouteToServer
            ? "Rules-based confidence too low (\(confidence)) - routing to server"
            : "Rules-based classification successful (\(confidence)) - matched patterns: \(matchedPatterns.joined(separator: ", "))"
        
        return IntentClassificationResult(
            intent: bestMatch,
            confidence: confidence,
            processingTime: processingTime,
            processingMethod: .rulesBased,
            alternativeIntents: alternatives,
            extractedEntities: entities,
            shouldRouteToServer: shouldRouteToServer,
            routingExplanation: routingExplanation
        )
    }
    
    // MARK: - Helper Methods
    private func calculateContextBoost(for intent: VoiceIntent, context: [String: Any]) -> Float {
        var boost: Float = 0.0
        
        // Time-based context
        if let timeContext = context["timeOfDay"] as? String {
            switch (intent, timeContext) {
            case (.calendar, "morning"), (.email, "morning"):
                boost += 0.1
            case (.weather, "morning"):
                boost += 0.05
            default:
                break
            }
        }
        
        // Location-based context
        if let location = context["location"] as? String {
            switch (intent, location) {
            case (.weather, "outdoors"):
                boost += 0.1
            case (.calendar, "office"):
                boost += 0.05
            default:
                break
            }
        }
        
        // Previous app context
        if let lastApp = context["lastUsedApp"] as? String {
            switch (intent, lastApp) {
            case (.email, "Mail"):
                boost += 0.15
            case (.calendar, "Calendar"):
                boost += 0.15
            case (.task, "Reminders"):
                boost += 0.15
            default:
                break
            }
        }
        
        return boost
    }
    
    private func generateAlternatives(
        text: String,
        excludingPrimary: VoiceIntent,
        patterns: [VoiceIntent: [String]]
    ) -> [(VoiceIntent, Float)] {
        
        let lowercasedText = text.lowercased()
        var alternatives: [(VoiceIntent, Float)] = []
        
        for (intent, intentPatterns) in patterns {
            guard intent != excludingPrimary && intent != .unknown else { continue }
            
            var score: Float = 0.0
            for pattern in intentPatterns {
                if lowercasedText.contains(pattern.lowercased()) {
                    score += 0.1
                }
            }
            
            if score > 0 {
                alternatives.append((intent, min(score, 0.8))) // Cap alternative confidence
            }
        }
        
        // Sort by confidence and return top 3
        return alternatives
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { ($0.0, $0.1) }
    }
    
    private func extractEntities(from text: String) -> [String: Any] {
        var entities: [String: Any] = [:]
        
        for (entityType, pattern) in entityPatterns {
            let matches = pattern.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            
            if !matches.isEmpty {
                let extractedValues = matches.compactMap { match in
                    String(text[Range(match.range, in: text)!])
                }
                entities[entityType] = extractedValues
            }
        }
        
        return entities
    }
    
    // MARK: - Statistics & Configuration Management
    private func updateStatistics(_ result: IntentClassificationResult) {
        statistics.totalClassifications += 1
        
        switch result.processingMethod {
        case .onDevice:
            statistics.onDeviceClassifications += 1
        case .rulesBased:
            statistics.rulesBasedClassifications += 1
        case .serverFallback:
            statistics.serverFallbackClassifications += 1
        case .hybrid:
            break
        }
        
        // Update rolling averages
        let n = Float(statistics.totalClassifications)
        statistics.averageConfidence = ((statistics.averageConfidence * (n - 1)) + result.confidence) / n
        statistics.averageProcessingTime = ((statistics.averageProcessingTime * Double(n - 1)) + result.processingTime) / Double(n)
        
        // Update intent distribution
        statistics.intentDistribution[result.intent, default: 0] += 1
        
        saveStatistics()
    }
    
    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "IntentClassificationConfig")
        }
    }
    
    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "IntentClassificationConfig"),
           let loadedConfig = try? JSONDecoder().decode(IntentClassificationConfig.self, from: data) {
            config = loadedConfig
        }
    }
    
    private func saveStatistics() {
        if let data = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(data, forKey: "IntentClassificationStatistics")
        }
    }
    
    private func loadStatistics() {
        if let data = UserDefaults.standard.data(forKey: "IntentClassificationStatistics"),
           let loadedStats = try? JSONDecoder().decode(ClassificationStatistics.self, from: data) {
            statistics = loadedStats
        }
    }
    
    // MARK: - Public Utility Methods
    public func getStatistics() -> ClassificationStatistics {
        return statistics
    }
    
    public func resetStatistics() {
        statistics = ClassificationStatistics()
        saveStatistics()
    }
    
    public func getSupportedIntents() -> [VoiceIntent] {
        return Array(intentPatterns.keys)
    }
    
    public func getIntentExamples(for intent: VoiceIntent) -> [String] {
        return intentPatterns[intent] ?? []
    }
    
    public func updateConfidenceThreshold(_ threshold: Float) {
        var newConfig = config
        newConfig.confidenceThreshold = max(0.1, min(1.0, threshold))
        config = newConfig
    }
}

// MARK: - Codable Conformance
extension IntentClassifier.ClassificationStatistics: Codable {}
extension IntentClassificationConfig: Codable {}