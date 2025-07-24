//
//  HybridVoiceProcessor.swift
//  VoiceAssistant
//
//  Created by Claude Code on 2025-07-22.
//  Hybrid voice processor that combines Core ML on-device processing with server fallback
//

import Foundation
import AVFoundation
import Combine
import UIKit

// MARK: - Processing Strategy
enum VoiceProcessingStrategy {
    case onDeviceOnly
    case serverOnly
    case hybrid // Try on-device first, fallback to server
    case intelligent // Choose based on conditions
}

// MARK: - Processing Result
struct VoiceProcessingResult {
    let response: VoiceResponse
    let processingMethod: ProcessingMethod
    let processingTime: TimeInterval
    let confidence: Float
    let onDeviceComponents: [String] // Which components were processed on-device
}

enum ProcessingMethod {
    case fullyOnDevice
    case fullyServer
    case hybrid(onDevice: [String], server: [String])
}

// MARK: - Hybrid Voice Processor
@MainActor
class HybridVoiceProcessor: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isProcessing = false
    @Published private(set) var processingStrategy: VoiceProcessingStrategy = .intelligent
    @Published private(set) var lastProcessingResult: VoiceProcessingResult?
    @Published private(set) var performanceMetrics: ProcessingPerformanceMetrics?
    
    // MARK: - Private Properties
    private let coreMLManager = CoreMLManager.shared
    private let apiClient = APIClient.shared
    private let configManager = ModelConfigurationManager.shared
    
    // Processing conditions
    private var isNetworkAvailable: Bool {
        // Simplified network check - in production use proper reachability
        return true
    }
    
    private var batteryLevel: Float {
        UIDevice.current.batteryLevel
    }
    
    private var isLowPowerModeEnabled: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    // MARK: - Processing Performance Metrics
    struct ProcessingPerformanceMetrics {
        let intentClassificationTime: TimeInterval
        let responseGenerationTime: TimeInterval
        let speechEnhancementTime: TimeInterval
        let serverProcessingTime: TimeInterval?
        let totalProcessingTime: TimeInterval
        let memoryUsage: Int64
        let energyImpact: ProcessingEnergyImpact
    }
    
    enum ProcessingEnergyImpact {
        case minimal
        case low
        case medium
        case high
    }
    
    // MARK: - Initialization
    init() {
        Task {
            await setupProcessor()
        }
    }
    
    private func setupProcessor() async {
        // Wait for Core ML manager to initialize
        while !coreMLManager.isInitialized {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Determine initial processing strategy
        processingStrategy = await determineOptimalStrategy()
        
        // Preload critical models if appropriate
        if shouldPreloadModels() {
            await preloadCriticalModels()
        }
    }
    
    // MARK: - Main Processing Interface
    func processVoiceCommand(_ request: VoiceRequest) async throws -> VoiceProcessingResult {
        isProcessing = true
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            isProcessing = false
        }
        
        do {
            let strategy = await determineProcessingStrategy(for: request)
            let result = try await executeProcessingStrategy(strategy, request: request, startTime: startTime)
            
            lastProcessingResult = result
            return result
            
        } catch {
            // If on-device processing fails, try server fallback
            if case .onDeviceOnly = processingStrategy {
                processingStrategy = .serverOnly
                return try await executeProcessingStrategy(.fullyServer, request: request, startTime: startTime)
            }
            throw error
        }
    }
    
    func processVoiceAudio(_ audioData: Data, sessionId: String) async throws -> VoiceProcessingResult {
        isProcessing = true
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            isProcessing = false
        }
        
        // For audio processing, we can enhance the audio on-device first
        let enhancedAudio = try await enhanceAudioIfPossible(audioData)
        
        // Then process either on-device or server
        let strategy = await determineAudioProcessingStrategy(audioData: enhancedAudio)
        
        switch strategy {
        case .fullyOnDevice:
            return try await processAudioOnDevice(enhancedAudio, startTime: startTime)
        case .fullyServer:
            return try await processAudioOnServer(enhancedAudio, sessionId: sessionId, startTime: startTime)
        case .hybrid(let onDeviceSteps, let serverSteps):
            return try await processAudioHybrid(enhancedAudio, sessionId: sessionId, onDeviceSteps: onDeviceSteps, serverSteps: serverSteps, startTime: startTime)
        }
    }
    
    // MARK: - Strategy Determination
    private func determineOptimalStrategy() async -> VoiceProcessingStrategy {
        let settings = configManager.settings
        
        // Check if fallback to server is enabled
        guard settings.enableFallbackToServer else {
            return .onDeviceOnly
        }
        
        // Consider device conditions
        if isLowPowerModeEnabled {
            return .serverOnly // Save battery
        }
        
        if batteryLevel < 0.2 {
            return .serverOnly // Battery critically low
        }
        
        if !isNetworkAvailable {
            return .onDeviceOnly // No network
        }
        
        return .intelligent // Use intelligent selection
    }
    
    private func determineProcessingStrategy(for request: VoiceRequest) async -> ProcessingMethod {
        switch processingStrategy {
        case .onDeviceOnly:
            return .fullyOnDevice
        case .serverOnly:
            return .fullyServer
        case .hybrid:
            return await determineHybridStrategy(for: request)
        case .intelligent:
            return await determineIntelligentStrategy(for: request)
        }
    }
    
    private func determineHybridStrategy(for request: VoiceRequest) async -> ProcessingMethod {
        // Default hybrid: Intent classification on-device, response generation on server
        return .hybrid(onDevice: ["intent_classification"], server: ["response_generation", "action_execution"])
    }
    
    private func determineIntelligentStrategy(for request: VoiceRequest) async -> ProcessingMethod {
        var onDeviceComponents: [String] = []
        var serverComponents: [String] = []
        
        // Intent classification - prefer on-device for privacy and speed
        if await canProcessOnDevice("intent_classification") {
            onDeviceComponents.append("intent_classification")
        } else {
            serverComponents.append("intent_classification")
        }
        
        // Response generation - consider complexity
        let canProcessResponseOnDevice = await canProcessOnDevice("response_generation")
        if request.text.count < 100 && canProcessResponseOnDevice {
            onDeviceComponents.append("response_generation")
        } else {
            serverComponents.append("response_generation")
        }
        
        // Action execution typically requires server integration
        serverComponents.append("action_execution")
        
        if serverComponents.isEmpty {
            return .fullyOnDevice
        } else if onDeviceComponents.isEmpty {
            return .fullyServer
        } else {
            return .hybrid(onDevice: onDeviceComponents, server: serverComponents)
        }
    }
    
    private func determineAudioProcessingStrategy(audioData: Data) async -> ProcessingMethod {
        let audioSize = audioData.count
        let duration = estimateAudioDuration(audioData)
        
        // For short audio clips, prefer on-device processing
        if duration < 10.0 && audioSize < 5_000_000 { // < 10 seconds, < 5MB
            return .hybrid(onDevice: ["speech_enhancement", "intent_classification"], server: ["response_generation"])
        } else {
            return .fullyServer // Long audio - use server for efficiency
        }
    }
    
    private func canProcessOnDevice(_ component: String) async -> Bool {
        // Check if models are available and loaded
        switch component {
        case "intent_classification":
            do {
                _ = try await coreMLManager.getIntentClassificationModel()
                return true
            } catch {
                return false
            }
        case "response_generation":
            do {
                _ = try await coreMLManager.getResponseGenerationModel()
                return true
            } catch {
                return false
            }
        case "speech_enhancement":
            do {
                _ = try await coreMLManager.getSpeechEnhancementModel()
                return true
            } catch {
                return false
            }
        default:
            return false
        }
    }
    
    // MARK: - Processing Execution
    private func executeProcessingStrategy(_ strategy: ProcessingMethod, request: VoiceRequest, startTime: CFAbsoluteTime) async throws -> VoiceProcessingResult {
        
        switch strategy {
        case .fullyOnDevice:
            return try await processOnDevice(request, startTime: startTime)
        case .fullyServer:
            return try await processOnServer(request, startTime: startTime)
        case .hybrid(let onDeviceComponents, let serverComponents):
            return try await processHybrid(request, onDevice: onDeviceComponents, server: serverComponents, startTime: startTime)
        }
    }
    
    private func processOnDevice(_ request: VoiceRequest, startTime: CFAbsoluteTime) async throws -> VoiceProcessingResult {
        var processingTimes: [String: TimeInterval] = [:]
        let intentStartTime = CFAbsoluteTimeGetCurrent()
        
        // 1. Intent Classification
        let intentModel = try await coreMLManager.getIntentClassificationModel()
        let intentInput = IntentClassificationInput(
            text: request.text,
            context: ["sessionId": request.context.sessionId, "languageCode": request.context.languageCode],
            previousIntent: nil
        )
        let intentResult: IntentClassificationOutput = try await intentModel.predict(input: intentInput)
        processingTimes["intent_classification"] = CFAbsoluteTimeGetCurrent() - intentStartTime
        
        // 2. Response Generation
        let responseStartTime = CFAbsoluteTimeGetCurrent()
        let responseModel = try await coreMLManager.getResponseGenerationModel()
        let conversationContext = ConversationContext()
        let userPreferences = UserPreferences.default
        let responseInput = ResponseGenerationInput(
            query: request.text,
            context: conversationContext,
            responseType: .confirmation,
            userPreferences: userPreferences
        )
        let responseResult: ResponseGenerationOutput = try await responseModel.predict(input: responseInput)
        processingTimes["response_generation"] = CFAbsoluteTimeGetCurrent() - responseStartTime
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Create voice response
        let voiceResponse = VoiceResponse(
            text: responseResult.generatedText,
            success: true,
            audioBase64: nil // On-device doesn't generate audio yet
        )
        
        // Create performance metrics
        performanceMetrics = ProcessingPerformanceMetrics(
            intentClassificationTime: processingTimes["intent_classification"] ?? 0,
            responseGenerationTime: processingTimes["response_generation"] ?? 0,
            speechEnhancementTime: 0,
            serverProcessingTime: nil,
            totalProcessingTime: totalTime,
            memoryUsage: coreMLManager.totalMemoryUsage,
            energyImpact: .low
        )
        
        return VoiceProcessingResult(
            response: voiceResponse,
            processingMethod: .fullyOnDevice,
            processingTime: totalTime,
            confidence: min(intentResult.confidence, responseResult.confidence),
            onDeviceComponents: ["intent_classification", "response_generation"]
        )
    }
    
    private func processOnServer(_ request: VoiceRequest, startTime: CFAbsoluteTime) async throws -> VoiceProcessingResult {
        let serverStartTime = CFAbsoluteTimeGetCurrent()
        
        let response = try await withCheckedThrowingContinuation { continuation in
            apiClient.sendVoiceCommand(request) { result in
                continuation.resume(with: result)
            }
        }
        
        let serverTime = CFAbsoluteTimeGetCurrent() - serverStartTime
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        performanceMetrics = ProcessingPerformanceMetrics(
            intentClassificationTime: 0,
            responseGenerationTime: 0,
            speechEnhancementTime: 0,
            serverProcessingTime: serverTime,
            totalProcessingTime: totalTime,
            memoryUsage: 0,
            energyImpact: .minimal
        )
        
        return VoiceProcessingResult(
            response: response,
            processingMethod: .fullyServer,
            processingTime: totalTime,
            confidence: response.success ? 0.9 : 0.1, // Default confidence based on success
            onDeviceComponents: []
        )
    }
    
    private func processHybrid(_ request: VoiceRequest, onDevice: [String], server: [String], startTime: CFAbsoluteTime) async throws -> VoiceProcessingResult {
        var processingTimes: [String: TimeInterval] = [:]
        var intent: VoiceIntent = .unknown
        var confidence: Float = 0.0
        
        // Process on-device components
        if onDevice.contains("intent_classification") {
            let intentStartTime = CFAbsoluteTimeGetCurrent()
            let intentModel = try await coreMLManager.getIntentClassificationModel()
            let intentInput = IntentClassificationInput(
                text: request.text,
                context: ["sessionId": request.context.sessionId, "languageCode": request.context.languageCode],
                previousIntent: nil
            )
            let intentResult: IntentClassificationOutput = try await intentModel.predict(input: intentInput)
            intent = intentResult.intent
            confidence = intentResult.confidence
            processingTimes["intent_classification"] = CFAbsoluteTimeGetCurrent() - intentStartTime
        }
        
        // Create modified request for server with on-device results
        var serverRequest = request
        if intent != .unknown {
            var metadata = serverRequest.context.metadata ?? [:]
            metadata["detected_intent"] = intent.rawValue
            metadata["intent_confidence"] = String(confidence)
            serverRequest = VoiceRequest(
                text: serverRequest.text, 
                sessionId: serverRequest.context.sessionId, 
                metadata: metadata, 
                platform: serverRequest.platform
            )
        }
        
        // Process server components
        if server.contains("response_generation") || server.contains("action_execution") {
            let serverStartTime = CFAbsoluteTimeGetCurrent()
            
            let serverResponse = try await withCheckedThrowingContinuation { continuation in
                apiClient.sendVoiceCommand(serverRequest) { result in
                    continuation.resume(with: result)
                }
            }
            
            processingTimes["server_processing"] = CFAbsoluteTimeGetCurrent() - serverStartTime
            
            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            
            performanceMetrics = ProcessingPerformanceMetrics(
                intentClassificationTime: processingTimes["intent_classification"] ?? 0,
                responseGenerationTime: 0,
                speechEnhancementTime: 0,
                serverProcessingTime: processingTimes["server_processing"],
                totalProcessingTime: totalTime,
                memoryUsage: coreMLManager.totalMemoryUsage,
                energyImpact: .medium
            )
            
            return VoiceProcessingResult(
                response: serverResponse,
                processingMethod: .hybrid(onDevice: onDevice, server: server),
                processingTime: totalTime,
                confidence: max(confidence, serverResponse.success ? 0.9 : 0.1),
                onDeviceComponents: onDevice
            )
        }
        
        throw VoiceAssistantError.processingFailed("Hybrid processing configuration error")
    }
    
    // MARK: - Audio Processing Methods
    private func enhanceAudioIfPossible(_ audioData: Data) async throws -> Data {
        guard configManager.settings.enablePreloading,
              let speechEnhancementModel = try? await coreMLManager.getSpeechEnhancementModel() else {
            return audioData // Return original if enhancement not available
        }
        
        do {
            return try await speechEnhancementModel.enhanceForSpeechRecognition(
                audioData: audioData,
                sampleRate: 44100.0
            )
        } catch {
            // If enhancement fails, return original audio
            print("⚠️ Audio enhancement failed: \(error)")
            return audioData
        }
    }
    
    private func processAudioOnDevice(_ audioData: Data, startTime: CFAbsoluteTime) async throws -> VoiceProcessingResult {
        // This would require implementing speech-to-text on device
        // For now, fall back to server processing
        throw VoiceAssistantError.processingFailed("Full on-device audio processing not yet implemented")
    }
    
    private func processAudioOnServer(_ audioData: Data, sessionId: String, startTime: CFAbsoluteTime) async throws -> VoiceProcessingResult {
        let serverStartTime = CFAbsoluteTimeGetCurrent()
        
        let response = try await withCheckedThrowingContinuation { continuation in
            apiClient.sendVoiceAudio(audioData, sessionId: sessionId) { result in
                continuation.resume(with: result)
            }
        }
        
        let serverTime = CFAbsoluteTimeGetCurrent() - serverStartTime
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        return VoiceProcessingResult(
            response: response,
            processingMethod: .fullyServer,
            processingTime: totalTime,
            confidence: response.success ? 0.9 : 0.1, // Default confidence based on success
            onDeviceComponents: []
        )
    }
    
    private func processAudioHybrid(_ audioData: Data, sessionId: String, onDeviceSteps: [String], serverSteps: [String], startTime: CFAbsoluteTime) async throws -> VoiceProcessingResult {
        // Audio was already enhanced if possible
        // Send to server for transcription and processing
        return try await processAudioOnServer(audioData, sessionId: sessionId, startTime: startTime)
    }
    
    // MARK: - Utility Methods
    private func shouldPreloadModels() -> Bool {
        return configManager.settings.enablePreloading &&
               !isLowPowerModeEnabled &&
               batteryLevel > 0.3
    }
    
    private func preloadCriticalModels() async {
        await coreMLManager.preloadCriticalModels()
    }
    
    private func estimateAudioDuration(_ audioData: Data) -> TimeInterval {
        // Rough estimation assuming common audio formats
        // In production, you'd parse the audio header
        let bytesPerSecond: Double = 44100 * 2 * 2 // 44.1kHz, stereo, 16-bit
        return Double(audioData.count) / bytesPerSecond
    }
    
    // MARK: - Configuration Methods
    func updateProcessingStrategy(_ strategy: VoiceProcessingStrategy) {
        processingStrategy = strategy
    }
    
    func getProcessingStatistics() -> [String: Any] {
        return [
            "total_requests": 0, // Would track in production
            "on_device_percentage": 0.0,
            "average_processing_time": performanceMetrics?.totalProcessingTime ?? 0.0,
            "average_confidence": lastProcessingResult?.confidence ?? 0.0,
            "memory_usage": performanceMetrics?.memoryUsage ?? 0
        ]
    }
}

// MARK: - Voice Assistant Error Extension
extension VoiceAssistantError {
    static func processingFailed(_ message: String) -> VoiceAssistantError {
        return .unknownError("Processing failed: \(message)")
    }
}