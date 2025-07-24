//
//  EnhancedVoiceProcessor.swift
//  VoiceAssistant
//
//  Created by Claude Code on 2025-07-22.
//  Enhanced voice processor that integrates intent classification and routing
//

import Foundation
import AVFoundation
import UIKit
import Combine
import OSLog

// MARK: - Voice Processing Context
public struct VoiceProcessingContext {
    let timeOfDay: String
    let location: String?
    let previousIntent: VoiceIntent?
    let conversationHistory: [ConversationMessage]
    let userPreferences: [String: Any]
    let deviceState: DeviceState
    
    public init(timeOfDay: String, location: String?, previousIntent: VoiceIntent?, conversationHistory: [ConversationMessage], userPreferences: [String: Any], deviceState: DeviceState) {
        self.timeOfDay = timeOfDay
        self.location = location
        self.previousIntent = previousIntent
        self.conversationHistory = conversationHistory
        self.userPreferences = userPreferences
        self.deviceState = deviceState
    }
}

// MARK: - Device State
public struct DeviceState {
    let batteryLevel: Float
    let isLowPowerMode: Bool
    let isNetworkAvailable: Bool
    let isWifiConnected: Bool
    let memoryUsage: Float
    
    public init(batteryLevel: Float, isLowPowerMode: Bool, isNetworkAvailable: Bool, isWifiConnected: Bool, memoryUsage: Float) {
        self.batteryLevel = batteryLevel
        self.isLowPowerMode = isLowPowerMode
        self.isNetworkAvailable = isNetworkAvailable
        self.isWifiConnected = isWifiConnected
        self.memoryUsage = memoryUsage
    }
}

// MARK: - Enhanced Voice Processing Result
public struct EnhancedVoiceProcessingResult {
    let response: VoiceResponse
    let intent: VoiceIntent
    let confidence: Float
    let processingMethod: ProcessingMethod
    let processingTime: TimeInterval
    let routingExplanation: String
    let wasProcessedOffline: Bool
    let followUpSuggestions: [String]
}

// MARK: - Enhanced Voice Processor
@MainActor
public class EnhancedVoiceProcessor: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isProcessing = false
    @Published public private(set) var currentProcessingStep: ProcessingStep = .idle
    @Published public private(set) var lastProcessingResult: EnhancedVoiceProcessingResult?
    @Published public private(set) var processingStatistics: ProcessingStatistics
    @Published public var enableOfflineFirst = true
    @Published public var confidenceThreshold: Float = 0.7
    
    // MARK: - Processing Steps
    public enum ProcessingStep {
        case idle
        case transcribing
        case classifyingIntent
        case routingDecision
        case processingOnDevice
        case processingOnServer
        case generatingResponse
        case completed
        case error(String)
    }
    
    // MARK: - Processing Statistics
    public struct ProcessingStatistics {
        var totalProcessed: Int = 0
        var onDeviceProcessed: Int = 0
        var serverProcessed: Int = 0
        var offlineProcessed: Int = 0
        var averageProcessingTime: TimeInterval = 0.0
        var averageConfidence: Float = 0.0
        var intentAccuracy: Float = 1.0
        
        var offlineSuccessRate: Float {
            guard totalProcessed > 0 else { return 0 }
            return Float(offlineProcessed) / Float(totalProcessed)
        }
    }
    
    // MARK: - Dependencies
    private let intentClassifier: IntentClassifier
    private let intentRouter: IntentRouter
    private let speechRecognizer: SpeechRecognizer
    private let apiClient: APIClient
    private let offlineHandlers: [VoiceIntent: OfflineIntentHandler]
    private let logger = Logger(subsystem: "com.voiceassistant", category: "EnhancedVoiceProcessor")
    
    // User preferences
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Initialization
    public init(
        speechRecognizer: SpeechRecognizer,
        apiClient: APIClient
    ) {
        self.speechRecognizer = speechRecognizer
        self.apiClient = apiClient
        self.intentClassifier = IntentClassifier()
        self.intentRouter = IntentRouter(intentClassifier: intentClassifier)
        self.offlineHandlers = OfflineHandlerFactory.createHandlers()
        self.processingStatistics = ProcessingStatistics()
        
        loadProcessingSettings()
        loadStatistics()
        
        logger.info("EnhancedVoiceProcessor initialized with \(self.offlineHandlers.count) offline handlers")
    }
    
    // MARK: - Main Processing Interface
    public func processVoiceCommand(
        audioData: Data,
        context: VoiceProcessingContext
    ) async throws -> EnhancedVoiceProcessingResult {
        
        isProcessing = true
        currentProcessingStep = .transcribing
        let processingStartTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            isProcessing = false
            currentProcessingStep = .idle
        }
        
        logger.info("Starting voice command processing")
        
        do {
            // Step 1: Transcribe audio to text
            let transcriptionText = try await transcribeAudio(audioData)
            logger.info("Transcription completed: '\(transcriptionText.prefix(50))'")
            
            // Step 2: Classify intent
            currentProcessingStep = .classifyingIntent
            let classificationResult = try await classifyIntent(
                text: transcriptionText,
                context: context
            )
            logger.info("Intent classified as '\(classificationResult.intent.displayName)' with confidence \(classificationResult.confidence)")
            
            // Step 3: Route based on confidence and capabilities
            currentProcessingStep = .routingDecision
            let routingDecision = try await routeIntent(
                classificationResult: classificationResult,
                context: context,
                originalText: transcriptionText
            )
            logger.info("Routing decision: \(routingDecision.explanation)")
            
            // Step 4: Process based on routing decision
            let processingResult = try await executeProcessing(
                routingDecision: routingDecision,
                classificationResult: classificationResult,
                originalText: transcriptionText,
                context: context
            )
            
            currentProcessingStep = .completed
            let totalProcessingTime = CFAbsoluteTimeGetCurrent() - processingStartTime
            
            // Create final result
            let finalResult = EnhancedVoiceProcessingResult(
                response: processingResult.response,
                intent: classificationResult.intent,
                confidence: classificationResult.confidence,
                processingMethod: processingResult.method,
                processingTime: totalProcessingTime,
                routingExplanation: routingDecision.explanation,
                wasProcessedOffline: processingResult.wasOffline,
                followUpSuggestions: generateFollowUpSuggestions(
                    intent: classificationResult.intent,
                    response: processingResult.response
                )
            )
            
            // Update statistics and store result
            updateStatistics(finalResult)
            lastProcessingResult = finalResult
            
            logger.info("Voice processing completed in \(String(format: "%.2f", totalProcessingTime))s")
            return finalResult
            
        } catch {
            currentProcessingStep = .error(error.localizedDescription)
            logger.error("Voice processing failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Text-Only Processing (for direct text input)
    public func processTextCommand(
        text: String,
        context: VoiceProcessingContext
    ) async throws -> EnhancedVoiceProcessingResult {
        
        isProcessing = true
        currentProcessingStep = .classifyingIntent
        let processingStartTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            isProcessing = false
            currentProcessingStep = .idle
        }
        
        logger.info("Starting text command processing: '\(text.prefix(50))'")
        
        do {
            // Step 1: Classify intent
            let classificationResult = try await classifyIntent(
                text: text,
                context: context
            )
            
            // Step 2: Route based on confidence and capabilities
            currentProcessingStep = .routingDecision
            let routingDecision = try await routeIntent(
                classificationResult: classificationResult,
                context: context,
                originalText: text
            )
            
            // Step 3: Process based on routing decision
            let processingResult = try await executeProcessing(
                routingDecision: routingDecision,
                classificationResult: classificationResult,
                originalText: text,
                context: context
            )
            
            currentProcessingStep = .completed
            let totalProcessingTime = CFAbsoluteTimeGetCurrent() - processingStartTime
            
            let finalResult = EnhancedVoiceProcessingResult(
                response: processingResult.response,
                intent: classificationResult.intent,
                confidence: classificationResult.confidence,
                processingMethod: processingResult.method,
                processingTime: totalProcessingTime,
                routingExplanation: routingDecision.explanation,
                wasProcessedOffline: processingResult.wasOffline,
                followUpSuggestions: generateFollowUpSuggestions(
                    intent: classificationResult.intent,
                    response: processingResult.response
                )
            )
            
            updateStatistics(finalResult)
            lastProcessingResult = finalResult
            
            return finalResult
            
        } catch {
            currentProcessingStep = .error(error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Processing Steps Implementation
    private func transcribeAudio(_ audioData: Data) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            speechRecognizer.transcribe(audioData) { result in
                switch result {
                case .success(let transcription):
                    continuation.resume(returning: transcription)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func classifyIntent(
        text: String,
        context: VoiceProcessingContext
    ) async throws -> IntentClassificationResult {
        
        let intentContext: [String: Any] = [
            "timeOfDay": context.timeOfDay,
            "location": context.location ?? "",
            "batteryLevel": context.deviceState.batteryLevel,
            "isLowPowerMode": context.deviceState.isLowPowerMode,
            "isNetworkAvailable": context.deviceState.isNetworkAvailable
        ]
        
        return try await intentClassifier.classifyIntent(
            text: text,
            context: intentContext,
            previousIntent: context.previousIntent
        )
    }
    
    private func routeIntent(
        classificationResult: IntentClassificationResult,
        context: VoiceProcessingContext,
        originalText: String
    ) async throws -> RoutingDecision {
        
        let routingContext: [String: Any] = [
            "timeOfDay": context.timeOfDay,
            "deviceState": [
                "batteryLevel": context.deviceState.batteryLevel,
                "isLowPowerMode": context.deviceState.isLowPowerMode,
                "isNetworkAvailable": context.deviceState.isNetworkAvailable
            ],
            "userPreferences": context.userPreferences
        ]
        
        return try await intentRouter.routeIntent(
            text: originalText,
            context: routingContext,
            previousIntent: context.previousIntent
        )
    }
    
    private func executeProcessing(
        routingDecision: RoutingDecision,
        classificationResult: IntentClassificationResult,
        originalText: String,
        context: VoiceProcessingContext
    ) async throws -> (response: VoiceResponse, method: ProcessingMethod, wasOffline: Bool) {
        
        switch routingDecision.route {
        case .offline(let cached):
            return try await processOffline(
                intent: classificationResult.intent,
                text: originalText,
                context: context,
                cached: cached
            )
            
        case .onDevice(let handler):
            currentProcessingStep = .processingOnDevice
            return try await processOnDevice(
                intent: classificationResult.intent,
                text: originalText,
                context: context,
                handler: handler
            )
            
        case .server:
            currentProcessingStep = .processingOnServer
            return try await processOnServer(
                text: originalText,
                context: context,
                intent: classificationResult.intent
            )
            
        case .hybrid(let onDeviceFirst):
            return try await processHybrid(
                intent: classificationResult.intent,
                text: originalText,
                context: context,
                onDeviceFirst: onDeviceFirst,
                fallbackRoute: routingDecision.fallbackRoute
            )
        }
    }
    
    private func processOffline(
        intent: VoiceIntent,
        text: String,
        context: VoiceProcessingContext,
        cached: Bool
    ) async throws -> (response: VoiceResponse, method: ProcessingMethod, wasOffline: Bool) {
        
        guard let handler = offlineHandlers[intent] else {
            throw VoiceProcessingError.noOfflineHandler(intent)
        }
        
        guard await handler.canHandle(text: text) else {
            throw VoiceProcessingError.offlineHandlerCannotProcess(intent, text)
        }
        
        let contextDict: [String: Any] = [
            "timeOfDay": context.timeOfDay,
            "deviceState": [
                "batteryLevel": context.deviceState.batteryLevel,
                "isLowPowerMode": context.deviceState.isLowPowerMode
            ]
        ]
        
        let response = try await handler.process(text: text, context: contextDict)
        
        return (
            response: response,
            method: .fullyOnDevice,
            wasOffline: true
        )
    }
    
    private func processOnDevice(
        intent: VoiceIntent,
        text: String,
        context: VoiceProcessingContext,
        handler: String
    ) async throws -> (response: VoiceResponse, method: ProcessingMethod, wasOffline: Bool) {
        
        // For on-device processing, we can use the offline handlers
        // or implement dedicated on-device Core ML processing
        if let offlineHandler = offlineHandlers[intent],
           await offlineHandler.canHandle(text: text) {
            
            let contextDict: [String: Any] = [
                "timeOfDay": context.timeOfDay,
                "deviceState": [
                    "batteryLevel": context.deviceState.batteryLevel,
                    "isLowPowerMode": context.deviceState.isLowPowerMode
                ]
            ]
            
            let response = try await offlineHandler.process(text: text, context: contextDict)
            return (
                response: response,
                method: .fullyOnDevice,
                wasOffline: false
            )
        }
        
        // Fallback to server if no on-device handler available
        throw VoiceProcessingError.onDeviceProcessingNotAvailable(intent)
    }
    
    private func processOnServer(
        text: String,
        context: VoiceProcessingContext,
        intent: VoiceIntent
    ) async throws -> (response: VoiceResponse, method: ProcessingMethod, wasOffline: Bool) {
        
        let request = VoiceRequest(
            text: text,
            sessionId: Constants.getCurrentSessionId(),
            metadata: [
                "intent": intent.rawValue,
                "confidence": "1.0", // We already classified, so high confidence
                "processingMethod": "server",
                "timeOfDay": context.timeOfDay
            ],
            generateAudio: true
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            apiClient.sendVoiceCommandEnhanced(request) { result in
                switch result {
                case .success(let enhancedResponse):
                    let voiceResponse = VoiceResponse(
                        text: enhancedResponse.text,
                        success: enhancedResponse.success,
                        audioBase64: enhancedResponse.audioBase64
                    )
                    
                    continuation.resume(returning: (
                        response: voiceResponse,
                        method: .fullyServer,
                        wasOffline: false
                    ))
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func processHybrid(
        intent: VoiceIntent,
        text: String,
        context: VoiceProcessingContext,
        onDeviceFirst: Bool,
        fallbackRoute: ProcessingRoute?
    ) async throws -> (response: VoiceResponse, method: ProcessingMethod, wasOffline: Bool) {
        
        if onDeviceFirst {
            // Try on-device first
            do {
                return try await processOnDevice(
                    intent: intent,
                    text: text,
                    context: context,
                    handler: "hybrid_primary"
                )
            } catch {
                // Fall back to server
                logger.info("On-device processing failed, falling back to server: \(error.localizedDescription)")
                let serverResult = try await processOnServer(
                    text: text,
                    context: context,
                    intent: intent
                )
                
                return (
                    response: serverResult.response,
                    method: .hybrid(onDevice: ["intent_classification"], server: ["response_generation"]),
                    wasOffline: false
                )
            }
        } else {
            // Server first approach - mainly for complex queries
            return try await processOnServer(
                text: text,
                context: context,
                intent: intent
            )
        }
    }
    
    // MARK: - Helper Methods
    private func generateFollowUpSuggestions(
        intent: VoiceIntent,
        response: VoiceResponse
    ) -> [String] {
        
        switch intent {
        case .time:
            return ["Set a reminder", "What's my schedule today?", "Create an event"]
        case .calculation:
            return ["Calculate tip for dinner", "Convert to different units", "What's the tax on this?"]
        case .deviceControl:
            return ["Check battery level", "What's my storage?", "Device information"]
        case .calendar:
            return ["What's next on my schedule?", "Create another event", "Check availability"]
        case .email:
            return ["Check unread emails", "Send another email", "Search for emails"]
        case .task:
            return ["Add another task", "Show my task list", "Mark task complete"]
        case .weather:
            return ["Tomorrow's forecast", "Weather alerts", "Should I bring an umbrella?"]
        case .general:
            return ["What can you help me with?", "Check the time", "What's my schedule?"]
        case .unknown:
            return ["Try asking about time", "Check calendar", "Get weather forecast"]
        }
    }
    
    private func getCurrentDeviceState() -> DeviceState {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        
        return DeviceState(
            batteryLevel: device.batteryLevel,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            isNetworkAvailable: true, // Simplified - would use proper network monitoring
            isWifiConnected: true, // Simplified - would check actual connection type
            memoryUsage: 0.5 // Simplified - would get actual memory usage
        )
    }
    
    // MARK: - Statistics & Settings Management
    private func updateStatistics(_ result: EnhancedVoiceProcessingResult) {
        processingStatistics.totalProcessed += 1
        
        switch result.processingMethod {
        case .fullyOnDevice:
            if result.wasProcessedOffline {
                processingStatistics.offlineProcessed += 1
            } else {
                processingStatistics.onDeviceProcessed += 1
            }
        case .fullyServer:
            processingStatistics.serverProcessed += 1
        case .hybrid:
            processingStatistics.onDeviceProcessed += 1 // Count as on-device since it started there
        }
        
        // Update rolling averages
        let n = Double(processingStatistics.totalProcessed)
        processingStatistics.averageProcessingTime = 
            ((processingStatistics.averageProcessingTime * (n - 1)) + result.processingTime) / n
        
        let nf = Float(processingStatistics.totalProcessed)
        processingStatistics.averageConfidence = 
            ((processingStatistics.averageConfidence * (nf - 1)) + result.confidence) / nf
        
        saveStatistics()
    }
    
    private func loadProcessingSettings() {
        enableOfflineFirst = userDefaults.bool(forKey: "EnableOfflineFirst")
        confidenceThreshold = userDefaults.float(forKey: "ConfidenceThreshold")
        
        if confidenceThreshold == 0 {
            confidenceThreshold = 0.7 // Default value
        }
    }
    
    private func saveStatistics() {
        if let data = try? JSONEncoder().encode(processingStatistics) {
            userDefaults.set(data, forKey: "EnhancedVoiceProcessingStatistics")
        }
    }
    
    private func loadStatistics() {
        if let data = userDefaults.data(forKey: "EnhancedVoiceProcessingStatistics"),
           let stats = try? JSONDecoder().decode(ProcessingStatistics.self, from: data) {
            processingStatistics = stats
        }
    }
    
    // MARK: - Public Utility Methods
    public func getStatistics() -> ProcessingStatistics {
        return processingStatistics
    }
    
    public func resetStatistics() {
        processingStatistics = ProcessingStatistics()
        saveStatistics()
    }
    
    public func updateSettings(
        enableOfflineFirst: Bool,
        confidenceThreshold: Float
    ) {
        self.enableOfflineFirst = enableOfflineFirst
        self.confidenceThreshold = max(0.1, min(1.0, confidenceThreshold))
        
        userDefaults.set(enableOfflineFirst, forKey: "EnableOfflineFirst")
        userDefaults.set(self.confidenceThreshold, forKey: "ConfidenceThreshold")
        
        // Update intent classifier threshold
        intentClassifier.updateConfidenceThreshold(self.confidenceThreshold)
    }
    
    public func getProcessingCapabilities() -> [VoiceIntent: [String]] {
        return OfflineHandlerFactory.getHandlerCapabilities()
    }
}

// MARK: - Voice Processing Errors
public enum VoiceProcessingError: Error, LocalizedError {
    case transcriptionFailed(String)
    case intentClassificationFailed(String)
    case routingFailed(String)
    case noOfflineHandler(VoiceIntent)
    case offlineHandlerCannotProcess(VoiceIntent, String)
    case onDeviceProcessingNotAvailable(VoiceIntent)
    case serverProcessingFailed(String)
    case hybridProcessingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .intentClassificationFailed(let message):
            return "Intent classification failed: \(message)"
        case .routingFailed(let message):
            return "Routing failed: \(message)"
        case .noOfflineHandler(let intent):
            return "No offline handler available for intent: \(intent.displayName)"
        case .offlineHandlerCannotProcess(let intent, let text):
            return "Offline handler for \(intent.displayName) cannot process: \(text.prefix(50))"
        case .onDeviceProcessingNotAvailable(let intent):
            return "On-device processing not available for intent: \(intent.displayName)"
        case .serverProcessingFailed(let message):
            return "Server processing failed: \(message)"
        case .hybridProcessingFailed(let message):
            return "Hybrid processing failed: \(message)"
        }
    }
}

// MARK: - Codable Conformance
extension EnhancedVoiceProcessor.ProcessingStatistics: Codable {}