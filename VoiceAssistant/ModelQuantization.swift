import Foundation
import CoreML
import os.log
import Combine

/// Quantization levels for model compression
public enum QuantizationLevel: String, CaseIterable {
    case none = "None"
    case light = "Light"
    case medium = "Medium"
    case aggressive = "Aggressive"
    
    var description: String {
        switch self {
        case .none:
            return "No quantization - full precision"
        case .light:
            return "Light quantization - minimal quality impact"
        case .medium:
            return "Medium quantization - balanced quality/size"
        case .aggressive:
            return "Aggressive quantization - maximum compression"
        }
    }
    
    var expectedSizeReduction: Double {
        switch self {
        case .none:
            return 1.0
        case .light:
            return 0.85
        case .medium:
            return 0.65
        case .aggressive:
            return 0.45
        }
    }
    
    var expectedQualityImpact: Double {
        switch self {
        case .none:
            return 0.0
        case .light:
            return 0.02
        case .medium:
            return 0.05
        case .aggressive:
            return 0.12
        }
    }
}

/// Precision mode for model operations
public enum PrecisionMode: String, CaseIterable {
    case float32 = "Float32"
    case float16 = "Float16"
    case int8 = "Int8"
    case adaptive = "Adaptive"
    
    var description: String {
        switch self {
        case .float32:
            return "32-bit floating point - highest precision"
        case .float16:
            return "16-bit floating point - good balance"
        case .int8:
            return "8-bit integer - fastest, lowest memory"
        case .adaptive:
            return "Adaptive precision based on conditions"
        }
    }
    
    var memoryMultiplier: Double {
        switch self {
        case .float32:
            return 1.0
        case .float16:
            return 0.5
        case .int8:
            return 0.25
        case .adaptive:
            return 0.6 // Average case
        }
    }
}

/// Quality vs Performance trade-off settings
public struct QualitySettings {
    let maxInferenceTime: TimeInterval
    let maxMemoryUsage: Double // MB
    let minAccuracyThreshold: Double
    let batteryOptimized: Bool
    
    static let highQuality = QualitySettings(
        maxInferenceTime: 5.0,
        maxMemoryUsage: 1000.0,
        minAccuracyThreshold: 0.95,
        batteryOptimized: false
    )
    
    static let balanced = QualitySettings(
        maxInferenceTime: 2.0,
        maxMemoryUsage: 500.0,
        minAccuracyThreshold: 0.90,
        batteryOptimized: false
    )
    
    static let efficiency = QualitySettings(
        maxInferenceTime: 1.0,
        maxMemoryUsage: 250.0,
        minAccuracyThreshold: 0.85,
        batteryOptimized: true
    )
}

/// Quantization result with metrics
public struct QuantizationResult {
    let originalSize: Double // MB
    let quantizedSize: Double // MB
    let compressionRatio: Double
    let expectedQualityLoss: Double
    let quantizationLevel: QuantizationLevel
    let precisionMode: PrecisionMode
    let processingTime: TimeInterval
    
    var sizeReduction: Double {
        return (originalSize - quantizedSize) / originalSize
    }
}

/// Model Quantization Manager
/// Handles dynamic model compression and precision reduction for efficiency
@MainActor
public class ModelQuantization: ObservableObject {
    
    // MARK: - Properties
    
    @Published public var currentQuantizationLevel: QuantizationLevel = .light
    @Published public var currentPrecisionMode: PrecisionMode = .adaptive
    @Published public var qualitySettings: QualitySettings = .balanced
    @Published public var isQuantizationEnabled: Bool = true
    @Published public var quantizationHistory: [QuantizationResult] = []
    @Published public var currentModelSize: Double = 0.0
    
    private let logger = Logger(subsystem: "com.voiceassistant.ml", category: "Quantization")
    private let performanceOptimizer: MLPerformanceOptimizer
    private var cancellables = Set<AnyCancellable>()
    private let quantizationQueue = DispatchQueue(label: "model-quantization", qos: .utility)
    
    // Cache for quantized model configurations
    private var configurationCache: [String: MLModelConfiguration] = [:]
    private let maxHistoryCount = 50
    
    // MARK: - Initialization
    
    public init(performanceOptimizer: MLPerformanceOptimizer) {
        self.performanceOptimizer = performanceOptimizer
        setupQuantizationMonitoring()
        loadUserPreferences()
    }
    
    // MARK: - Public Methods
    
    /// Get optimized model configuration with quantization settings
    public func getQuantizedConfiguration(
        for modelType: String,
        qualityRequirement: QualitySettings? = nil
    ) -> MLModelConfiguration {
        
        let settings = qualityRequirement ?? qualitySettings
        let cacheKey = "\(modelType)_\(currentQuantizationLevel.rawValue)_\(currentPrecisionMode.rawValue)"
        
        if let cachedConfig = configurationCache[cacheKey] {
            logger.debug("Using cached quantized configuration for \(modelType)")
            return cachedConfig
        }
        
        let config = createQuantizedConfiguration(settings: settings)
        configurationCache[cacheKey] = config
        
        logger.info("Created quantized configuration: level=\(self.currentQuantizationLevel.rawValue), precision=\(self.currentPrecisionMode.rawValue)")
        
        return config
    }
    
    /// Update quantization level based on performance requirements
    public func updateQuantizationLevel(_ level: QuantizationLevel) {
        currentQuantizationLevel = level
        clearConfigurationCache()
        saveUserPreferences()
        
        logger.info("Quantization level updated to: \(level.rawValue)")
    }
    
    /// Update precision mode
    public func updatePrecisionMode(_ mode: PrecisionMode) {
        currentPrecisionMode = mode
        clearConfigurationCache()
        saveUserPreferences()
        
        logger.info("Precision mode updated to: \(mode.rawValue)")
    }
    
    /// Update quality settings
    public func updateQualitySettings(_ settings: QualitySettings) {
        qualitySettings = settings
        clearConfigurationCache()
        saveUserPreferences()
        
        logger.info("Quality settings updated: maxTime=\(settings.maxInferenceTime)s, maxMemory=\(settings.maxMemoryUsage)MB")
    }
    
    /// Analyze model and suggest optimal quantization
    public func analyzeAndSuggestQuantization(
        modelSize: Double,
        averageInferenceTime: TimeInterval,
        memoryUsage: Double,
        accuracy: Double
    ) -> QuantizationLevel {
        
        currentModelSize = modelSize
        
        // Consider system conditions
        let thermalState = performanceOptimizer.thermalState
        let batteryLevel = performanceOptimizer.batteryLevel
        let isCharging = performanceOptimizer.isCharging
        
        var suggestion: QuantizationLevel = .light
        
        // Aggressive quantization for poor conditions
        if thermalState.shouldThrottle || (batteryLevel < 0.2 && !isCharging) {
            suggestion = .aggressive
        }
        // Medium quantization for moderate performance needs
        else if averageInferenceTime > qualitySettings.maxInferenceTime || 
                memoryUsage > qualitySettings.maxMemoryUsage {
            suggestion = .medium
        }
        // Light quantization for good conditions but efficiency focus
        else if qualitySettings.batteryOptimized {
            suggestion = .light
        }
        // No quantization if quality is paramount and conditions are good
        else if accuracy > 0.95 && isCharging && thermalState == .nominal {
            suggestion = .none
        }
        
        logger.info("Quantization suggestion: \(suggestion.rawValue) (thermal: \(thermalState.rawValue), battery: \(batteryLevel), time: \(averageInferenceTime)s)")
        
        return suggestion
    }
    
    /// Simulate quantization impact
    public func simulateQuantizationImpact(
        originalSize: Double,
        level: QuantizationLevel,
        precision: PrecisionMode
    ) -> QuantizationResult {
        
        let sizeReduction = level.expectedSizeReduction * precision.memoryMultiplier
        let quantizedSize = originalSize * sizeReduction
        let compressionRatio = originalSize / quantizedSize
        
        return QuantizationResult(
            originalSize: originalSize,
            quantizedSize: quantizedSize,
            compressionRatio: compressionRatio,
            expectedQualityLoss: level.expectedQualityImpact,
            quantizationLevel: level,
            precisionMode: precision,
            processingTime: 0.0
        )
    }
    
    /// Record actual quantization result
    public func recordQuantizationResult(_ result: QuantizationResult) {
        quantizationHistory.append(result)
        
        // Limit history size
        if quantizationHistory.count > maxHistoryCount {
            quantizationHistory.removeFirst(quantizationHistory.count - maxHistoryCount)
        }
        
        logger.debug("Recorded quantization result: \(result.compressionRatio)x compression, \(result.expectedQualityLoss) quality loss")
    }
    
    /// Get quantization recommendations
    public func getQuantizationRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if !isQuantizationEnabled {
            recommendations.append("Enable quantization for better performance")
            return recommendations
        }
        
        let avgEfficiency = performanceOptimizer.averageEfficiency() ?? 0.5
        
        if avgEfficiency < 0.6 {
            recommendations.append("Consider more aggressive quantization for better efficiency")
        }
        
        if currentModelSize > 500.0 && currentQuantizationLevel == .none {
            recommendations.append("Large model detected - quantization recommended")
        }
        
        if performanceOptimizer.thermalState.shouldThrottle && currentQuantizationLevel != .aggressive {
            recommendations.append("Thermal throttling detected - use aggressive quantization")
        }
        
        if performanceOptimizer.batteryLevel < 0.3 && !performanceOptimizer.isCharging {
            recommendations.append("Low battery - enable aggressive quantization")
        }
        
        let avgCompressionRatio = averageCompressionRatio()
        if avgCompressionRatio < 1.5 && currentQuantizationLevel != .none {
            recommendations.append("Low compression achieved - consider different quantization level")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Quantization settings are optimal for current conditions")
        }
        
        return recommendations
    }
    
    /// Get average compression ratio from history
    public func averageCompressionRatio() -> Double {
        guard !quantizationHistory.isEmpty else { return 1.0 }
        
        let totalRatio = quantizationHistory.reduce(0.0) { $0 + $1.compressionRatio }
        return totalRatio / Double(quantizationHistory.count)
    }
    
    /// Clear quantization history
    public func clearHistory() {
        quantizationHistory.removeAll()
        logger.info("Quantization history cleared")
    }
    
    /// Toggle quantization on/off
    public func toggleQuantization() {
        isQuantizationEnabled.toggle()
        clearConfigurationCache()
        saveUserPreferences()
        
        logger.info("Quantization \(self.isQuantizationEnabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Private Methods
    
    private func setupQuantizationMonitoring() {
        // Monitor performance optimizer changes
        performanceOptimizer.$thermalState
            .combineLatest(performanceOptimizer.$batteryLevel, performanceOptimizer.$isCharging)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] thermalState, batteryLevel, isCharging in
                guard let self = self else { return }
                self.adaptQuantizationToConditions(
                    thermalState: thermalState,
                    batteryLevel: batteryLevel,
                    isCharging: isCharging
                )
            }
            .store(in: &cancellables)
    }
    
    private func adaptQuantizationToConditions(
        thermalState: ThermalState,
        batteryLevel: Float,
        isCharging: Bool
    ) {
        guard isQuantizationEnabled else { return }
        
        var shouldUpdate = false
        
        // Auto-adjust for severe conditions
        if thermalState.shouldThrottle && currentQuantizationLevel != .aggressive {
            currentQuantizationLevel = .aggressive
            shouldUpdate = true
        } else if !thermalState.shouldThrottle && batteryLevel < 0.2 && !isCharging && currentQuantizationLevel == .none {
            currentQuantizationLevel = .medium
            shouldUpdate = true
        }
        
        // Adaptive precision mode adjustments
        if currentPrecisionMode == .adaptive {
            if thermalState.shouldThrottle || (batteryLevel < 0.15 && !isCharging) {
                // Use most aggressive precision for poor conditions
                shouldUpdate = true
            }
        }
        
        if shouldUpdate {
            clearConfigurationCache()
            logger.info("Auto-adapted quantization to conditions")
        }
    }
    
    private func createQuantizedConfiguration(settings: QualitySettings) -> MLModelConfiguration {
        let config = performanceOptimizer.getOptimizedConfiguration()
        
        guard isQuantizationEnabled else {
            return config
        }
        
        // Apply precision-based optimizations
        switch currentPrecisionMode {
        case .float16, .int8, .adaptive:
            config.allowLowPrecisionAccumulationOnGPU = true
        case .float32:
            config.allowLowPrecisionAccumulationOnGPU = false
        }
        
        // Additional optimizations based on quantization level
        switch currentQuantizationLevel {
        case .aggressive:
            config.allowLowPrecisionAccumulationOnGPU = true
        case .none:
            config.allowLowPrecisionAccumulationOnGPU = false
        default:
            break
        }
        
        return config
    }
    
    private func clearConfigurationCache() {
        configurationCache.removeAll()
        logger.debug("Configuration cache cleared")
    }
    
    private func loadUserPreferences() {
        // Load quantization level
        if let levelString = UserDefaults.standard.string(forKey: "QuantizationLevel"),
           let level = QuantizationLevel(rawValue: levelString) {
            currentQuantizationLevel = level
        }
        
        // Load precision mode
        if let modeString = UserDefaults.standard.string(forKey: "PrecisionMode"),
           let mode = PrecisionMode(rawValue: modeString) {
            currentPrecisionMode = mode
        }
        
        // Load quantization enabled state
        isQuantizationEnabled = UserDefaults.standard.bool(forKey: "QuantizationEnabled")
        
        // Load quality settings
        let maxTime = UserDefaults.standard.double(forKey: "QualityMaxTime")
        let maxMemory = UserDefaults.standard.double(forKey: "QualityMaxMemory")
        let minAccuracy = UserDefaults.standard.double(forKey: "QualityMinAccuracy")
        let batteryOptimized = UserDefaults.standard.bool(forKey: "QualityBatteryOptimized")
        
        if maxTime > 0 {
            qualitySettings = QualitySettings(
                maxInferenceTime: maxTime,
                maxMemoryUsage: maxMemory,
                minAccuracyThreshold: minAccuracy,
                batteryOptimized: batteryOptimized
            )
        }
    }
    
    private func saveUserPreferences() {
        UserDefaults.standard.set(currentQuantizationLevel.rawValue, forKey: "QuantizationLevel")
        UserDefaults.standard.set(currentPrecisionMode.rawValue, forKey: "PrecisionMode")
        UserDefaults.standard.set(isQuantizationEnabled, forKey: "QuantizationEnabled")
        UserDefaults.standard.set(qualitySettings.maxInferenceTime, forKey: "QualityMaxTime")
        UserDefaults.standard.set(qualitySettings.maxMemoryUsage, forKey: "QualityMaxMemory")
        UserDefaults.standard.set(qualitySettings.minAccuracyThreshold, forKey: "QualityMinAccuracy")
        UserDefaults.standard.set(qualitySettings.batteryOptimized, forKey: "QualityBatteryOptimized")
    }
}