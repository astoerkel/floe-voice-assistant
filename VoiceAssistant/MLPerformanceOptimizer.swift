import Foundation
import CoreML
import os.log
import UIKit
import Combine

/// Performance modes for Core ML optimization
public enum PerformanceMode: String, CaseIterable {
    case highPerformance = "High Performance"
    case balanced = "Balanced"
    case powerSaving = "Power Saving"
    case adaptive = "Adaptive"
    
    var computeUnits: MLComputeUnits {
        switch self {
        case .highPerformance:
            return .all
        case .balanced:
            return .cpuAndNeuralEngine
        case .powerSaving:
            return .cpuOnly
        case .adaptive:
            return .all // Will be dynamically adjusted
        }
    }
    
    var description: String {
        switch self {
        case .highPerformance:
            return "Maximum performance using all available compute units"
        case .balanced:
            return "Balanced performance and battery efficiency"
        case .powerSaving:
            return "Minimum power consumption, CPU-only processing"
        case .adaptive:
            return "Intelligent adaptation based on device state"
        }
    }
}

/// Thermal state tracking for performance optimization
public enum ThermalState: String {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"
    
    init(from processInfo: ProcessInfo.ThermalState) {
        switch processInfo {
        case .nominal:
            self = .nominal
        case .fair:
            self = .fair
        case .serious:
            self = .serious
        case .critical:
            self = .critical
        @unknown default:
            self = .nominal
        }
    }
    
    var shouldThrottle: Bool {
        return self == .serious || self == .critical
    }
    
    var recommendedPerformanceMode: PerformanceMode {
        switch self {
        case .nominal, .fair:
            return .highPerformance
        case .serious:
            return .balanced
        case .critical:
            return .powerSaving
        }
    }
}

/// Performance metrics for monitoring and optimization
public struct MLPerformanceMetrics {
    let timestamp: Date
    let inferenceTime: TimeInterval
    let memoryUsage: Double // MB
    let thermalState: ThermalState
    let batteryLevel: Float
    let isCharging: Bool
    let computeUnits: MLComputeUnits
    let modelSize: Double // MB
    let successRate: Double
    
    var efficiency: Double {
        // Calculate efficiency score based on multiple factors
        let timeScore = max(0, 1.0 - (inferenceTime / 5.0)) // 5 seconds = 0 score
        let memoryScore = max(0, 1.0 - (memoryUsage / 1000.0)) // 1GB = 0 score
        let thermalScore = thermalState == .nominal ? 1.0 : (thermalState == .fair ? 0.8 : 0.4)
        let batteryScore = isCharging ? 1.0 : Double(batteryLevel)
        
        return (timeScore + memoryScore + thermalScore + batteryScore + successRate) / 5.0
    }
}

/// Core ML Performance Optimizer
/// Monitors system resources and optimizes Core ML performance for battery efficiency
@MainActor
public class MLPerformanceOptimizer: ObservableObject {
    
    // MARK: - Properties
    
    @Published public var currentMode: PerformanceMode = .adaptive
    @Published public var thermalState: ThermalState = .nominal
    @Published public var batteryLevel: Float = 1.0
    @Published public var isCharging: Bool = false
    @Published public var currentMetrics: MLPerformanceMetrics?
    @Published public var isThrottling: Bool = false
    @Published public var performanceHistory: [MLPerformanceMetrics] = []
    
    private let logger = Logger(subsystem: "com.voiceassistant.ml", category: "Performance")
    private var cancellables = Set<AnyCancellable>()
    private let metricsQueue = DispatchQueue(label: "ml-performance", qos: .utility)
    private let maxHistoryCount = 100
    
    // Configuration
    private let thermalThrottleThreshold: TimeInterval = 2.0
    private let batteryThrottleLevel: Float = 0.15
    private let memoryWarningThreshold: Double = 800.0 // MB
    
    // MARK: - Initialization
    
    public init() {
        setupMonitoring()
        loadUserPreferences()
    }
    
    // MARK: - Public Methods
    
    /// Get optimized ML configuration for current conditions
    public func getOptimizedConfiguration() -> MLModelConfiguration {
        let config = MLModelConfiguration()
        
        let computeUnits = determineOptimalComputeUnits()
        config.computeUnits = computeUnits
        
        // Set memory optimization
        if thermalState.shouldThrottle || batteryLevel < batteryThrottleLevel {
            config.allowLowPrecisionAccumulationOnGPU = true
        }
        
        logger.info("Optimized configuration: \(computeUnits.description), thermal: \(self.thermalState.rawValue)")
        
        return config
    }
    
    /// Record performance metrics for a completed inference
    public func recordInference(
        duration: TimeInterval,
        memoryUsage: Double,
        modelSize: Double,
        success: Bool,
        computeUnits: MLComputeUnits
    ) {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            let metrics = MLPerformanceMetrics(
                timestamp: Date(),
                inferenceTime: duration,
                memoryUsage: memoryUsage,
                thermalState: self.thermalState,
                batteryLevel: self.batteryLevel,
                isCharging: self.isCharging,
                computeUnits: computeUnits,
                modelSize: modelSize,
                successRate: success ? 1.0 : 0.0
            )
            
            DispatchQueue.main.async {
                self.updateMetrics(metrics)
            }
        }
    }
    
    /// Update performance mode
    public func setPerformanceMode(_ mode: PerformanceMode) {
        currentMode = mode
        saveUserPreferences()
        logger.info("Performance mode changed to: \(mode.rawValue)")
    }
    
    /// Check if system should throttle performance
    public func shouldThrottle() -> Bool {
        return isThrottling
    }
    
    /// Get performance recommendations
    public func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if thermalState.shouldThrottle {
            recommendations.append("Device is running hot - consider reducing workload")
        }
        
        if batteryLevel < batteryThrottleLevel && !isCharging {
            recommendations.append("Low battery - switching to power saving mode")
        }
        
        if let metrics = currentMetrics, metrics.memoryUsage > memoryWarningThreshold {
            recommendations.append("High memory usage detected - consider model quantization")
        }
        
        if let avgEfficiency = averageEfficiency(), avgEfficiency < 0.7 {
            recommendations.append("Performance below optimal - consider adjusting settings")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Performance is optimal for current conditions")
        }
        
        return recommendations
    }
    
    /// Get average efficiency over recent history
    public func averageEfficiency() -> Double? {
        let recentMetrics = performanceHistory.suffix(20)
        guard !recentMetrics.isEmpty else { return nil }
        
        let totalEfficiency = recentMetrics.reduce(0.0) { $0 + $1.efficiency }
        return totalEfficiency / Double(recentMetrics.count)
    }
    
    /// Clear performance history
    public func clearHistory() {
        performanceHistory.removeAll()
        logger.info("Performance history cleared")
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        // Monitor thermal state
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateThermalState()
            }
            .store(in: &cancellables)
        
        // Monitor battery state
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateBatteryState()
            }
            .store(in: &cancellables)
        
        // Initial state updates
        updateThermalState()
        updateBatteryState()
        
        // Periodic efficiency evaluation
        Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.evaluateAndAdjustPerformance()
            }
            .store(in: &cancellables)
    }
    
    private func updateThermalState() {
        let newThermalState = ThermalState(from: ProcessInfo.processInfo.thermalState)
        
        if newThermalState != thermalState {
            thermalState = newThermalState
            isThrottling = newThermalState.shouldThrottle
            
            logger.info("Thermal state changed to: \(newThermalState.rawValue)")
            
            // Auto-adjust for adaptive mode
            if currentMode == .adaptive {
                adaptToConditions()
            }
        }
    }
    
    private func updateBatteryState() {
        batteryLevel = UIDevice.current.batteryLevel
        isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        
        // Auto-throttle on low battery
        if batteryLevel < batteryThrottleLevel && !isCharging && !isThrottling {
            isThrottling = true
            logger.warning("Low battery throttling activated")
        } else if (batteryLevel > batteryThrottleLevel * 1.5 || isCharging) && isThrottling {
            // Remove throttling when battery recovers
            isThrottling = false
            logger.info("Battery throttling deactivated")
        }
        
        // Auto-adjust for adaptive mode
        if currentMode == .adaptive {
            adaptToConditions()
        }
    }
    
    private func determineOptimalComputeUnits() -> MLComputeUnits {
        switch currentMode {
        case .highPerformance:
            return .all
        case .balanced:
            return .cpuAndNeuralEngine
        case .powerSaving:
            return .cpuOnly
        case .adaptive:
            return determineAdaptiveComputeUnits()
        }
    }
    
    private func determineAdaptiveComputeUnits() -> MLComputeUnits {
        // High thermal state or low battery = CPU only
        if thermalState.shouldThrottle || (batteryLevel < batteryThrottleLevel && !isCharging) {
            return .cpuOnly
        }
        
        // Charging and good thermal state = all units
        if isCharging && thermalState == .nominal {
            return .all
        }
        
        // Default balanced approach
        return .cpuAndNeuralEngine
    }
    
    private func adaptToConditions() {
        guard currentMode == .adaptive else { return }
        
        let optimalUnits = determineOptimalComputeUnits()
        logger.info("Adaptive mode adjusted to: \(optimalUnits.description)")
    }
    
    private func updateMetrics(_ metrics: MLPerformanceMetrics) {
        currentMetrics = metrics
        performanceHistory.append(metrics)
        
        // Limit history size
        if performanceHistory.count > maxHistoryCount {
            performanceHistory.removeFirst(performanceHistory.count - maxHistoryCount)
        }
        
        logger.debug("Recorded metrics: inference=\(metrics.inferenceTime)s, memory=\(metrics.memoryUsage)MB, efficiency=\(metrics.efficiency)")
    }
    
    private func evaluateAndAdjustPerformance() {
        guard let efficiency = averageEfficiency() else { return }
        
        logger.debug("Current average efficiency: \(efficiency)")
        
        // If efficiency is consistently low, suggest optimizations
        if efficiency < 0.5 && !isThrottling {
            logger.warning("Low efficiency detected: \(efficiency)")
        }
    }
    
    private func loadUserPreferences() {
        if let modeString = UserDefaults.standard.string(forKey: "MLPerformanceMode"),
           let mode = PerformanceMode(rawValue: modeString) {
            currentMode = mode
        }
    }
    
    private func saveUserPreferences() {
        UserDefaults.standard.set(currentMode.rawValue, forKey: "MLPerformanceMode")
    }
}

// MARK: - Extensions

extension MLComputeUnits {
    var description: String {
        switch self {
        case .cpuOnly:
            return "CPU Only"
        case .cpuAndGPU:
            return "CPU + GPU"
        case .cpuAndNeuralEngine:
            return "CPU + Neural Engine"
        case .all:
            return "All Units"
        @unknown default:
            return "Unknown"
        }
    }
}