import Foundation
import CoreML
import Combine
import os.log

/// Tracks on-device vs server processing performance and model accuracy over time
/// Provides insights for model improvement and optimization decisions
@MainActor
public class ModelPerformanceTracker: ObservableObject {
    
    // MARK: - Types
    
    public struct ProcessingRatio {
        let onDeviceCount: Int
        let serverCount: Int
        let hybridCount: Int
        let enhancedCount: Int
        let totalCount: Int
        
        public var onDevicePercentage: Double {
            return totalCount > 0 ? Double(onDeviceCount) / Double(totalCount) * 100 : 0
        }
        
        public var serverPercentage: Double {
            return totalCount > 0 ? Double(serverCount) / Double(totalCount) * 100 : 0
        }
        
        public var hybridPercentage: Double {
            return totalCount > 0 ? Double(hybridCount) / Double(totalCount) * 100 : 0
        }
        
        public var enhancedPercentage: Double {
            return totalCount > 0 ? Double(enhancedCount) / Double(totalCount) * 100 : 0
        }
    }
    
    public struct ResponseTimeMetrics {
        let onDeviceAverage: TimeInterval
        let serverAverage: TimeInterval
        let onDeviceP95: TimeInterval
        let serverP95: TimeInterval
        let improvementRatio: Double // How much faster on-device is vs server
        
        public init(onDeviceAverage: TimeInterval, serverAverage: TimeInterval, onDeviceP95: TimeInterval, serverP95: TimeInterval) {
            self.onDeviceAverage = onDeviceAverage
            self.serverAverage = serverAverage
            self.onDeviceP95 = onDeviceP95
            self.serverP95 = serverP95
            self.improvementRatio = serverAverage > 0 ? onDeviceAverage / serverAverage : 1.0
        }
    }
    
    public struct AccuracyMetrics {
        let onDeviceAccuracy: Double
        let serverAccuracy: Double
        let intentClassificationAccuracy: Double
        let speechRecognitionAccuracy: Double
        let responseGenerationAccuracy: Double
        let overallImprovement: Double
        
        public init(onDeviceAccuracy: Double, serverAccuracy: Double, intentClassificationAccuracy: Double, speechRecognitionAccuracy: Double, responseGenerationAccuracy: Double) {
            self.onDeviceAccuracy = onDeviceAccuracy
            self.serverAccuracy = serverAccuracy
            self.intentClassificationAccuracy = intentClassificationAccuracy
            self.speechRecognitionAccuracy = speechRecognitionAccuracy
            self.responseGenerationAccuracy = responseGenerationAccuracy
            self.overallImprovement = onDeviceAccuracy - serverAccuracy
        }
    }
    
    public struct ModelImprovement {
        let modelName: String
        let previousAccuracy: Double
        let currentAccuracy: Double
        let improvementPercentage: Double
        let lastUpdate: Date
        let trainingDataPoints: Int
        
        public init(modelName: String, previousAccuracy: Double, currentAccuracy: Double, lastUpdate: Date, trainingDataPoints: Int) {
            self.modelName = modelName
            self.previousAccuracy = previousAccuracy
            self.currentAccuracy = currentAccuracy
            self.improvementPercentage = previousAccuracy > 0 ? ((currentAccuracy - previousAccuracy) / previousAccuracy) * 100 : 0
            self.lastUpdate = lastUpdate
            self.trainingDataPoints = trainingDataPoints
        }
    }
    
    public struct ProcessingEvent {
        let id: UUID
        let processingMode: ProcessingMode
        let responseTime: TimeInterval
        let accuracy: Double?
        let confidence: Double?
        let success: Bool
        let modelUsed: String?
        let errorType: String?
        let timestamp: Date
        let batteryLevel: Double?
        let memoryUsage: Double?
        let networkQuality: NetworkQuality?
        
        public init(processingMode: ProcessingMode, responseTime: TimeInterval, accuracy: Double? = nil, confidence: Double? = nil, success: Bool, modelUsed: String? = nil, errorType: String? = nil, batteryLevel: Double? = nil, memoryUsage: Double? = nil, networkQuality: NetworkQuality? = nil) {
            self.id = UUID()
            self.processingMode = processingMode
            self.responseTime = responseTime
            self.accuracy = accuracy
            self.confidence = confidence
            self.success = success
            self.modelUsed = modelUsed
            self.errorType = errorType
            self.timestamp = Date()
            self.batteryLevel = batteryLevel
            self.memoryUsage = memoryUsage
            self.networkQuality = networkQuality
        }
    }
    
    public enum ProcessingMode: String, CaseIterable {
        case onDevice = "on_device"
        case server = "server"
        case hybrid = "hybrid"  
        case enhanced = "enhanced"
    }
    
    public enum NetworkQuality: String, Comparable {
        case excellent = "excellent"
        case good = "good"
        case fair = "fair"
        case poor = "poor"
        case unavailable = "unavailable"
        
        public static func < (lhs: NetworkQuality, rhs: NetworkQuality) -> Bool {
            let order: [NetworkQuality] = [.unavailable, .poor, .fair, .good, .excellent]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
    
    // MARK: - Published Properties
    
    @Published public private(set) var currentProcessingRatio: ProcessingRatio
    @Published public private(set) var responseTimeMetrics: ResponseTimeMetrics
    @Published public private(set) var accuracyMetrics: AccuracyMetrics
    @Published public private(set) var modelImprovements: [ModelImprovement] = []
    @Published public private(set) var isTracking: Bool = false
    @Published public private(set) var lastAnalysisDate: Date?
    
    // MARK: - Private Properties
    
    private var processingEvents: [ProcessingEvent] = []
    private let maxEvents = 10000
    private let analysisInterval: TimeInterval = 1800 // 30 minutes
    private var analysisTimer: Timer?
    private let logger = Logger(subsystem: "com.voiceassistant.analytics", category: "ModelPerformance")
    private let privateAnalytics: PrivateAnalytics?
    
    // Model tracking
    private var modelAccuracyHistory: [String: [Double]] = [:]
    private var modelLatencyHistory: [String: [TimeInterval]] = [:]
    private var modelUsageCount: [String: Int] = [:]
    
    // Cache for performance optimization
    private var cachedMetrics: (ProcessingRatio, ResponseTimeMetrics, AccuracyMetrics)?
    private var lastCacheUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    public init(privateAnalytics: PrivateAnalytics? = nil) {
        self.privateAnalytics = privateAnalytics
        
        // Initialize with default values
        self.currentProcessingRatio = ProcessingRatio(onDeviceCount: 0, serverCount: 0, hybridCount: 0, enhancedCount: 0, totalCount: 0)
        self.responseTimeMetrics = ResponseTimeMetrics(onDeviceAverage: 0, serverAverage: 0, onDeviceP95: 0, serverP95: 0)
        self.accuracyMetrics = AccuracyMetrics(onDeviceAccuracy: 0, serverAccuracy: 0, intentClassificationAccuracy: 0, speechRecognitionAccuracy: 0, responseGenerationAccuracy: 0)
        
        loadPersistedData()
    }
    
    deinit {
        analysisTimer?.invalidate()
        // Note: Cannot call MainActor methods from deinit
        // Data will be persisted on next launch or background task
    }
    
    // MARK: - Public Interface
    
    /// Start tracking model performance
    public func startTracking() {
        guard !isTracking else { return }
        
        isTracking = true
        logger.info("Started model performance tracking")
        
        startAnalysisTimer()
    }
    
    /// Stop tracking model performance
    public func stopTracking() {
        guard isTracking else { return }
        
        isTracking = false
        analysisTimer?.invalidate()
        persistData()
        
        logger.info("Stopped model performance tracking")
    }
    
    /// Record a processing event
    public func recordProcessingEvent(
        processingMode: ProcessingMode,
        responseTime: TimeInterval,
        accuracy: Double? = nil,
        confidence: Double? = nil,
        success: Bool,
        modelUsed: String? = nil,
        errorType: String? = nil
    ) {
        guard isTracking else { return }
        
        let event = ProcessingEvent(
            processingMode: processingMode,
            responseTime: responseTime,
            accuracy: accuracy,
            confidence: confidence,
            success: success,
            modelUsed: modelUsed,
            errorType: errorType,
            batteryLevel: getCurrentBatteryLevel(),
            memoryUsage: getCurrentMemoryUsage(),
            networkQuality: getCurrentNetworkQuality()
        )
        
        addEvent(event)
        
        // Update model-specific tracking
        if let modelName = modelUsed {
            updateModelTracking(modelName: modelName, accuracy: accuracy, latency: responseTime)
        }
        
        // Report to private analytics if available
        privateAnalytics?.recordModelPerformance(
            modelType: modelUsed ?? "unknown",
            accuracy: accuracy ?? 0.0,
            latency: responseTime,
            memoryUsage: event.memoryUsage ?? 0.0
        )
        
        // Invalidate cache
        invalidateCache()
        
        logger.debug("Recorded processing event: \(processingMode.rawValue), success: \(success), time: \(responseTime)s")
    }
    
    /// Get current processing ratio with caching
    public func getProcessingRatio() -> ProcessingRatio {
        if let cached = getCachedMetrics() {
            return cached.0
        }
        
        let ratio = calculateProcessingRatio()
        updateCache(ratio: ratio, responseTime: responseTimeMetrics, accuracy: accuracyMetrics)
        return ratio
    }
    
    /// Get response time metrics with caching
    public func getResponseTimeMetrics() -> ResponseTimeMetrics {
        if let cached = getCachedMetrics() {
            return cached.1
        }
        
        let metrics = calculateResponseTimeMetrics()
        updateCache(ratio: currentProcessingRatio, responseTime: metrics, accuracy: accuracyMetrics)
        return metrics
    }
    
    /// Get accuracy metrics with caching
    public func getAccuracyMetrics() -> AccuracyMetrics {
        if let cached = getCachedMetrics() {
            return cached.2
        }
        
        let metrics = calculateAccuracyMetrics()
        updateCache(ratio: currentProcessingRatio, responseTime: responseTimeMetrics, accuracy: metrics)
        return metrics
    }
    
    /// Get model improvement tracking
    public func getModelImprovements() -> [ModelImprovement] {
        return modelImprovements.sorted { $0.improvementPercentage > $1.improvementPercentage }
    }
    
    /// Get detailed model performance for specific model
    public func getModelPerformance(for modelName: String) -> (accuracy: [Double], latency: [TimeInterval], usage: Int)? {
        guard let accuracyHistory = modelAccuracyHistory[modelName],
              let latencyHistory = modelLatencyHistory[modelName],
              let usage = modelUsageCount[modelName] else {
            return nil
        }
        
        return (accuracy: accuracyHistory, latency: latencyHistory, usage: usage)
    }
    
    /// Get processing mode recommendation based on current conditions
    public func getProcessingModeRecommendation() -> ProcessingMode {
        let batteryLevel = getCurrentBatteryLevel()
        let networkQuality = getCurrentNetworkQuality()
        let memoryPressure = getCurrentMemoryUsage()
        
        // Low battery - prefer on-device processing
        if batteryLevel < 0.2 {
            return .onDevice
        }
        
        // High memory pressure - prefer server processing
        if memoryPressure > 0.8 {
            return .server
        }
        
        // Poor network - prefer on-device processing
        if networkQuality == .poor || networkQuality == .unavailable {
            return .enhanced
        }
        
        // Good conditions - use hybrid for best of both worlds
        return .hybrid
    }
    
    /// Get areas for improvement based on performance data
    public func getImprovementAreas() -> [String] {
        var areas: [String] = []
        
        let ratio = getProcessingRatio()
        let responseMetrics = getResponseTimeMetrics()
        let accuracyMetrics = getAccuracyMetrics()
        
        // Check if on-device processing could be improved
        if ratio.onDevicePercentage < 50 && responseMetrics.onDeviceAverage < responseMetrics.serverAverage {
            areas.append("Increase on-device processing ratio to improve response times")
        }
        
        // Check if accuracy needs improvement
        if accuracyMetrics.onDeviceAccuracy < 0.85 {
            areas.append("Improve on-device model accuracy through additional training")
        }
        
        // Check if response times are suboptimal
        if responseMetrics.onDeviceAverage > 2.0 {
            areas.append("Optimize on-device models for faster inference")
        }
        
        // Check for underperforming models
        for improvement in modelImprovements {
            if improvement.currentAccuracy < 0.8 {
                areas.append("Model '\(improvement.modelName)' accuracy below threshold")
            }
        }
        
        return areas
    }
    
    /// Export performance data for analysis
    public func exportPerformanceData() throws -> Data {
        let exportData = ModelPerformanceExport(
            processingRatio: getProcessingRatio(),
            responseTimeMetrics: getResponseTimeMetrics(),
            accuracyMetrics: getAccuracyMetrics(),
            modelImprovements: getModelImprovements(),
            recentEvents: Array(processingEvents.suffix(100)), // Last 100 events
            exportDate: Date(),
            analysisVersion: "1.0"
        )
        
        return try JSONEncoder().encode(exportData)
    }
    
    /// Clear all performance data
    public func clearPerformanceData() {
        processingEvents.removeAll()
        modelAccuracyHistory.removeAll()
        modelLatencyHistory.removeAll()
        modelUsageCount.removeAll()  
        modelImprovements.removeAll()
        
        invalidateCache()
        persistData()
        
        logger.info("Cleared all performance data")
    }
    
    // MARK: - Private Methods
    
    private func addEvent(_ event: ProcessingEvent) {
        processingEvents.append(event)
        
        // Maintain event limit
        if processingEvents.count > maxEvents {
            processingEvents.removeFirst(processingEvents.count - maxEvents)
        }
    }
    
    private func updateModelTracking(modelName: String, accuracy: Double?, latency: TimeInterval) {
        // Update accuracy history
        if let accuracy = accuracy {
            if modelAccuracyHistory[modelName] == nil {
                modelAccuracyHistory[modelName] = []
            }
            modelAccuracyHistory[modelName]?.append(accuracy)
            
            // Keep last 100 accuracy measurements
            if let count = modelAccuracyHistory[modelName]?.count, count > 100 {
                modelAccuracyHistory[modelName]?.removeFirst()
            }
        }
        
        // Update latency history
        if modelLatencyHistory[modelName] == nil {
            modelLatencyHistory[modelName] = []
        }
        modelLatencyHistory[modelName]?.append(latency)
        
        // Keep last 100 latency measurements
        if let count = modelLatencyHistory[modelName]?.count, count > 100 {
            modelLatencyHistory[modelName]?.removeFirst()
        }
        
        // Update usage count
        modelUsageCount[modelName] = (modelUsageCount[modelName] ?? 0) + 1
    }
    
    private func startAnalysisTimer() {
        analysisTimer?.invalidate()
        analysisTimer = Timer.scheduledTimer(withTimeInterval: analysisInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performAnalysis()
            }
        }
    }
    
    private func performAnalysis() {
        guard isTracking else { return }
        
        // Update metrics
        currentProcessingRatio = calculateProcessingRatio()
        responseTimeMetrics = calculateResponseTimeMetrics()
        accuracyMetrics = calculateAccuracyMetrics()
        
        // Update model improvements
        updateModelImprovements()
        
        lastAnalysisDate = Date()
        persistData()
        
        logger.info("Performed performance analysis - On-device: \(currentProcessingRatio.onDevicePercentage)%, Avg response: \(responseTimeMetrics.onDeviceAverage)s")
    }
    
    private func calculateProcessingRatio() -> ProcessingRatio {
        let onDeviceCount = processingEvents.filter { $0.processingMode == .onDevice }.count
        let serverCount = processingEvents.filter { $0.processingMode == .server }.count
        let hybridCount = processingEvents.filter { $0.processingMode == .hybrid }.count
        let enhancedCount = processingEvents.filter { $0.processingMode == .enhanced }.count
        let totalCount = processingEvents.count
        
        return ProcessingRatio(
            onDeviceCount: onDeviceCount,
            serverCount: serverCount,
            hybridCount: hybridCount,
            enhancedCount: enhancedCount,
            totalCount: totalCount
        )
    }
    
    private func calculateResponseTimeMetrics() -> ResponseTimeMetrics {
        let onDeviceEvents = processingEvents.filter { $0.processingMode == .onDevice || $0.processingMode == .enhanced }
        let serverEvents = processingEvents.filter { $0.processingMode == .server || $0.processingMode == .hybrid }
        
        let onDeviceTimes = onDeviceEvents.map { $0.responseTime }
        let serverTimes = serverEvents.map { $0.responseTime }
        
        let onDeviceAvg = onDeviceTimes.isEmpty ? 0 : onDeviceTimes.reduce(0, +) / Double(onDeviceTimes.count)
        let serverAvg = serverTimes.isEmpty ? 0 : serverTimes.reduce(0, +) / Double(serverTimes.count)
        
        let onDeviceP95 = calculatePercentile(onDeviceTimes.sorted(), percentile: 0.95)
        let serverP95 = calculatePercentile(serverTimes.sorted(), percentile: 0.95)
        
        return ResponseTimeMetrics(
            onDeviceAverage: onDeviceAvg,
            serverAverage: serverAvg,
            onDeviceP95: onDeviceP95,
            serverP95: serverP95
        )
    }
    
    private func calculateAccuracyMetrics() -> AccuracyMetrics {
        let onDeviceEvents = processingEvents.filter { 
            ($0.processingMode == .onDevice || $0.processingMode == .enhanced) && $0.accuracy != nil 
        }
        let serverEvents = processingEvents.filter { 
            ($0.processingMode == .server || $0.processingMode == .hybrid) && $0.accuracy != nil 
        }
        
        let onDeviceAccuracies = onDeviceEvents.compactMap { $0.accuracy }
        let serverAccuracies = serverEvents.compactMap { $0.accuracy }
        
        let onDeviceAvg = onDeviceAccuracies.isEmpty ? 0 : onDeviceAccuracies.reduce(0, +) / Double(onDeviceAccuracies.count)
        let serverAvg = serverAccuracies.isEmpty ? 0 : serverAccuracies.reduce(0, +) / Double(serverAccuracies.count)
        
        // Calculate model-specific accuracies
        let intentEvents = processingEvents.filter { $0.modelUsed?.contains("Intent") == true }
        let speechEvents = processingEvents.filter { $0.modelUsed?.contains("Speech") == true }
        let responseEvents = processingEvents.filter { $0.modelUsed?.contains("Response") == true }
        
        let intentAccuracy = calculateAverageAccuracy(intentEvents)
        let speechAccuracy = calculateAverageAccuracy(speechEvents)
        let responseAccuracy = calculateAverageAccuracy(responseEvents)
        
        return AccuracyMetrics(
            onDeviceAccuracy: onDeviceAvg,
            serverAccuracy: serverAvg,
            intentClassificationAccuracy: intentAccuracy,
            speechRecognitionAccuracy: speechAccuracy,
            responseGenerationAccuracy: responseAccuracy
        )
    }
    
    private func updateModelImprovements() {
        var improvements: [ModelImprovement] = []
        
        for (modelName, accuracies) in modelAccuracyHistory {
            guard accuracies.count >= 2 else { continue }
            
            let previousAccuracy = accuracies[max(0, accuracies.count - 10)...accuracies.count - 1].prefix(5).reduce(0, +) / 5.0
            let currentAccuracy = accuracies.suffix(5).reduce(0, +) / 5.0
            let trainingDataPoints = modelUsageCount[modelName] ?? 0
            
            let improvement = ModelImprovement(
                modelName: modelName,
                previousAccuracy: previousAccuracy,
                currentAccuracy: currentAccuracy,
                lastUpdate: Date(),
                trainingDataPoints: trainingDataPoints
            )
            
            improvements.append(improvement)
        }
        
        modelImprovements = improvements
    }
    
    private func calculatePercentile(_ sortedValues: [TimeInterval], percentile: Double) -> TimeInterval {
        guard !sortedValues.isEmpty else { return 0 }
        
        let index = Int(Double(sortedValues.count - 1) * percentile)
        return sortedValues[index]
    }
    
    private func calculateAverageAccuracy(_ events: [ProcessingEvent]) -> Double {
        let accuracies = events.compactMap { $0.accuracy }
        return accuracies.isEmpty ? 0 : accuracies.reduce(0, +) / Double(accuracies.count)
    }
    
    private func getCachedMetrics() -> (ProcessingRatio, ResponseTimeMetrics, AccuracyMetrics)? {
        guard let cached = cachedMetrics,
              let lastUpdate = lastCacheUpdate,
              Date().timeIntervalSince(lastUpdate) < cacheValidityDuration else {
            return nil
        }
        
        return cached
    }
    
    private func updateCache(ratio: ProcessingRatio, responseTime: ResponseTimeMetrics, accuracy: AccuracyMetrics) {
        cachedMetrics = (ratio, responseTime, accuracy)
        lastCacheUpdate = Date()
    }
    
    private func invalidateCache() {
        cachedMetrics = nil
        lastCacheUpdate = nil
    }
    
    private func getCurrentBatteryLevel() -> Double {
        #if targetEnvironment(simulator)
        return 0.8 // Mock value for simulator
        #else
        return Double(UIDevice.current.batteryLevel)
        #endif
    }
    
    private func getCurrentMemoryUsage() -> Double {
        let info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024 * 1024) // Convert to GB
        }
        
        return 0.0
    }
    
    private func getCurrentNetworkQuality() -> NetworkQuality {
        // In a real implementation, this would check actual network conditions
        // For now, return a mock value
        return .good
    }
    
    private func persistData() {
        let data = ModelPerformanceData(
            events: processingEvents,
            modelAccuracyHistory: modelAccuracyHistory,
            modelLatencyHistory: modelLatencyHistory,
            modelUsageCount: modelUsageCount,
            improvements: modelImprovements,
            lastAnalysis: lastAnalysisDate
        )
        
        do {
            let encoded = try JSONEncoder().encode(data)
            UserDefaults.standard.set(encoded, forKey: "ModelPerformanceTracker.data")
            logger.debug("Persisted performance data")
        } catch {
            logger.error("Failed to persist performance data: \(error)")
        }
    }
    
    private func loadPersistedData() {
        guard let data = UserDefaults.standard.data(forKey: "ModelPerformanceTracker.data") else {
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode(ModelPerformanceData.self, from: data)
            processingEvents = decoded.events
            modelAccuracyHistory = decoded.modelAccuracyHistory
            modelLatencyHistory = decoded.modelLatencyHistory
            modelUsageCount = decoded.modelUsageCount
            modelImprovements = decoded.improvements
            lastAnalysisDate = decoded.lastAnalysis
            
            logger.debug("Loaded persisted performance data")
        } catch {
            logger.error("Failed to load persisted performance data: \(error)")
        }
    }
}

// MARK: - Supporting Types

private struct ModelPerformanceData: Codable {
    let events: [ModelPerformanceTracker.ProcessingEvent]
    let modelAccuracyHistory: [String: [Double]]
    let modelLatencyHistory: [String: [TimeInterval]]
    let modelUsageCount: [String: Int]
    let improvements: [ModelPerformanceTracker.ModelImprovement]
    let lastAnalysis: Date?
}

private struct ModelPerformanceExport: Codable {
    let processingRatio: ModelPerformanceTracker.ProcessingRatio
    let responseTimeMetrics: ModelPerformanceTracker.ResponseTimeMetrics
    let accuracyMetrics: ModelPerformanceTracker.AccuracyMetrics
    let modelImprovements: [ModelPerformanceTracker.ModelImprovement]
    let recentEvents: [ModelPerformanceTracker.ProcessingEvent]
    let exportDate: Date
    let analysisVersion: String
}

// MARK: - Extensions

extension ModelPerformanceTracker.ProcessingRatio: Codable {}
extension ModelPerformanceTracker.ResponseTimeMetrics: Codable {}
extension ModelPerformanceTracker.AccuracyMetrics: Codable {}
extension ModelPerformanceTracker.ModelImprovement: Codable {}
extension ModelPerformanceTracker.ProcessingEvent: Codable {}
extension ModelPerformanceTracker.ProcessingMode: Codable {}
extension ModelPerformanceTracker.NetworkQuality: Codable {}

#if canImport(UIKit)
import UIKit
#endif