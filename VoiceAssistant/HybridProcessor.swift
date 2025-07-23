import Foundation
import UIKit
import AVFoundation
import Speech

/// Processing location for voice commands
public enum ProcessingLocation: Codable {
    case onDevice
    case server
    case hybrid
    case fallback
}

/// Result from hybrid processing
public struct HybridProcessingResult {
    let response: String
    let audioBase64: String?
    let processingLocation: ProcessingLocation
    let confidence: Double
    let processingTime: TimeInterval
    let cost: Double // Processing cost estimate
    let privacyScore: Double // Privacy protection score (1.0 = fully private)
    let metadata: [String: Any]
}

/// Main hybrid processor that intelligently routes between on-device and server processing
@MainActor
public class HybridProcessor: ObservableObject {
    
    // MARK: - Dependencies
    private let decisionEngine: ProcessingDecisionEngine
    private let apiClient: APIClient
    private let offlineProcessor: OfflineProcessor
    private let responseMerger: ResponseMerger
    private let analytics: HybridProcessingAnalytics
    
    // MARK: - State
    @Published public var isProcessing: Bool = false
    @Published public var currentProcessingLocation: ProcessingLocation = .onDevice
    @Published public var processingStats: ProcessingStats = ProcessingStats()
    
    // MARK: - Configuration
    private var configuration: HybridProcessingConfiguration
    
    public init(
        decisionEngine: ProcessingDecisionEngine = ProcessingDecisionEngine(),
        apiClient: APIClient = APIClient.shared,
        offlineProcessor: OfflineProcessor,
        responseMerger: ResponseMerger = ResponseMerger(),
        analytics: HybridProcessingAnalytics = HybridProcessingAnalytics.shared,
        configuration: HybridProcessingConfiguration = HybridProcessingConfiguration.default
    ) {
        self.decisionEngine = decisionEngine
        self.apiClient = apiClient
        self.offlineProcessor = offlineProcessor
        self.responseMerger = responseMerger
        self.analytics = analytics
        self.configuration = configuration
    }
    
    // MARK: - Default Context Creation
    
    private func createDefaultContext() async -> VoiceProcessingContext {
        let currentTime = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        
        let timeOfDay: String
        switch hour {
        case 5..<12:
            timeOfDay = "morning"
        case 12..<17:
            timeOfDay = "afternoon"
        case 17..<21:
            timeOfDay = "evening"
        default:
            timeOfDay = "night"
        }
        
        let deviceState = DeviceState(
            batteryLevel: 0.8, // Default value
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            isNetworkAvailable: true,
            isWifiConnected: true,
            memoryUsage: 0.5
        )
        
        return VoiceProcessingContext(
            timeOfDay: timeOfDay,
            location: nil,
            previousIntent: nil,
            conversationHistory: [],
            userPreferences: [:],
            deviceState: deviceState
        )
    }
    
    // MARK: - Main Processing Interface
    
    /// Process voice command with intelligent routing
    public func processVoiceCommand(
        text: String,
        audioData: Data? = nil,
        context: VoiceProcessingContext? = nil
    ) async throws -> HybridProcessingResult {
        
        let processingContext: VoiceProcessingContext
        if let context = context {
            processingContext = context
        } else {
            processingContext = await createDefaultContext()
        }
        
        let startTime = Date()
        isProcessing = true
        
        defer {
            isProcessing = false
        }
        
        do {
            // Step 1: Get processing decision
            let decision = await decisionEngine.makeProcessingDecision(
                text: text,
                audioData: audioData,
                context: processingContext
            )
            
            currentProcessingLocation = decision.recommendedLocation
            
            // Step 2: Process according to decision
            let result = try await executeProcessing(
                text: text,
                audioData: audioData,
                decision: decision,
                context: processingContext,
                startTime: startTime
            )
            
            // Step 3: Update analytics
            await analytics.recordProcessingEvent(
                location: result.processingLocation,
                decision: decision,
                result: result,
                success: true
            )
            
            // Step 4: Update stats
            updateProcessingStats(result: result)
            
            return result
            
        } catch {
            // Handle error and record analytics
            await analytics.recordProcessingEvent(
                location: currentProcessingLocation,
                decision: nil,
                result: nil,
                success: false,
                error: error
            )
            
            // Try fallback processing if available
            if let fallbackResult = try? await handleProcessingFallback(
                text: text,
                audioData: audioData,
                context: processingContext,
                originalError: error,
                startTime: startTime
            ) {
                return fallbackResult
            }
            
            throw error
        }
    }
    
    // MARK: - Processing Execution
    
    private func executeProcessing(
        text: String,
        audioData: Data?,
        decision: ProcessingDecision,
        context: VoiceProcessingContext,
        startTime: Date
    ) async throws -> HybridProcessingResult {
        
        switch decision.recommendedLocation {
        case .onDevice:
            return try await processOnDevice(
                text: text,
                audioData: audioData,
                decision: decision,
                context: context,
                startTime: startTime
            )
            
        case .server:
            return try await processOnServer(
                text: text,
                audioData: audioData,
                decision: decision,
                context: context,
                startTime: startTime
            )
            
        case .hybrid:
            return try await processHybrid(
                text: text,
                audioData: audioData,
                decision: decision,
                context: context,
                startTime: startTime
            )
            
        case .fallback:
            return try await processFallback(
                text: text,
                audioData: audioData,
                decision: decision,
                context: context,
                startTime: startTime
            )
        }
    }
    
    // MARK: - On-Device Processing
    
    private func processOnDevice(
        text: String,
        audioData: Data?,
        decision: ProcessingDecision,
        context: VoiceProcessingContext,
        startTime: Date
    ) async throws -> HybridProcessingResult {
        
        // Use existing offline processor
        let offlineResult = await offlineProcessor.processCommand(text, audioData: audioData)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return HybridProcessingResult(
            response: offlineResult.text,
            audioBase64: offlineResult.audioBase64,
            processingLocation: .onDevice,
            confidence: offlineResult.confidence,
            processingTime: processingTime,
            cost: 0.0, // On-device is free
            privacyScore: 1.0, // Maximum privacy
            metadata: [
                "capabilities_used": Array(offlineResult.capabilities),
                "source": String(describing: offlineResult.source),
                "requires_sync": offlineResult.requiresSync
            ]
        )
    }
    
    // MARK: - Server Processing
    
    private func processOnServer(
        text: String,
        audioData: Data?,
        decision: ProcessingDecision,
        context: VoiceProcessingContext,
        startTime: Date
    ) async throws -> HybridProcessingResult {
        
        // Use APIClient with processing flags
        let apiContext = APIVoiceContext()
        let serverResult = try await apiClient.processVoiceCommandWithFlags(
            text: text,
            audioData: audioData,
            processingFlags: ProcessingFlags(
                onDeviceCapable: decision.onDeviceCapability > 0.5,
                complexityScore: decision.complexityScore,
                privacyRequired: decision.privacyRequired,
                resourceConstraints: decision.resourceConstraints
            ),
            context: apiContext
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return HybridProcessingResult(
            response: serverResult.response,
            audioBase64: serverResult.audioBase64,
            processingLocation: .server,
            confidence: serverResult.confidence,
            processingTime: processingTime,
            cost: estimateServerCost(text: text, audioData: audioData),
            privacyScore: 0.3, // Lower privacy due to cloud processing
            metadata: [
                "server_processing_time": serverResult.serverProcessingTime,
                "ai_model_used": serverResult.modelUsed as Any,
                "tokens_consumed": serverResult.tokensConsumed as Any
            ]
        )
    }
    
    // MARK: - Hybrid Processing
    
    private func processHybrid(
        text: String,
        audioData: Data?,
        decision: ProcessingDecision,
        context: VoiceProcessingContext,
        startTime: Date
    ) async throws -> HybridProcessingResult {
        
        // Start both processing paths concurrently
        async let onDeviceTask = processOnDevice(
            text: text,
            audioData: audioData,
            decision: decision,
            context: context,
            startTime: startTime
        )
        
        async let serverTask = processOnServer(
            text: text,
            audioData: audioData,
            decision: decision,
            context: context,
            startTime: startTime
        )
        
        // Wait for both results
        let (onDeviceResult, serverResult) = try await (onDeviceTask, serverTask)
        
        // Merge results intelligently
        let mergedResult = await responseMerger.mergeResults(
            onDeviceResult: onDeviceResult,
            serverResult: serverResult,
            decision: decision
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return HybridProcessingResult(
            response: mergedResult.response,
            audioBase64: mergedResult.audioBase64,
            processingLocation: .hybrid,
            confidence: mergedResult.confidence,
            processingTime: processingTime,
            cost: mergedResult.cost,
            privacyScore: mergedResult.privacyScore,
            metadata: [
                "on_device_confidence": onDeviceResult.confidence,
                "server_confidence": serverResult.confidence,
                "merge_strategy": mergedResult.mergeStrategy,
                "primary_source": mergedResult.primarySource
            ]
        )
    }
    
    // MARK: - Fallback Processing
    
    private func processFallback(
        text: String,
        audioData: Data?,
        decision: ProcessingDecision,
        context: VoiceProcessingContext,
        startTime: Date
    ) async throws -> HybridProcessingResult {
        
        // Try on-device first as fallback
        if let onDeviceResult = try? await processOnDevice(
            text: text,
            audioData: audioData,
            decision: decision,
            context: context,
            startTime: startTime
        ) {
            return onDeviceResult
        }
        
        // Then try basic offline processing
        let basicResult = await offlineProcessor.processCommand(text)
        let processingTime = Date().timeIntervalSince(startTime)
        
        return HybridProcessingResult(
            response: basicResult.text,
            audioBase64: basicResult.audioBase64,
            processingLocation: .fallback,
            confidence: basicResult.confidence,
            processingTime: processingTime,
            cost: 0.0,
            privacyScore: 1.0,
            metadata: [
                "fallback_used": true,
                "basic_processing": true
            ]
        )
    }
    
    // MARK: - Fallback Handling
    
    private func handleProcessingFallback(
        text: String,
        audioData: Data?,
        context: VoiceProcessingContext,
        originalError: Error,
        startTime: Date
    ) async throws -> HybridProcessingResult? {
        
        // If server failed, try on-device
        if currentProcessingLocation == .server {
            return try? await processOnDevice(
                text: text,
                audioData: audioData,
                decision: ProcessingDecision.onDeviceFallback(),
                context: context,
                startTime: startTime
            )
        }
        
        // If on-device failed, try basic fallback
        return try? await processFallback(
            text: text,
            audioData: audioData,
            decision: ProcessingDecision.basicFallback(),
            context: context,
            startTime: startTime
        )
    }
    
    // MARK: - Utility Methods
    
    private func estimateServerCost(text: String, audioData: Data?) -> Double {
        let textCost = Double(text.count) * 0.00001 // Rough estimate
        let audioCost = audioData.map { Double($0.count) * 0.000001 } ?? 0.0
        return textCost + audioCost
    }
    
    private func updateProcessingStats(result: HybridProcessingResult) {
        processingStats.recordProcessing(
            location: result.processingLocation,
            processingTime: result.processingTime,
            confidence: result.confidence,
            cost: result.cost
        )
    }
    
    // MARK: - Configuration Management
    
    public func updateConfiguration(_ newConfiguration: HybridProcessingConfiguration) {
        self.configuration = newConfiguration
        decisionEngine.updateConfiguration(newConfiguration.decisionEngineConfiguration)
    }
    
    // MARK: - Status and Capabilities
    
    public func getCurrentCapabilities() -> ProcessingCapabilities {
        return ProcessingCapabilities(
            onDeviceAvailable: !offlineProcessor.offlineCapabilities.isEmpty,
            serverAvailable: apiClient.isReachable,
            hybridAvailable: !offlineProcessor.offlineCapabilities.isEmpty && apiClient.isReachable,
            currentBatteryLevel: UIDevice.current.batteryLevel,
            networkQuality: decisionEngine.currentNetworkQuality,
            currentMode: currentProcessingLocation
        )
    }
    
    public func getProcessingStats() -> ProcessingStats {
        return processingStats
    }
}

// MARK: - Supporting Types

public struct ProcessingStats {
    public var totalProcessings: Int = 0
    public var onDeviceCount: Int = 0
    public var serverCount: Int = 0
    public var hybridCount: Int = 0
    public var fallbackCount: Int = 0
    
    public var averageOnDeviceTime: TimeInterval = 0
    public var averageServerTime: TimeInterval = 0
    public var averageConfidence: Double = 0
    public var totalCost: Double = 0
    
    public var onDeviceRatio: Double {
        guard totalProcessings > 0 else { return 0 }
        return Double(onDeviceCount) / Double(totalProcessings)
    }
    
    mutating func recordProcessing(
        location: ProcessingLocation,
        processingTime: TimeInterval,
        confidence: Double,
        cost: Double
    ) {
        totalProcessings += 1
        totalCost += cost
        averageConfidence = ((averageConfidence * Double(totalProcessings - 1)) + confidence) / Double(totalProcessings)
        
        switch location {
        case .onDevice:
            onDeviceCount += 1
            averageOnDeviceTime = ((averageOnDeviceTime * Double(onDeviceCount - 1)) + processingTime) / Double(onDeviceCount)
        case .server:
            serverCount += 1
            averageServerTime = ((averageServerTime * Double(serverCount - 1)) + processingTime) / Double(serverCount)
        case .hybrid:
            hybridCount += 1
        case .fallback:
            fallbackCount += 1
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func createDefaultContext() async -> VoiceProcessingContext {
        let deviceState = DeviceState(
            batteryLevel: UIDevice.current.batteryLevel,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            isNetworkAvailable: true,
            isWifiConnected: true,
            memoryUsage: 0.0
        )
        
        return VoiceProcessingContext(
            timeOfDay: getCurrentTimeOfDay(),
            location: nil,
            previousIntent: nil,
            conversationHistory: [],
            userPreferences: [:],
            deviceState: deviceState
        )
    }
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "night"
        }
    }
}

public struct ProcessingCapabilities {
    public let onDeviceAvailable: Bool
    public let serverAvailable: Bool
    public let hybridAvailable: Bool
    public let currentBatteryLevel: Float
    public let networkQuality: NetworkQuality
    public let currentMode: ProcessingLocation
}

public struct HybridProcessingConfiguration {
    public let preferOnDevice: Bool
    public let batteryThreshold: Float
    public let networkQualityThreshold: NetworkQuality
    public let privacyMode: PrivacyMode
    public let costOptimization: Bool
    public let decisionEngineConfiguration: ProcessingDecisionConfiguration
    
    public static let `default` = HybridProcessingConfiguration(
        preferOnDevice: true,
        batteryThreshold: 0.2,
        networkQualityThreshold: .good,
        privacyMode: .balanced,
        costOptimization: true,
        decisionEngineConfiguration: ProcessingDecisionConfiguration.default
    )
}

public enum PrivacyMode {
    case maximum   // Always prefer on-device
    case balanced  // Intelligent routing
    case performance // Prefer server for complex queries
}