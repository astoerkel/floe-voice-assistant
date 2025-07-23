//
//  CoreMLManager.swift
//  VoiceAssistant
//
//  Created by Claude Code on 2025-07-22.
//  Core ML manager for loading, caching, and managing on-device AI models
//

import Foundation
import CoreML
import Combine
import OSLog

// MARK: - Core ML Manager Configuration
struct CoreMLManagerConfig {
    let maxConcurrentModels: Int
    let memoryLimit: Int64 // in bytes
    let enableAutomaticUpdates: Bool
    let updateCheckInterval: TimeInterval // in seconds
    let enablePerformanceMonitoring: Bool
    let cachingStrategy: ModelCachingStrategy
    
    static let `default` = CoreMLManagerConfig(
        maxConcurrentModels: 3,
        memoryLimit: 200_000_000, // 200MB
        enableAutomaticUpdates: true,
        updateCheckInterval: 3600, // 1 hour
        enablePerformanceMonitoring: true,
        cachingStrategy: .aggressive
    )
}

// MARK: - Model Caching Strategy
enum ModelCachingStrategy {
    case conservative // Only keep actively used models
    case balanced // Keep recently used models
    case aggressive // Preload and cache frequently used models
}

// MARK: - Model Status
enum ModelStatus: Equatable {
    case notLoaded
    case loading
    case loaded
    case error(MLModelError)
    case updating
}

// MARK: - Model Registry Entry
class ModelRegistryEntry: ObservableObject {
    let modelType: MLModelProtocol.Type
    @Published var model: MLModelProtocol?
    @Published var status: ModelStatus = .notLoaded
    @Published var lastUsed: Date?
    @Published var usageCount: Int = 0
    @Published var performanceHistory: [ModelPerformanceMetrics] = []
    
    let identifier: String
    let priority: ModelPriority
    
    init(modelType: MLModelProtocol.Type, identifier: String, priority: ModelPriority) {
        self.modelType = modelType
        self.identifier = identifier
        self.priority = priority
    }
}

// MARK: - Model Priority
enum ModelPriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    static func < (lhs: ModelPriority, rhs: ModelPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Core ML Manager
@MainActor
class CoreMLManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = CoreMLManager()
    
    // MARK: - Published Properties
    @Published private(set) var registeredModels: [String: ModelRegistryEntry] = [:]
    @Published private(set) var isInitialized = false
    @Published private(set) var totalMemoryUsage: Int64 = 0
    @Published private(set) var activeModelsCount = 0
    
    // MARK: - Private Properties
    private let config: CoreMLManagerConfig
    private let logger = Logger(subsystem: "com.voiceassistant", category: "CoreMLManager")
    private var updateTimer: Timer?
    private let serialQueue = DispatchQueue(label: "coreml-manager", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Model Instances (Lazy Loading)
    private lazy var intentClassificationModel = IntentClassificationModel()
    private lazy var responseGenerationModel = ResponseGenerationModel()
    private lazy var speechEnhancementModel = SpeechEnhancementModel()
    
    // MARK: - Initialization
    private init(config: CoreMLManagerConfig = .default) {
        self.config = config
        
        Task {
            await initialize()
        }
    }
    
    private func initialize() async {
        logger.info("Initializing CoreML Manager")
        
        // Register available models
        registerModel(
            model: intentClassificationModel,
            identifier: "intent_classification",
            priority: .high
        )
        
        registerModel(
            model: responseGenerationModel,
            identifier: "response_generation",
            priority: .medium
        )
        
        registerModel(
            model: speechEnhancementModel,
            identifier: "speech_enhancement",
            priority: .low
        )
        
        // Set up automatic updates if enabled
        if config.enableAutomaticUpdates {
            setupAutomaticUpdates()
        }
        
        // Start performance monitoring
        if config.enablePerformanceMonitoring {
            startPerformanceMonitoring()
        }
        
        isInitialized = true
        logger.info("CoreML Manager initialized with \(self.registeredModels.count) models")
    }
    
    // MARK: - Model Registration
    private func registerModel(model: MLModelProtocol, identifier: String, priority: ModelPriority) {
        let entry = ModelRegistryEntry(
            modelType: type(of: model),
            identifier: identifier,
            priority: priority
        )
        entry.model = model
        
        registeredModels[identifier] = entry
        logger.debug("Registered model: \(identifier) with priority: \(priority.rawValue)")
    }
    
    // MARK: - Model Loading & Management
    func loadModel(_ identifier: String, force: Bool = false) async throws {
        guard let entry = registeredModels[identifier] else {
            throw MLModelError.modelNotFound(identifier)
        }
        
        // Check if already loaded and not forcing reload
        if !force && entry.status == .loaded {
            entry.lastUsed = Date()
            entry.usageCount += 1
            return
        }
        
        // Check memory constraints
        if !force {
            try await ensureMemoryAvailable(for: entry)
        }
        
        // Update status to loading
        entry.status = .loading
        
        do {
            // Load the model
            if let model = entry.model {
                try await model.loadModel()
                entry.status = .loaded
                entry.lastUsed = Date()
                entry.usageCount += 1
                
                await updateMemoryUsage()
                logger.info("Successfully loaded model: \(identifier)")
            }
        } catch {
            entry.status = .error(MLModelError.loadingFailed(error.localizedDescription))
            logger.error("Failed to load model \(identifier): \(error.localizedDescription)")
            throw error
        }
    }
    
    func unloadModel(_ identifier: String) async throws {
        guard let entry = registeredModels[identifier] else {
            throw MLModelError.modelNotFound(identifier)
        }
        
        guard let model = entry.model else {
            return
        }
        
        do {
            try await model.unloadModel()
            entry.status = .notLoaded
            
            await updateMemoryUsage()
            logger.info("Successfully unloaded model: \(identifier)")
        } catch {
            entry.status = .error(MLModelError.loadingFailed(error.localizedDescription))
            throw error
        }
    }
    
    // MARK: - Model Access
    func getModel<T: MLModelProtocol>(_ identifier: String, type: T.Type) async throws -> T {
        guard let entry = registeredModels[identifier] else {
            throw MLModelError.modelNotFound(identifier)
        }
        
        // Load model if not already loaded
        if entry.status != .loaded {
            try await loadModel(identifier)
        }
        
        guard let model = entry.model as? T else {
            throw MLModelError.loadingFailed("Model type mismatch for \(identifier)")
        }
        
        entry.lastUsed = Date()
        entry.usageCount += 1
        
        return model
    }
    
    // MARK: - Convenience Methods for Specific Models
    func getIntentClassificationModel() async throws -> IntentClassificationModel {
        return try await getModel("intent_classification", type: IntentClassificationModel.self)
    }
    
    func getResponseGenerationModel() async throws -> ResponseGenerationModel {
        return try await getModel("response_generation", type: ResponseGenerationModel.self)
    }
    
    func getSpeechEnhancementModel() async throws -> SpeechEnhancementModel {
        return try await getModel("speech_enhancement", type: SpeechEnhancementModel.self)
    }
    
    // MARK: - Preloading
    func preloadCriticalModels() async {
        logger.info("Preloading critical models")
        
        let criticalModels = registeredModels.values
            .filter { $0.priority >= .high }
            .sorted { $0.priority > $1.priority }
        
        for entry in criticalModels {
            do {
                try await loadModel(entry.identifier)
            } catch {
                logger.error("Failed to preload critical model \(entry.identifier): \(error.localizedDescription)")
            }
        }
    }
    
    func preloadModelsByUsage() async {
        logger.info("Preloading models by usage patterns")
        
        let frequentlyUsedModels = registeredModels.values
            .filter { $0.usageCount > 5 } // Arbitrary threshold
            .sorted { $0.usageCount > $1.usageCount }
        
        for entry in frequentlyUsedModels.prefix(config.maxConcurrentModels) {
            if entry.status != .loaded {
                do {
                    try await loadModel(entry.identifier)
                } catch {
                    logger.error("Failed to preload frequent model \(entry.identifier): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Memory Management
    private func ensureMemoryAvailable(for entry: ModelRegistryEntry) async throws {
        await updateMemoryUsage()
        
        // Estimate model memory usage (mock estimation)
        let estimatedUsage = entry.model?.getMemoryUsage() ?? 50_000_000
        
        if totalMemoryUsage + estimatedUsage > config.memoryLimit {
            try await freeMemory(needed: estimatedUsage)
        }
    }
    
    private func freeMemory(needed: Int64) async throws {
        logger.info("Freeing memory: \(needed) bytes needed")
        
        // Get models sorted by priority (lowest first) and last used (oldest first)
        let modelsToUnload = registeredModels.values
            .filter { $0.status == .loaded && $0.model?.isLoaded == true }
            .sorted { entry1, entry2 in
                if entry1.priority != entry2.priority {
                    return entry1.priority < entry2.priority
                }
                return (entry1.lastUsed ?? Date.distantPast) < (entry2.lastUsed ?? Date.distantPast)
            }
        
        var freedMemory: Int64 = 0
        
        for entry in modelsToUnload {
            if freedMemory >= needed {
                break
            }
            
            let modelMemory = entry.model?.getMemoryUsage() ?? 0
            try await unloadModel(entry.identifier)
            freedMemory += modelMemory
            
            logger.debug("Unloaded \(entry.identifier) to free \(modelMemory) bytes")
        }
        
        if freedMemory < needed {
            throw MLModelError.memoryExceeded(needed - freedMemory)
        }
    }
    
    private func updateMemoryUsage() async {
        let usage = registeredModels.values
            .compactMap { $0.model?.getMemoryUsage() }
            .reduce(0, +)
        
        totalMemoryUsage = usage
        activeModelsCount = registeredModels.values.filter { $0.status == .loaded }.count
    }
    
    // MARK: - Performance Monitoring
    private func startPerformanceMonitoring() {
        Timer.publish(every: 30, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.collectPerformanceMetrics()
                }
            }
            .store(in: &cancellables)
    }
    
    private func collectPerformanceMetrics() async {
        for entry in registeredModels.values {
            if let metrics = entry.model?.getPerformanceMetrics() {
                entry.performanceHistory.append(metrics)
                
                // Keep only last 100 entries
                if entry.performanceHistory.count > 100 {
                    entry.performanceHistory.removeFirst()
                }
            }
        }
    }
    
    // MARK: - Model Updates
    private func setupAutomaticUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: config.updateCheckInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.checkForModelUpdates()
            }
        }
    }
    
    private func checkForModelUpdates() async {
        logger.info("Checking for model updates")
        
        for entry in registeredModels.values {
            guard let model = entry.model else { continue }
            
            do {
                let hasUpdate = try await model.checkForUpdates()
                if hasUpdate {
                    logger.info("Update available for model: \(entry.identifier)")
                    // In a real implementation, you might want to notify the user
                    // or automatically update based on settings
                }
            } catch {
                logger.error("Failed to check updates for \(entry.identifier): \(error.localizedDescription)")
            }
        }
    }
    
    func updateModel(_ identifier: String) async throws {
        guard let entry = registeredModels[identifier] else {
            throw MLModelError.modelNotFound(identifier)
        }
        
        guard let model = entry.model else {
            throw MLModelError.loadingFailed("Model instance not available")
        }
        
        entry.status = .updating
        
        do {
            try await model.updateModel()
            entry.status = .loaded
            logger.info("Successfully updated model: \(identifier)")
        } catch {
            entry.status = .error(MLModelError.updateFailed(error.localizedDescription))
            throw error
        }
    }
    
    // MARK: - Analytics & Reporting
    func getModelStatistics(_ identifier: String) -> MLModelStatistics? {
        guard let entry = registeredModels[identifier] else {
            return nil
        }
        
        let metrics = entry.performanceHistory
        guard !metrics.isEmpty else {
            return MLModelStatistics(
                totalPredictions: entry.usageCount,
                averagePredictionTime: 0,
                averageConfidence: 0,
                successRate: 0,
                memoryPeakUsage: entry.model?.getMemoryUsage() ?? 0,
                lastUsed: entry.lastUsed
            )
        }
        
        let avgPredictionTime = metrics.map { $0.predictionTime }.reduce(0, +) / Double(metrics.count)
        let avgConfidence = metrics.map { $0.confidence }.reduce(0, +) / Float(metrics.count)
        let peakMemory = metrics.map { $0.memoryUsage }.max() ?? 0
        
        return MLModelStatistics(
            totalPredictions: entry.usageCount,
            averagePredictionTime: avgPredictionTime,
            averageConfidence: avgConfidence,
            successRate: 0.95, // Mock success rate
            memoryPeakUsage: peakMemory,
            lastUsed: entry.lastUsed
        )
    }
    
    func getAllModelStatistics() -> [String: MLModelStatistics] {
        var statistics: [String: MLModelStatistics] = [:]
        
        for (identifier, _) in registeredModels {
            if let stats = getModelStatistics(identifier) {
                statistics[identifier] = stats
            }
        }
        
        return statistics
    }
    
    // MARK: - Cleanup
    func cleanup() async {
        logger.info("Cleaning up CoreML Manager")
        
        updateTimer?.invalidate()
        updateTimer = nil
        
        for entry in registeredModels.values {
            if entry.status == .loaded {
                do {
                    try await unloadModel(entry.identifier)
                } catch {
                    logger.error("Failed to unload \(entry.identifier) during cleanup: \(error.localizedDescription)")
                }
            }
        }
        
        cancellables.removeAll()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}