//
//  MockPrivateAnalytics.swift
//  VoiceAssistant
//
//  Created by Claude Code on 2025-07-24.
//  Temporary mock to replace PrivateAnalytics during build fix
//

import Foundation
import Combine

/// Temporary mock replacement for PrivateAnalytics to prevent build failures
@MainActor
public class PrivateAnalytics: ObservableObject {
    
    // MARK: - Mock Types (matching original structure)
    
    public struct UsagePattern: Codable {
        let intent: String
        let frequency: Double
        let averageConfidence: Double
        let timeDistribution: [Int: Double]
        let processingMode: ProcessingMode
        let successRate: Double
        let timestamp: Date
        
        public init(intent: String, frequency: Double, averageConfidence: Double, timeDistribution: [Int: Double], processingMode: ProcessingMode, successRate: Double, timestamp: Date) {
            self.intent = intent
            self.frequency = frequency
            self.averageConfidence = averageConfidence
            self.timeDistribution = timeDistribution
            self.processingMode = processingMode
            self.successRate = successRate
            self.timestamp = timestamp
        }
    }
    
    public struct ModelAccuracyMetrics: Codable {
        let intentClassificationAccuracy: Double
        let speechRecognitionAccuracy: Double
        let responseGenerationQuality: Double
        let userCorrectionRate: Double
        let confidenceCalibration: Double
        let timestamp: Date
        
        public init(intentClassificationAccuracy: Double, speechRecognitionAccuracy: Double, responseGenerationQuality: Double, userCorrectionRate: Double, confidenceCalibration: Double, timestamp: Date) {
            self.intentClassificationAccuracy = intentClassificationAccuracy
            self.speechRecognitionAccuracy = speechRecognitionAccuracy
            self.responseGenerationQuality = responseGenerationQuality
            self.userCorrectionRate = userCorrectionRate
            self.confidenceCalibration = confidenceCalibration
            self.timestamp = timestamp
        }
    }
    
    public struct PrivatePerformanceMetrics: Codable {
        let averageResponseTime: TimeInterval
        let onDeviceProcessingRatio: Double
        let memoryUsage: Double
        let batteryImpact: Double
        let cacheHitRate: Double
        let timestamp: Date
        
        public init(averageResponseTime: TimeInterval, onDeviceProcessingRatio: Double, memoryUsage: Double, batteryImpact: Double, cacheHitRate: Double, timestamp: Date) {
            self.averageResponseTime = averageResponseTime
            self.onDeviceProcessingRatio = onDeviceProcessingRatio
            self.memoryUsage = memoryUsage
            self.batteryImpact = batteryImpact
            self.cacheHitRate = cacheHitRate
            self.timestamp = timestamp
        }
    }
    
    public struct UserBehaviorInsights: Codable {
        let peakUsageHours: [Int]
        let mostUsedCommands: [String: Int]
        let averageSessionLength: TimeInterval
        let preferredProcessingMode: ProcessingMode
        let languagePatterns: [String: Double]
        let timestamp: Date
        
        public init(peakUsageHours: [Int], mostUsedCommands: [String: Int], averageSessionLength: TimeInterval, preferredProcessingMode: ProcessingMode, languagePatterns: [String: Double], timestamp: Date) {
            self.peakUsageHours = peakUsageHours
            self.mostUsedCommands = mostUsedCommands
            self.averageSessionLength = averageSessionLength
            self.preferredProcessingMode = preferredProcessingMode
            self.languagePatterns = languagePatterns
            self.timestamp = timestamp
        }
    }
    
    public enum ProcessingMode: String, CaseIterable, Codable {
        case onDevice = "on_device"
        case server = "server"
        case hybrid = "hybrid"
        case enhanced = "enhanced"
    }
    
    public enum AnalyticsError: Error {
        case modelNotAvailable
        case encryptionFailed
        case dataCorrupted
        case insufficientData
        case privacyViolation
    }
    
    // MARK: - Published Properties
    
    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var lastAnalysisDate: Date?
    @Published public private(set) var dataRetentionDays: Int = 30
    @Published public private(set) var analyticsDataSize: Int64 = 0
    
    // MARK: - Initialization
    
    public init() {
        print("PrivateAnalytics: Using mock implementation - analytics disabled")
    }
    
    // MARK: - Mock Public Interface (no-op implementations)
    
    public func enableAnalytics() async throws {
        print("MockPrivateAnalytics: enableAnalytics() - no-op")
        isEnabled = true
    }
    
    public func disableAnalytics(deleteData: Bool = false) async {
        print("MockPrivateAnalytics: disableAnalytics() - no-op")
        isEnabled = false
    }
    
    public func recordVoiceEvent(
        intent: String,
        confidence: Double,
        processingMode: ProcessingMode,
        responseTime: TimeInterval,
        success: Bool,
        correction: String? = nil
    ) {
        // No-op
        print("MockPrivateAnalytics: recordVoiceEvent(\(intent)) - no-op")
    }
    
    public func recordModelPerformance(
        modelType: String,
        accuracy: Double,
        latency: TimeInterval,
        memoryUsage: Double
    ) {
        // No-op
        print("MockPrivateAnalytics: recordModelPerformance(\(modelType)) - no-op")
    }
    
    public func recordUserBehavior(
        action: String,
        context: [String: Any],
        duration: TimeInterval? = nil
    ) {
        // No-op
        print("MockPrivateAnalytics: recordUserBehavior(\(action)) - no-op")
    }
    
    public func getUsageInsights() async throws -> UserBehaviorInsights? {
        print("MockPrivateAnalytics: getUsageInsights() - returning nil")
        return nil
    }
    
    public func getModelAccuracy() async throws -> ModelAccuracyMetrics? {
        print("MockPrivateAnalytics: getModelAccuracy() - returning nil")
        return nil
    }
    
    public func getPrivatePerformanceMetrics() async throws -> PrivatePerformanceMetrics? {
        print("MockPrivateAnalytics: getPrivatePerformanceMetrics() - returning nil")
        return nil
    }
    
    public func exportAnalyticsData() async throws -> Data {
        print("MockPrivateAnalytics: exportAnalyticsData() - returning empty data")
        return Data()
    }
    
    public func deleteAllAnalyticsData() async throws {
        print("MockPrivateAnalytics: deleteAllAnalyticsData() - no-op")
    }
}