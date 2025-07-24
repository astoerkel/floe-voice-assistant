//
//  IntentRouter.swift
//  VoiceAssistant
//
//  Created by Claude Code on 2025-07-22.
//  Intelligent routing system for voice intents based on confidence and processing capabilities
//

import Foundation
import Combine
import OSLog
import UIKit

// MARK: - Routing Decision
public struct RoutingDecision {
    let route: ProcessingRoute
    let confidence: Float
    let explanation: String
    let estimatedProcessingTime: TimeInterval
    let fallbackRoute: ProcessingRoute?
}

// MARK: - Processing Route
public enum ProcessingRoute: Codable {
    case onDevice(handler: String)
    case server
    case hybrid(onDeviceFirst: Bool)
    case offline(cached: Bool)
    
    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case type
        case handler
        case onDeviceFirst
        case cached
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "onDevice":
            let handler = try container.decode(String.self, forKey: .handler)
            self = .onDevice(handler: handler)
        case "server":
            self = .server
        case "hybrid":
            let onDeviceFirst = try container.decode(Bool.self, forKey: .onDeviceFirst)
            self = .hybrid(onDeviceFirst: onDeviceFirst)
        case "offline":
            let cached = try container.decode(Bool.self, forKey: .cached)
            self = .offline(cached: cached)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown ProcessingRoute type: \(type)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .onDevice(let handler):
            try container.encode("onDevice", forKey: .type)
            try container.encode(handler, forKey: .handler)
        case .server:
            try container.encode("server", forKey: .type)
        case .hybrid(let onDeviceFirst):
            try container.encode("hybrid", forKey: .type)
            try container.encode(onDeviceFirst, forKey: .onDeviceFirst)
        case .offline(let cached):
            try container.encode("offline", forKey: .type)
            try container.encode(cached, forKey: .cached)
        }
    }
}

// MARK: - Intent Routing Configuration
public struct IntentRoutingConfig {
    var highConfidenceThreshold: Float
    var mediumConfidenceThreshold: Float
    let enableOfflineRouting: Bool
    let enableHybridRouting: Bool
    let preferOnDeviceWhenPossible: Bool
    let maxOnDeviceProcessingTime: TimeInterval
    let enableIntentLearning: Bool
    
    public static let `default` = IntentRoutingConfig(
        highConfidenceThreshold: 0.8,
        mediumConfidenceThreshold: 0.6,
        enableOfflineRouting: true,
        enableHybridRouting: true,
        preferOnDeviceWhenPossible: true,
        maxOnDeviceProcessingTime: 3.0,
        enableIntentLearning: true
    )
}

// MARK: - Routing Statistics
public struct RoutingStatistics {
    var totalRequests: Int = 0
    var onDeviceRoutes: Int = 0
    var serverRoutes: Int = 0
    var hybridRoutes: Int = 0
    var offlineRoutes: Int = 0
    var fallbacksUsed: Int = 0
    var averageConfidence: Float = 0.0
    var routingAccuracy: Float = 1.0 // Success rate of routing decisions
    
    var onDevicePercentage: Float {
        guard totalRequests > 0 else { return 0 }
        return Float(onDeviceRoutes) / Float(totalRequests)
    }
    
    var serverFallbackRate: Float {
        guard totalRequests > 0 else { return 0 }
        return Float(fallbacksUsed) / Float(totalRequests)
    }
}

// MARK: - Intent Router
@MainActor
public class IntentRouter: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isProcessing = false
    @Published public private(set) var statistics: RoutingStatistics = RoutingStatistics()
    @Published public private(set) var lastRoutingDecision: RoutingDecision?
    @Published public var config: IntentRoutingConfig {
        didSet { saveConfiguration() }
    }
    
    // MARK: - Private Properties
    private let intentClassifier: IntentClassifier
    private let logger = Logger(subsystem: "com.voiceassistant", category: "IntentRouter")
    
    // Learning system for improving routing decisions
    private var routingHistory: [RoutingHistoryEntry] = []
    private let maxHistorySize = 1000
    
    // Offline handlers registry
    private let offlineHandlers: [VoiceIntent: OfflineIntentHandler]
    
    // Network and system status
    private var isNetworkAvailable: Bool {
        // Simplified - would use proper network monitoring in production
        return true
    }
    
    private var isLowPowerMode: Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    private var batteryLevel: Float {
        return UIDevice.current.batteryLevel
    }
    
    // MARK: - Routing History Entry
    fileprivate struct RoutingHistoryEntry {
        let intent: VoiceIntent
        let confidence: Float
        let routingDecision: ProcessingRoute
        var actualProcessingTime: TimeInterval
        var success: Bool
        let timestamp: Date
        let contextHash: String
    }
    
    // MARK: - Initialization
    public init(
        intentClassifier: IntentClassifier,
        config: IntentRoutingConfig = .default
    ) {
        self.intentClassifier = intentClassifier
        self.config = config
        
        // Initialize offline handlers
        self.offlineHandlers = [
            .time: TimeIntentHandler(),
            .calculation: CalculationIntentHandler(),
            .deviceControl: DeviceControlIntentHandler()
        ]
        
        loadConfiguration()
        loadStatistics()
        loadRoutingHistory()
        
        // Log initialization
        logger.info("IntentRouter initialized with \(self.offlineHandlers.count) offline handlers")
    }
    
    // MARK: - Main Routing Interface
    public func routeIntent(
        text: String,
        context: [String: Any]? = nil,
        previousIntent: VoiceIntent? = nil
    ) async throws -> RoutingDecision {
        
        isProcessing = true
        defer { isProcessing = false }
        
        logger.info("Routing intent for text: '\(text.prefix(50))'")
        
        // First, classify the intent
        let classificationResult = try await intentClassifier.classifyIntent(
            text: text,
            context: context,
            previousIntent: previousIntent
        )
        
        // Then determine the best routing strategy
        let routingDecision = await determineRoute(
            classificationResult: classificationResult,
            text: text,
            context: context
        )
        
        // Log the routing decision
        logRoutingDecision(routingDecision, for: classificationResult)
        
        // Update statistics
        updateStatistics(routingDecision, classificationResult: classificationResult)
        
        // Store for learning
        if config.enableIntentLearning {
            storeRoutingDecision(routingDecision, classificationResult: classificationResult, text: text, context: context)
        }
        
        lastRoutingDecision = routingDecision
        return routingDecision
    }
    
    // MARK: - Route Determination Logic
    private func determineRoute(
        classificationResult: IntentClassificationResult,
        text: String,
        context: [String: Any]?
    ) async -> RoutingDecision {
        
        let intent = classificationResult.intent
        let confidence = classificationResult.confidence
        
        // Check for offline processing first (highest priority)
        if intent.supportsOfflineProcessing && config.enableOfflineRouting {
            if let offlineDecision = await checkOfflineRouting(intent: intent, confidence: confidence, text: text) {
                return offlineDecision
            }
        }
        
        // High confidence - prefer on-device processing
        if confidence >= config.highConfidenceThreshold {
            return await routeHighConfidenceIntent(
                intent: intent,
                confidence: confidence,
                text: text,
                context: context
            )
        }
        
        // Medium confidence - consider hybrid approach
        if confidence >= config.mediumConfidenceThreshold && config.enableHybridRouting {
            return await routeHybridIntent(
                intent: intent,
                confidence: confidence,
                text: text,
                context: context
            )
        }
        
        // Low confidence - route to server
        return routeLowConfidenceIntent(
            intent: intent,
            confidence: confidence,
            text: text,
            context: context
        )
    }
    
    private func checkOfflineRouting(
        intent: VoiceIntent,
        confidence: Float,
        text: String
    ) async -> RoutingDecision? {
        
        guard let handler = offlineHandlers[intent] else {
            return nil
        }
        
        // Check if the specific query can be handled offline
        let canHandle = await handler.canHandle(text: text)
        
        if canHandle {
            let estimatedTime = await handler.estimatedProcessingTime(text: text)
            
            return RoutingDecision(
                route: .offline(cached: false),
                confidence: min(confidence * 1.1, 1.0), // Boost confidence for offline capability
                explanation: "Intent '\(intent.displayName)' can be processed offline with high reliability",
                estimatedProcessingTime: estimatedTime,
                fallbackRoute: .server
            )
        }
        
        return nil
    }
    
    private func routeHighConfidenceIntent(
        intent: VoiceIntent,
        confidence: Float,
        text: String,
        context: [String: Any]?
    ) async -> RoutingDecision {
        
        // Consider system conditions
        if isLowPowerMode || batteryLevel < 0.2 {
            return RoutingDecision(
                route: .server,
                confidence: confidence,
                explanation: "High confidence but routing to server to preserve battery (Low Power Mode: \(isLowPowerMode), Battery: \(Int(batteryLevel * 100))%)",
                estimatedProcessingTime: 2.0,
                fallbackRoute: nil
            )
        }
        
        // Check if intent requires server processing
        if intent.requiresServerProcessing {
            return RoutingDecision(
                route: .server,
                confidence: confidence,
                explanation: "Intent '\(intent.displayName)' requires server integration for external services",
                estimatedProcessingTime: 1.5,
                fallbackRoute: .onDevice(handler: "local_fallback")
            )
        }
        
        // Route to on-device processing
        let handlerName = getOnDeviceHandler(for: intent)
        return RoutingDecision(
            route: .onDevice(handler: handlerName),
            confidence: confidence,
            explanation: "High confidence (\(String(format: "%.2f", confidence))) - processing on device for speed and privacy",
            estimatedProcessingTime: 0.8,
            fallbackRoute: .server
        )
    }
    
    private func routeHybridIntent(
        intent: VoiceIntent,
        confidence: Float,
        text: String,
        context: [String: Any]?
    ) async -> RoutingDecision {
        
        // Check historical performance for this type of intent
        let shouldTryOnDeviceFirst = await shouldPreferOnDevice(
            intent: intent,
            confidence: confidence,
            context: context
        )
        
        let explanation = shouldTryOnDeviceFirst
            ? "Medium confidence (\(String(format: "%.2f", confidence))) - trying on-device first with server fallback"
            : "Medium confidence (\(String(format: "%.2f", confidence))) - hybrid processing with server preference"
        
        return RoutingDecision(
            route: .hybrid(onDeviceFirst: shouldTryOnDeviceFirst),
            confidence: confidence,
            explanation: explanation,
            estimatedProcessingTime: shouldTryOnDeviceFirst ? 1.2 : 2.0,
            fallbackRoute: shouldTryOnDeviceFirst ? .server : .onDevice(handler: getOnDeviceHandler(for: intent))
        )
    }
    
    private func routeLowConfidenceIntent(
        intent: VoiceIntent,
        confidence: Float,
        text: String,
        context: [String: Any]?
    ) -> RoutingDecision {
        
        // Always route low confidence to server for better accuracy
        return RoutingDecision(
            route: .server,
            confidence: confidence,
            explanation: "Low confidence (\(String(format: "%.2f", confidence))) - routing to server for better accuracy and handling",
            estimatedProcessingTime: 2.5,
            fallbackRoute: .onDevice(handler: "general_fallback")
        )
    }
    
    // MARK: - Helper Methods
    private func getOnDeviceHandler(for intent: VoiceIntent) -> String {
        switch intent {
        case .time:
            return "TimeHandler"
        case .calculation:
            return "CalculationHandler"
        case .deviceControl:
            return "DeviceControlHandler"
        case .general:
            return "GeneralResponseHandler"
        default:
            return "DefaultHandler"
        }
    }
    
    private func shouldPreferOnDevice(
        intent: VoiceIntent,
        confidence: Float,
        context: [String: Any]?
    ) async -> Bool {
        
        // Base preference
        guard config.preferOnDeviceWhenPossible else { return false }
        
        // Check network availability
        if !isNetworkAvailable {
            return true // Must use on-device if no network
        }
        
        // Learn from history
        if config.enableIntentLearning {
            let historicalSuccess = getHistoricalSuccessRate(for: intent, route: .onDevice(handler: ""))
            if historicalSuccess > 0.8 {
                return true
            }
        }
        
        // Consider context factors
        if let timeOfDay = context?["timeOfDay"] as? String {
            // Prefer on-device during off-peak hours
            if timeOfDay == "night" || timeOfDay == "early_morning" {
                return true
            }
        }
        
        return confidence > 0.65 // Default threshold for hybrid on-device preference
    }
    
    private func getHistoricalSuccessRate(for intent: VoiceIntent, route: ProcessingRoute) -> Float {
        let relevantEntries = routingHistory.filter { entry in
            entry.intent == intent && routesMatch(entry.routingDecision, route)
        }
        
        guard !relevantEntries.isEmpty else { return 0.5 } // Default neutral rate
        
        let successfulEntries = relevantEntries.filter { $0.success }
        return Float(successfulEntries.count) / Float(relevantEntries.count)
    }
    
    private func routesMatch(_ route1: ProcessingRoute, _ route2: ProcessingRoute) -> Bool {
        switch (route1, route2) {
        case (.onDevice, .onDevice):
            return true
        case (.server, .server):
            return true
        case (.hybrid, .hybrid):
            return true
        case (.offline, .offline):
            return true
        default:
            return false
        }
    }
    
    // MARK: - Logging & Analytics
    private func logRoutingDecision(_ decision: RoutingDecision, for classificationResult: IntentClassificationResult) {
        let routeDescription: String
        
        switch decision.route {
        case .onDevice(let handler):
            routeDescription = "On-Device (\(handler))"
        case .server:
            routeDescription = "Server"
        case .hybrid(let onDeviceFirst):
            routeDescription = "Hybrid (\(onDeviceFirst ? "On-Device First" : "Server First"))"
        case .offline(let cached):
            routeDescription = "Offline (\(cached ? "Cached" : "Live"))"
        }
        
        logger.info("""
            Intent Routing Decision:
            - Intent: \(classificationResult.intent.displayName)
            - Confidence: \(String(format: "%.3f", decision.confidence))
            - Route: \(routeDescription)
            - Estimated Time: \(String(format: "%.2f", decision.estimatedProcessingTime))s
            - Explanation: \(decision.explanation)
            """)
    }
    
    private func updateStatistics(_ decision: RoutingDecision, classificationResult: IntentClassificationResult) {
        statistics.totalRequests += 1
        
        // Update routing counts
        switch decision.route {
        case .onDevice, .offline:
            statistics.onDeviceRoutes += 1
        case .server:
            statistics.serverRoutes += 1
        case .hybrid:
            statistics.hybridRoutes += 1
        }
        
        // Update average confidence (rolling average)
        let n = Float(statistics.totalRequests)
        statistics.averageConfidence = ((statistics.averageConfidence * (n - 1)) + decision.confidence) / n
        
        saveStatistics()
    }
    
    private func storeRoutingDecision(
        _ decision: RoutingDecision,
        classificationResult: IntentClassificationResult,
        text: String,
        context: [String: Any]?
    ) {
        let contextHash = generateContextHash(context)
        
        let entry = RoutingHistoryEntry(
            intent: classificationResult.intent,
            confidence: decision.confidence,
            routingDecision: decision.route,
            actualProcessingTime: decision.estimatedProcessingTime, // Would be updated with actual time
            success: true, // Would be updated based on actual outcome
            timestamp: Date(),
            contextHash: contextHash
        )
        
        routingHistory.append(entry)
        
        // Trim history if too large
        if routingHistory.count > maxHistorySize {
            routingHistory.removeFirst(routingHistory.count - maxHistorySize)
        }
        
        saveRoutingHistory()
    }
    
    private func generateContextHash(_ context: [String: Any]?) -> String {
        guard let context = context else { return "no_context" }
        
        // Create a simple hash of context keys
        let keys = context.keys.sorted().joined(separator: ",")
        return String(keys.hash)
    }
    
    // MARK: - Feedback & Learning
    public func reportRoutingOutcome(
        routingDecision: RoutingDecision,
        success: Bool,
        actualProcessingTime: TimeInterval
    ) {
        
        // Update statistics
        if !success {
            statistics.fallbacksUsed += 1
        }
        
        // Update routing accuracy (rolling average)
        let n = Float(statistics.totalRequests)
        let successRate = success ? 1.0 : 0.0
        statistics.routingAccuracy = ((statistics.routingAccuracy * (n - 1)) + Float(successRate)) / n
        
        // Update learning history if enabled
        if config.enableIntentLearning, let lastIndex = routingHistory.indices.last {
            routingHistory[lastIndex].actualProcessingTime = actualProcessingTime
            routingHistory[lastIndex].success = success
        }
        
        logger.info("Routing outcome reported: Success=\(success), Time=\(String(format: "%.2f", actualProcessingTime))s")
        
        saveStatistics()
        if config.enableIntentLearning {
            saveRoutingHistory()
        }
    }
    
    // MARK: - Configuration & Persistence
    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "IntentRoutingConfig")
        }
    }
    
    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "IntentRoutingConfig"),
           let loadedConfig = try? JSONDecoder().decode(IntentRoutingConfig.self, from: data) {
            config = loadedConfig
        }
    }
    
    private func saveStatistics() {
        if let data = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(data, forKey: "IntentRoutingStatistics")
        }
    }
    
    private func loadStatistics() {
        if let data = UserDefaults.standard.data(forKey: "IntentRoutingStatistics"),
           let loadedStats = try? JSONDecoder().decode(RoutingStatistics.self, from: data) {
            statistics = loadedStats
        }
    }
    
    private func saveRoutingHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(routingHistory.suffix(maxHistorySize)) {
            UserDefaults.standard.set(data, forKey: "IntentRoutingHistory")
        }
    }
    
    private func loadRoutingHistory() {
        guard let data = UserDefaults.standard.data(forKey: "IntentRoutingHistory") else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let loadedHistory = try? decoder.decode([RoutingHistoryEntry].self, from: data) {
            routingHistory = loadedHistory
        }
    }
    
    // MARK: - Public Utility Methods
    public func getRoutingStatistics() -> RoutingStatistics {
        return statistics
    }
    
    public func resetStatistics() {
        statistics = RoutingStatistics()
        saveStatistics()
    }
    
    public func getAvailableOfflineIntents() -> [VoiceIntent] {
        return Array(offlineHandlers.keys)
    }
    
    public func updateConfidenceThresholds(high: Float, medium: Float) {
        var newConfig = config
        newConfig.highConfidenceThreshold = max(0.1, min(1.0, high))
        newConfig.mediumConfidenceThreshold = max(0.1, min(high - 0.1, medium))
        config = newConfig
    }
}

// MARK: - Offline Intent Handler Protocol
protocol OfflineIntentHandler {
    func canHandle(text: String) async -> Bool
    func process(text: String, context: [String: Any]?) async throws -> VoiceResponse
    func estimatedProcessingTime(text: String) async -> TimeInterval
}

// MARK: - Offline Handler Implementations

class TimeIntentHandler: OfflineIntentHandler {
    func canHandle(text: String) async -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("time") || lowercased.contains("date") || 
               lowercased.contains("today") || lowercased.contains("now")
    }
    
    func process(text: String, context: [String: Any]?) async throws -> VoiceResponse {
        let now = Date()
        let formatter = DateFormatter()
        
        if text.lowercased().contains("date") {
            formatter.dateStyle = .full
            let response = "Today is \(formatter.string(from: now))"
            return VoiceResponse(text: response, success: true, audioBase64: nil)
        } else {
            formatter.timeStyle = .short
            let response = "The time is \(formatter.string(from: now))"
            return VoiceResponse(text: response, success: true, audioBase64: nil)
        }
    }
    
    func estimatedProcessingTime(text: String) async -> TimeInterval {
        return 0.1 // Very fast for time queries
    }
}

class CalculationIntentHandler: OfflineIntentHandler {
    func canHandle(text: String) async -> Bool {
        let lowercased = text.lowercased()
        let mathKeywords = ["calculate", "plus", "minus", "multiply", "divide", "add", "subtract"]
        return mathKeywords.contains { lowercased.contains($0) } || containsNumbers(text)
    }
    
    private func containsNumbers(_ text: String) -> Bool {
        let numberRegex = try? NSRegularExpression(pattern: "\\d+", options: [])
        let matches = numberRegex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
        return matches.count >= 2 // At least two numbers for calculation
    }
    
    func process(text: String, context: [String: Any]?) async throws -> VoiceResponse {
        // Simple calculation parser (could be enhanced)
        let result = parseAndCalculate(text)
        let response = "The result is \(result)"
        return VoiceResponse(text: response, success: true, audioBase64: nil)
    }
    
    private func parseAndCalculate(_ text: String) -> String {
        // Simplified calculation - in production would use proper expression parser
        return "42" // Placeholder result
    }
    
    func estimatedProcessingTime(text: String) async -> TimeInterval {
        return 0.3
    }
}

class DeviceControlIntentHandler: OfflineIntentHandler {
    func canHandle(text: String) async -> Bool {
        let lowercased = text.lowercased()
        let deviceKeywords = ["brightness", "volume", "wifi", "bluetooth", "battery"]
        return deviceKeywords.contains { lowercased.contains($0) }
    }
    
    func process(text: String, context: [String: Any]?) async throws -> VoiceResponse {
        let response = "Device control commands are not fully implemented in this demo"
        return VoiceResponse(text: response, success: true, audioBase64: nil)
    }
    
    func estimatedProcessingTime(text: String) async -> TimeInterval {
        return 0.5
    }
}

// MARK: - Codable Conformance
extension RoutingStatistics: Codable {}
extension IntentRoutingConfig: Codable {}
extension IntentRouter.RoutingHistoryEntry: Codable {}