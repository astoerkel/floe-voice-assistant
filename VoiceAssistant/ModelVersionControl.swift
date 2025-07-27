import Foundation
import CoreML
import UIKit

/// Manages version tracking, compatibility checking, and performance monitoring for Core ML models
public class ModelVersionControl: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var versionHistory: [ModelVersion] = []
    @Published public var currentVersion: String?
    @Published public var performanceMetrics: [String: ModelPerformanceMetrics] = [:]
    
    // MARK: - Types
    
    public struct ModelVersion {
        let version: String
        let installDate: Date
        let size: Int64
        let changelog: [ChangelogEntry]
        let compatibility: CompatibilityInfo
        let performanceBaseline: ModelPerformanceMetrics
        let updateType: ModelUpdateManager.UpdateType
        let rollbackCount: Int
        let isActive: Bool
        
        public struct ChangelogEntry {
            let category: ChangeCategory
            let description: String
            let impact: ImpactLevel
            
            public enum ChangeCategory: Codable {
                case accuracy
                case performance
                case features
                case bugfix
                case security
                case compatibility
            }
            
            public enum ImpactLevel: String, Codable {
                case major
                case minor
                case patch
            }
        }
        
        public struct CompatibilityInfo {
            let minOSVersion: String
            let minAppVersion: String
            let supportedDevices: [String]
            let requiredFeatures: [String]
            let deprecatedFeatures: [String]
            let breakingChanges: [String]
        }
    }
    
    public struct ModelPerformanceMetrics {
        public let version: String
        public let recordedDate: Date
        
        // Core ML Performance
        public let inferenceTime: TimeInterval // Average inference time in seconds
        public let loadTime: TimeInterval // Model loading time
        public let memoryUsage: Int64 // Peak memory usage in bytes
        public let modelSize: Int64 // Model file size
        
        // Accuracy Metrics
        public let accuracy: Double // Overall accuracy (0.0 - 1.0)
        public let precision: Double // Precision score
        public let recall: Double // Recall score
        public let f1Score: Double // F1 score
        
        // User Experience Metrics
        public let responseTime: TimeInterval // End-to-end response time
        public let successRate: Double // Successful processing rate
        public let errorRate: Double // Error rate
        public let userSatisfaction: Double // User satisfaction score (0.0 - 1.0)
        
        // Battery and Resource Impact
        public let batteryImpact: Double // Battery drain rate
        public let cpuUsage: Double // CPU utilization percentage
        public let thermalState: Int // Thermal state during processing
        
        // Comparative Metrics
        public let improvementOverPrevious: Double // Performance improvement percentage
        public let regressionRisk: Double // Risk score for performance regression
        
        public func comparisonSummary(with other: ModelPerformanceMetrics) -> ComparisonResult {
            return ComparisonResult(
                current: self,
                previous: other,
                inferenceTimeChange: (self.inferenceTime - other.inferenceTime) / other.inferenceTime,
                accuracyChange: self.accuracy - other.accuracy,
                memoryChange: (Double(self.memoryUsage - other.memoryUsage) / Double(other.memoryUsage)),
                overallImprovement: calculateOverallImprovement(compared: other)
            )
        }
        
        private func calculateOverallImprovement(compared other: ModelPerformanceMetrics) -> Double {
            let accuracyWeight = 0.3
            let speedWeight = 0.25
            let memoryWeight = 0.2
            let successWeight = 0.15
            let batteryWeight = 0.1
            
            let accuracyImprovement = (self.accuracy - other.accuracy) * accuracyWeight
            let speedImprovement = ((other.inferenceTime - self.inferenceTime) / other.inferenceTime) * speedWeight
            let memoryImprovement = ((Double(other.memoryUsage - self.memoryUsage)) / Double(other.memoryUsage)) * memoryWeight
            let successImprovement = (self.successRate - other.successRate) * successWeight
            let batteryImprovement = (other.batteryImpact - self.batteryImpact) * batteryWeight
            
            return accuracyImprovement + speedImprovement + memoryImprovement + successImprovement + batteryImprovement
        }
    }
    
    public struct ComparisonResult {
        let current: ModelPerformanceMetrics
        let previous: ModelPerformanceMetrics
        let inferenceTimeChange: Double // Percentage change
        let accuracyChange: Double // Absolute change
        let memoryChange: Double // Percentage change
        let overallImprovement: Double // Overall improvement score
        
        public var isImprovement: Bool {
            return overallImprovement > 0.05 // 5% improvement threshold
        }
        
        public var isRegression: Bool {
            return overallImprovement < -0.10 // 10% regression threshold
        }
        
        public var shouldRollback: Bool {
            return overallImprovement < -0.20 || // 20% performance drop
                   accuracyChange < -0.05 || // 5% accuracy drop
                   current.errorRate > previous.errorRate * 1.5 // 50% increase in errors
        }
    }
    
    public struct RollbackEvent {
        let fromVersion: String
        let toVersion: String
        let reason: RollbackReason
        let timestamp: Date
        let performanceData: ModelPerformanceMetrics?
        
        public enum RollbackReason: Codable {
            case performanceRegression
            case accuracyDrop
            case userReported
            case automaticTrigger
            case manual
            case compatibilityIssue
        }
    }
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let storageKey = "ModelVersionControl"
    private let metricsKey = "ModelModelPerformanceMetrics"
    private let rollbackKey = "ModelRollbackHistory"
    
    private let maxVersionHistory = 20
    private let maxPerformanceHistory = 50
    private let performanceMonitoringEnabled = true
    
    private var rollbackHistory: [RollbackEvent] = []
    
    // MARK: - Initialization
    
    public init() {
        loadVersionHistory()
        loadModelPerformanceMetrics()
        loadRollbackHistory()
    }
    
    // MARK: - Version Management
    
    /// Check if should update from one version to another
    public func shouldUpdate(from currentVersion: String, to newVersion: String) -> Bool {
        guard let current = parseVersion(currentVersion),
              let new = parseVersion(newVersion) else {
            return false
        }
        
        // Compare semantic versions
        if new.major > current.major { return true }
        if new.major < current.major { return false }
        
        if new.minor > current.minor { return true }
        if new.minor < current.minor { return false }
        
        return new.patch > current.patch
    }
    
    /// Record a successful model update
    public func recordUpdate(to version: String, type: ModelUpdateManager.UpdateType, performanceBaseline: [String: Double]) {
        let changelog = generateChangelog(for: version, type: type)
        let compatibility = generateCompatibilityInfo(for: version)
        
        let performanceMetrics = ModelPerformanceMetrics(
            version: version,
            recordedDate: Date(),
            inferenceTime: performanceBaseline["inferenceTime"] ?? 0.0,
            loadTime: performanceBaseline["loadTime"] ?? 0.0,
            memoryUsage: Int64(performanceBaseline["memoryUsage"] ?? 0),
            modelSize: Int64(performanceBaseline["modelSize"] ?? 0),
            accuracy: performanceBaseline["accuracy"] ?? 0.0,
            precision: performanceBaseline["precision"] ?? 0.0,
            recall: performanceBaseline["recall"] ?? 0.0,
            f1Score: performanceBaseline["f1Score"] ?? 0.0,
            responseTime: performanceBaseline["responseTime"] ?? 0.0,
            successRate: performanceBaseline["successRate"] ?? 1.0,
            errorRate: performanceBaseline["errorRate"] ?? 0.0,
            userSatisfaction: performanceBaseline["userSatisfaction"] ?? 0.8,
            batteryImpact: performanceBaseline["batteryImpact"] ?? 0.0,
            cpuUsage: performanceBaseline["cpuUsage"] ?? 0.0,
            thermalState: Int(performanceBaseline["thermalState"] ?? 0),
            improvementOverPrevious: 0.0,
            regressionRisk: 0.0
        )
        
        // Deactivate previous versions
        for i in 0..<versionHistory.count {
            versionHistory[i] = ModelVersion(
                version: versionHistory[i].version,
                installDate: versionHistory[i].installDate,
                size: versionHistory[i].size,
                changelog: versionHistory[i].changelog,
                compatibility: versionHistory[i].compatibility,
                performanceBaseline: versionHistory[i].performanceBaseline,
                updateType: versionHistory[i].updateType,
                rollbackCount: versionHistory[i].rollbackCount,
                isActive: false
            )
        }
        
        // Add new version
        let newVersion = ModelVersion(
            version: version,
            installDate: Date(),
            size: performanceMetrics.modelSize,
            changelog: changelog,
            compatibility: compatibility,
            performanceBaseline: performanceMetrics,
            updateType: type,
            rollbackCount: 0,
            isActive: true
        )
        
        versionHistory.insert(newVersion, at: 0)
        
        // Limit history size
        if versionHistory.count > maxVersionHistory {
            versionHistory = Array(versionHistory.prefix(maxVersionHistory))
        }
        
        currentVersion = version
        self.performanceMetrics[version] = performanceMetrics
        
        saveVersionHistory()
        saveModelPerformanceMetrics()
    }
    
    /// Record a rollback event
    public func recordRollback(from: String, to: String, reason: RollbackEvent.RollbackReason = .manual) {
        let rollbackEvent = RollbackEvent(
            fromVersion: from,
            toVersion: to,
            reason: reason,
            timestamp: Date(),
            performanceData: performanceMetrics[from]
        )
        
        rollbackHistory.insert(rollbackEvent, at: 0)
        
        // Update rollback count for the version
        if let index = versionHistory.firstIndex(where: { $0.version == from }) {
            let existing = versionHistory[index]
            versionHistory[index] = ModelVersion(
                version: existing.version,
                installDate: existing.installDate,
                size: existing.size,
                changelog: existing.changelog,
                compatibility: existing.compatibility,
                performanceBaseline: existing.performanceBaseline,
                updateType: existing.updateType,
                rollbackCount: existing.rollbackCount + 1,
                isActive: false
            )
        }
        
        // Activate rolled-back version
        if let index = versionHistory.firstIndex(where: { $0.version == to }) {
            let existing = versionHistory[index]
            versionHistory[index] = ModelVersion(
                version: existing.version,
                installDate: existing.installDate,
                size: existing.size,
                changelog: existing.changelog,
                compatibility: existing.compatibility,
                performanceBaseline: existing.performanceBaseline,
                updateType: existing.updateType,
                rollbackCount: existing.rollbackCount,
                isActive: true
            )
        }
        
        currentVersion = to
        
        saveVersionHistory()
        saveRollbackHistory()
    }
    
    /// Get the previous version for rollback
    public func getPreviousVersion() -> String? {
        let sortedVersions = versionHistory.sorted { $0.installDate > $1.installDate }
        return sortedVersions.dropFirst().first?.version
    }
    
    /// Get compatibility information for a version
    public func getCompatibilityInfo(for version: String) -> ModelVersion.CompatibilityInfo? {
        return versionHistory.first { $0.version == version }?.compatibility
    }
    
    /// Check if version is compatible with current system
    public func isCompatible(version: String) -> Bool {
        guard let compatibilityInfo = getCompatibilityInfo(for: version) else {
            return false
        }
        
        let currentOSVersion = UIDevice.current.systemVersion
        let currentAppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let deviceModel = UIDevice.current.model
        
        // Check OS version compatibility
        if !isVersionCompatible(current: currentOSVersion, minimum: compatibilityInfo.minOSVersion) {
            return false
        }
        
        // Check app version compatibility
        if !isVersionCompatible(current: currentAppVersion, minimum: compatibilityInfo.minAppVersion) {
            return false
        }
        
        // Check device compatibility
        if !compatibilityInfo.supportedDevices.isEmpty &&
           !compatibilityInfo.supportedDevices.contains(deviceModel) {
            return false
        }
        
        return true
    }
    
    // MARK: - Performance Monitoring
    
    /// Record performance metrics for a model version
    public func recordModelPerformanceMetrics(_ metrics: ModelPerformanceMetrics) {
        performanceMetrics[metrics.version] = metrics
        
        // Calculate improvement over previous version
        if let previousVersion = getPreviousVersion(),
           let previousMetrics = performanceMetrics[previousVersion] {
            
            let comparison = metrics.comparisonSummary(with: previousMetrics)
            
            // Update metrics with improvement calculation
            let updatedMetrics = ModelPerformanceMetrics(
                version: metrics.version,
                recordedDate: metrics.recordedDate,
                inferenceTime: metrics.inferenceTime,
                loadTime: metrics.loadTime,
                memoryUsage: metrics.memoryUsage,
                modelSize: metrics.modelSize,
                accuracy: metrics.accuracy,
                precision: metrics.precision,
                recall: metrics.recall,
                f1Score: metrics.f1Score,
                responseTime: metrics.responseTime,
                successRate: metrics.successRate,
                errorRate: metrics.errorRate,
                userSatisfaction: metrics.userSatisfaction,
                batteryImpact: metrics.batteryImpact,
                cpuUsage: metrics.cpuUsage,
                thermalState: metrics.thermalState,
                improvementOverPrevious: comparison.overallImprovement,
                regressionRisk: calculateRegressionRisk(comparison)
            )
            
            performanceMetrics[metrics.version] = updatedMetrics
            
            // Check for automatic rollback conditions
            if comparison.shouldRollback {
                triggerAutomaticRollback(reason: .performanceRegression, comparison: comparison)
            }
        }
        
        saveModelPerformanceMetrics()
    }
    
    /// Get performance comparison between versions
    public func getPerformanceComparison(current: String, previous: String) -> ComparisonResult? {
        guard let currentMetrics = performanceMetrics[current],
              let previousMetrics = performanceMetrics[previous] else {
            return nil
        }
        
        return currentMetrics.comparisonSummary(with: previousMetrics)
    }
    
    /// Get performance trend for a specific metric
    public func getPerformanceTrend(metric: String, versions: Int = 5) -> [Double] {
        let sortedVersions = versionHistory.sorted { $0.installDate > $1.installDate }
        let recentVersions = Array(sortedVersions.prefix(versions))
        
        return recentVersions.compactMap { version in
            guard let metrics = performanceMetrics[version.version] else { return nil }
            
            switch metric {
            case "accuracy":
                return metrics.accuracy
            case "inferenceTime":
                return metrics.inferenceTime
            case "memoryUsage":
                return Double(metrics.memoryUsage)
            case "successRate":
                return metrics.successRate
            case "batteryImpact":
                return metrics.batteryImpact
            default:
                return nil
            }
        }
    }
    
    // MARK: - Changelog Generation
    
    private func generateChangelog(for version: String, type: ModelUpdateManager.UpdateType) -> [ModelVersion.ChangelogEntry] {
        // In a real implementation, this would come from the server
        // For now, generate based on update type
        
        var changelog: [ModelVersion.ChangelogEntry] = []
        
        switch type {
        case .delta(_):
            changelog.append(ModelVersion.ChangelogEntry(
                category: .performance,
                description: "Incremental model improvements with reduced download size",
                impact: .minor
            ))
            
        case .fullModel:
            changelog.append(ModelVersion.ChangelogEntry(
                category: .accuracy,
                description: "Full model update with improved accuracy and new features",
                impact: .major
            ))
            
        case .abTest(_):
            changelog.append(ModelVersion.ChangelogEntry(
                category: .features,
                description: "Experimental model features for A/B testing",
                impact: .minor
            ))
        }
        
        // Add common entries
        changelog.append(ModelVersion.ChangelogEntry(
            category: .performance,
            description: "Optimized inference speed and memory usage",
            impact: .minor
        ))
        
        changelog.append(ModelVersion.ChangelogEntry(
            category: .bugfix,
            description: "Various bug fixes and stability improvements",
            impact: .patch
        ))
        
        return changelog
    }
    
    private func generateCompatibilityInfo(for version: String) -> ModelVersion.CompatibilityInfo {
        // In a real implementation, this would come from the server
        return ModelVersion.CompatibilityInfo(
            minOSVersion: "15.0",
            minAppVersion: "1.0.0",
            supportedDevices: ["iPhone", "iPad"],
            requiredFeatures: ["CoreML"],
            deprecatedFeatures: [],
            breakingChanges: []
        )
    }
    
    // MARK: - Rollback Logic
    
    private func calculateRegressionRisk(_ comparison: ComparisonResult) -> Double {
        var risk: Double = 0.0
        
        // Accuracy regression risk
        if comparison.accuracyChange < 0 {
            risk += abs(comparison.accuracyChange) * 2.0
        }
        
        // Performance regression risk
        if comparison.inferenceTimeChange > 0.2 { // 20% slower
            risk += comparison.inferenceTimeChange
        }
        
        // Memory usage increase risk
        if comparison.memoryChange > 0.3 { // 30% more memory
            risk += comparison.memoryChange * 0.5
        }
        
        // Error rate increase risk
        if comparison.current.errorRate > comparison.previous.errorRate {
            risk += (comparison.current.errorRate - comparison.previous.errorRate) * 3.0
        }
        
        return min(risk, 1.0) // Cap at 1.0
    }
    
    private func triggerAutomaticRollback(reason: RollbackEvent.RollbackReason, comparison: ComparisonResult) {
        guard let previousVersion = getPreviousVersion() else { return }
        
        // Post notification for automatic rollback
        NotificationCenter.default.post(
            name: NSNotification.Name("ModelAutomaticRollbackTriggered"),
            object: nil,
            userInfo: [
                "fromVersion": comparison.current.version,
                "toVersion": previousVersion,
                "reason": reason,
                "comparison": comparison
            ]
        )
    }
    
    // MARK: - Version Parsing
    
    private func parseVersion(_ version: String) -> (major: Int, minor: Int, patch: Int)? {
        let components = version.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 3 else { return nil }
        return (major: components[0], minor: components[1], patch: components[2])
    }
    
    private func isVersionCompatible(current: String, minimum: String) -> Bool {
        guard let currentVersion = parseVersion(current),
              let minimumVersion = parseVersion(minimum) else {
            return false
        }
        
        if currentVersion.major > minimumVersion.major { return true }
        if currentVersion.major < minimumVersion.major { return false }
        
        if currentVersion.minor > minimumVersion.minor { return true }
        if currentVersion.minor < minimumVersion.minor { return false }
        
        return currentVersion.patch >= minimumVersion.patch
    }
    
    // MARK: - Persistence
    
    private func saveVersionHistory() {
        if let data = try? JSONEncoder().encode(versionHistory) {
            userDefaults.set(data, forKey: storageKey)
        }
    }
    
    private func loadVersionHistory() {
        guard let data = userDefaults.data(forKey: storageKey),
              let versions = try? JSONDecoder().decode([ModelVersion].self, from: data) else {
            return
        }
        
        versionHistory = versions
        currentVersion = versionHistory.first { $0.isActive }?.version
    }
    
    private func saveModelPerformanceMetrics() {
        if let data = try? JSONEncoder().encode(performanceMetrics) {
            userDefaults.set(data, forKey: metricsKey)
        }
    }
    
    private func loadModelPerformanceMetrics() {
        guard let data = userDefaults.data(forKey: metricsKey),
              let metrics = try? JSONDecoder().decode([String: ModelPerformanceMetrics].self, from: data) else {
            return
        }
        
        performanceMetrics = metrics
    }
    
    private func saveRollbackHistory() {
        if let data = try? JSONEncoder().encode(rollbackHistory) {
            userDefaults.set(data, forKey: rollbackKey)
        }
    }
    
    private func loadRollbackHistory() {
        guard let data = userDefaults.data(forKey: rollbackKey),
              let history = try? JSONDecoder().decode([RollbackEvent].self, from: data) else {
            return
        }
        
        rollbackHistory = history
    }
}

// MARK: - Codable Conformance

extension ModelVersionControl.ModelVersion: Codable {}
extension ModelVersionControl.ModelVersion.ChangelogEntry: Codable {}
extension ModelVersionControl.ModelVersion.CompatibilityInfo: Codable {}
extension ModelVersionControl.ModelPerformanceMetrics: Codable {}
extension ModelVersionControl.RollbackEvent: Codable {}
extension ModelUpdateManager.UpdateType: Codable {
    enum CodingKeys: String, CodingKey {
        case delta, fullModel, abTest
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .delta(let version):
            try container.encode(version, forKey: .delta)
        case .fullModel:
            try container.encode(true, forKey: .fullModel)
        case .abTest(let id):
            try container.encode(id, forKey: .abTest)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let deltaVersion = try container.decodeIfPresent(String.self, forKey: .delta) {
            self = .delta(deltaVersion)
        } else if container.contains(.fullModel) {
            self = .fullModel
        } else if let abTestId = try container.decodeIfPresent(String.self, forKey: .abTest) {
            self = .abTest(abTestId)
        } else {
            self = .fullModel
        }
    }
}