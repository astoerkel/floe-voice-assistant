import Foundation
import CoreML
import Network
import UIKit

/// Manages safety measures for Core ML model updates including gradual rollout, monitoring, and automatic rollback
@MainActor
public class ModelUpdateSafetyManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var rolloutProgress: Double = 0.0
    @Published public var isMonitoring: Bool = false
    @Published public var safetyStatus: SafetyStatus = .safe
    @Published public var rolloutPhase: RolloutPhase = .none
    
    // MARK: - Types
    
    public enum SafetyStatus {
        case safe
        case warning(String)
        case critical(String)
        case rollbackInProgress
    }
    
    public enum RolloutPhase {
        case none
        case pilot(percentage: Int)
        case gradual(percentage: Int)
        case fullRollout
        case paused(reason: String)
        case rolledBack(reason: String)
    }
    
    public enum SafetyMetric {
        case crashRate
        case errorRate
        case performanceRegression
        case userFeedback
        case batteryImpact
        case memoryUsage
    }
    
    private struct SafetyThreshold {
        let metric: SafetyMetric
        let warningLevel: Double
        let criticalLevel: Double
        let samplingWindow: TimeInterval // in seconds
    }
    
    private struct RolloutConfiguration {
        let phases: [RolloutPhase]
        let phaseDelay: TimeInterval
        let maxErrorRate: Double
        let maxCrashRate: Double
        let minSuccessRate: Double
        let userFeedbackThreshold: Double
    }
    
    private struct PerformanceMonitor {
        var startTime: Date
        var totalRequests: Int
        var successfulRequests: Int  
        var failedRequests: Int
        var crashes: Int
        var averageResponseTime: TimeInterval
        var memoryPeakUsage: Int64
        var batteryDrainRate: Double
        var userFeedbackScore: Double
    }
    
    // MARK: - Private Properties
    
    private let versionControl: ModelVersionControl
    private let updateManager: ModelUpdateManager
    private var performanceMonitor = PerformanceMonitor(
        startTime: Date(),
        totalRequests: 0,
        successfulRequests: 0,
        failedRequests: 0,
        crashes: 0,
        averageResponseTime: 0,
        memoryPeakUsage: 0,
        batteryDrainRate: 0,
        userFeedbackScore: 0.8
    )
    
    // Safety thresholds
    private let safetyThresholds: [SafetyThreshold] = [
        SafetyThreshold(metric: .crashRate, warningLevel: 0.01, criticalLevel: 0.05, samplingWindow: 3600),
        SafetyThreshold(metric: .errorRate, warningLevel: 0.05, criticalLevel: 0.15, samplingWindow: 1800),
        SafetyThreshold(metric: .performanceRegression, warningLevel: 0.20, criticalLevel: 0.40, samplingWindow: 3600),
        SafetyThreshold(metric: .userFeedback, warningLevel: 0.60, criticalLevel: 0.40, samplingWindow: 7200),
        SafetyThreshold(metric: .batteryImpact, warningLevel: 0.30, criticalLevel: 0.50, samplingWindow: 3600),
        SafetyThreshold(metric: .memoryUsage, warningLevel: 0.25, criticalLevel: 0.50, samplingWindow: 1800)
    ]
    
    // Rollout configuration
    private let rolloutConfig = RolloutConfiguration(
        phases: [
            .pilot(percentage: 5),
            .gradual(percentage: 25),
            .gradual(percentage: 50),
            .gradual(percentage: 75),
            .fullRollout
        ],
        phaseDelay: 3600, // 1 hour between phases
        maxErrorRate: 0.10,
        maxCrashRate: 0.02,
        minSuccessRate: 0.90,
        userFeedbackThreshold: 0.70
    )
    
    private var monitoringTimer: Timer?
    private var rolloutTimer: Timer?
    private var currentPhaseIndex = 0
    private let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    
    // Background task management
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Initialization
    
    public init(versionControl: ModelVersionControl, updateManager: ModelUpdateManager) {
        self.versionControl = versionControl
        self.updateManager = updateManager
        
        setupNotificationObservers()
        loadMonitoringState()
    }
    
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Interface
    
    /// Start gradual rollout for a model update
    public func startGradualRollout(for version: String) async {
        guard rolloutPhase == .none else {
            print("Rollout already in progress")
            return
        }
        
        await MainActor.run {
            currentPhaseIndex = 0
            rolloutProgress = 0.0
        }
        
        await executeNextRolloutPhase(version: version)
    }
    
    /// Start performance monitoring for the current model
    public func startMonitoring(for version: String) {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        performanceMonitor = PerformanceMonitor(
            startTime: Date(),
            totalRequests: 0,
            successfulRequests: 0,
            failedRequests: 0,
            crashes: 0,
            averageResponseTime: 0,
            memoryPeakUsage: 0,
            batteryDrainRate: 0,
            userFeedbackScore: 0.8
        )
        
        startBackgroundTask()
        
        // Start periodic monitoring
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performSafetyCheck()
            }
        }
        
        print("Started safety monitoring for model version \(version)")
        
        // Record monitoring start
        recordSafetyEvent(.monitoringStarted, version: version, details: [:])
    }
    
    /// Stop performance monitoring
    public func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        rolloutTimer?.invalidate()
        rolloutTimer = nil
        
        endBackgroundTask()
        
        print("Stopped safety monitoring")
    }
    
    /// Record a performance event for monitoring
    public func recordPerformanceEvent(_ event: PerformanceEvent) {
        guard isMonitoring else { return }
        
        switch event {
        case .requestStarted:
            performanceMonitor.totalRequests += 1
            
        case .requestSucceeded(let responseTime):
            performanceMonitor.successfulRequests += 1
            updateAverageResponseTime(responseTime)
            
        case .requestFailed(let error):
            performanceMonitor.failedRequests += 1
            recordFailure(error: error)
            
        case .crashDetected:
            performanceMonitor.crashes += 1
            
        case .memoryPeakRecorded(let usage):
            performanceMonitor.memoryPeakUsage = max(performanceMonitor.memoryPeakUsage, usage)
            
        case .batteryDrainRecorded(let rate):
            performanceMonitor.batteryDrainRate = rate
            
        case .userFeedback(let score):
            updateUserFeedbackScore(score)
        }
    }
    
    /// Force rollback to previous version due to safety concerns
    public func forceRollback(reason: String) async -> Bool {
        await MainActor.run {
            safetyStatus = .rollbackInProgress
            rolloutPhase = .rolledBack(reason: reason)
        }
        
        let success = await updateManager.rollbackToPreviousVersion()
        
        if success {
            await MainActor.run {
                safetyStatus = .safe
            }
            
            recordSafetyEvent(.rollbackCompleted, version: updateManager.currentVersion ?? "unknown", details: [
                "reason": reason,
                "successful": true
            ])
            
            // Notify about rollback
            NotificationCenter.default.post(name: NSNotification.Name("ModelSafetyRollback"), object: nil, userInfo: [
                "reason": reason,
                "success": success
            ])
        }
        
        return success
    }
    
    /// Check if device should participate in rollout based on percentage
    public func shouldParticipateInRollout(percentage: Int) -> Bool {
        let hash = deviceId.hash
        let devicePercentile = abs(hash) % 100
        return devicePercentile < percentage
    }
    
    /// Get current safety metrics
    public func getCurrentSafetyMetrics() -> [String: Any] {
        let uptime = Date().timeIntervalSince(performanceMonitor.startTime)
        
        return [
            "uptime": uptime,
            "totalRequests": performanceMonitor.totalRequests,
            "successRate": calculateSuccessRate(),
            "errorRate": calculateErrorRate(),
            "crashRate": calculateCrashRate(),
            "averageResponseTime": performanceMonitor.averageResponseTime,
            "memoryPeakUsage": performanceMonitor.memoryPeakUsage,
            "batteryDrainRate": performanceMonitor.batteryDrainRate,
            "userFeedbackScore": performanceMonitor.userFeedbackScore,
            "safetyStatus": safetyStatus,
            "rolloutPhase": rolloutPhase
        ]
    }
    
    /// Export safety report
    public func exportSafetyReport() -> [String: Any] {
        return [
            "deviceId": deviceId,
            "currentVersion": updateManager.currentVersion ?? "unknown",
            "monitoringStartTime": performanceMonitor.startTime,
            "reportGeneratedAt": Date(),
            "safetyMetrics": getCurrentSafetyMetrics(),
            "thresholds": safetyThresholds.map { threshold in
                [
                    "metric": String(describing: threshold.metric),
                    "warningLevel": threshold.warningLevel,
                    "criticalLevel": threshold.criticalLevel,
                    "samplingWindow": threshold.samplingWindow
                ]
            },
            "rolloutConfiguration": [
                "phases": rolloutConfig.phases.map { String(describing: $0) },
                "phaseDelay": rolloutConfig.phaseDelay,
                "maxErrorRate": rolloutConfig.maxErrorRate,
                "maxCrashRate": rolloutConfig.maxCrashRate,
                "minSuccessRate": rolloutConfig.minSuccessRate
            ]
        ]
    }
    
    // MARK: - Performance Event Types
    
    public enum PerformanceEvent {
        case requestStarted
        case requestSucceeded(responseTime: TimeInterval)
        case requestFailed(error: Error)
        case crashDetected
        case memoryPeakRecorded(usage: Int64)
        case batteryDrainRecorded(rate: Double)
        case userFeedback(score: Double)
    }
    
    // MARK: - Private Implementation
    
    private func setupNotificationObservers() {
        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(memoryWarningReceived),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Listen for automatic rollback triggers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(automaticRollbackTriggered(_:)),
            name: NSNotification.Name("ModelAutomaticRollbackTriggered"),
            object: nil
        )
    }
    
    private func executeNextRolloutPhase(version: String) async {
        guard currentPhaseIndex < rolloutConfig.phases.count else {
            await MainActor.run {
                rolloutPhase = .fullRollout
                rolloutProgress = 1.0
            }
            return
        }
        
        let phase = rolloutConfig.phases[currentPhaseIndex]
        
        await MainActor.run {
            rolloutPhase = phase
        }
        
        switch phase {
        case .pilot(let percentage):
            await executePilotPhase(percentage: percentage, version: version)
            
        case .gradual(let percentage):
            await executeGradualPhase(percentage: percentage, version: version)
            
        case .fullRollout:
            await executeFullRollout(version: version)
            
        case .paused(let reason):
            print("Rollout paused: \(reason)")
            return
            
        case .rolledBack(let reason):
            print("Rollout rolled back: \(reason)")
            return
            
        case .none:
            break
        }
        
        // Schedule next phase
        rolloutTimer = Timer.scheduledTimer(withTimeInterval: rolloutConfig.phaseDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.currentPhaseIndex += 1
                await self?.executeNextRolloutPhase(version: version)
            }
        }
    }
    
    private func executePilotPhase(percentage: Int, version: String) async {
        print("Starting pilot phase: \(percentage)% of devices")
        
        if shouldParticipateInRollout(percentage: percentage) {
            await updateManager.startUpdate(strategy: .immediate)
            startMonitoring(for: version)
        }
        
        await MainActor.run {
            rolloutProgress = Double(percentage) / 100.0
        }
        
        recordSafetyEvent(.rolloutPhaseStarted, version: version, details: [
            "phase": "pilot",
            "percentage": percentage
        ])
    }
    
    private func executeGradualPhase(percentage: Int, version: String) async {
        print("Starting gradual phase: \(percentage)% of devices")
        
        if shouldParticipateInRollout(percentage: percentage) {
            await updateManager.startUpdate(strategy: .gradual(percentage: percentage))
        }
        
        await MainActor.run {
            rolloutProgress = Double(percentage) / 100.0
        }
        
        recordSafetyEvent(.rolloutPhaseStarted, version: version, details: [
            "phase": "gradual",
            "percentage": percentage
        ])
    }
    
    private func executeFullRollout(version: String) async {
        print("Starting full rollout: 100% of devices")
        
        await updateManager.startUpdate(strategy: .immediate)
        
        await MainActor.run {
            rolloutProgress = 1.0
        }
        
        recordSafetyEvent(.rolloutPhaseStarted, version: version, details: [
            "phase": "full",
            "percentage": 100
        ])
    }
    
    private func performSafetyCheck() async {
        guard isMonitoring else { return }
        
        let metrics = getCurrentSafetyMetrics()
        var warnings: [String] = []
        var criticalIssues: [String] = []
        
        // Check each safety threshold
        for threshold in safetyThresholds {
            let currentValue = getMetricValue(threshold.metric, from: metrics)
            
            if currentValue >= threshold.criticalLevel {
                criticalIssues.append("Critical: \(threshold.metric) at \(currentValue)")
            } else if currentValue >= threshold.warningLevel {
                warnings.append("Warning: \(threshold.metric) at \(currentValue)")
            }
        }
        
        // Update safety status
        await MainActor.run {
            if !criticalIssues.isEmpty {
                safetyStatus = .critical(criticalIssues.joined(separator: ", "))
            } else if !warnings.isEmpty {
                safetyStatus = .warning(warnings.joined(separator: ", "))
            } else {
                safetyStatus = .safe
            }
        }
        
        // Trigger automatic rollback if critical issues detected
        if !criticalIssues.isEmpty {
            await triggerAutomaticRollback(reason: criticalIssues.joined(separator: ", "))
        }
        
        // Log safety check
        recordSafetyEvent(.safetyCheckPerformed, version: updateManager.currentVersion ?? "unknown", details: [
            "warnings": warnings,
            "criticalIssues": criticalIssues,
            "metrics": metrics
        ])
    }
    
    private func triggerAutomaticRollback(reason: String) async {
        guard case .safe = safetyStatus || case .warning(_) = safetyStatus else {
            return // Rollback already in progress
        }
        
        print("Triggering automatic rollback due to: \(reason)")
        
        await MainActor.run {
            rolloutPhase = .paused(reason: reason)
        }
        
        _ = await forceRollback(reason: "Automatic safety rollback: \(reason)")
    }
    
    // MARK: - Metric Calculations
    
    private func calculateSuccessRate() -> Double {
        guard performanceMonitor.totalRequests > 0 else { return 1.0 }
        return Double(performanceMonitor.successfulRequests) / Double(performanceMonitor.totalRequests)
    }
    
    private func calculateErrorRate() -> Double {
        guard performanceMonitor.totalRequests > 0 else { return 0.0 }
        return Double(performanceMonitor.failedRequests) / Double(performanceMonitor.totalRequests)
    }
    
    private func calculateCrashRate() -> Double {
        guard performanceMonitor.totalRequests > 0 else { return 0.0 }
        return Double(performanceMonitor.crashes) / Double(performanceMonitor.totalRequests)
    }
    
    private func getMetricValue(_ metric: SafetyMetric, from metrics: [String: Any]) -> Double {
        switch metric {
        case .crashRate:
            return metrics["crashRate"] as? Double ?? 0.0
        case .errorRate:
            return metrics["errorRate"] as? Double ?? 0.0
        case .performanceRegression:
            let avgTime = metrics["averageResponseTime"] as? TimeInterval ?? 0.0
            // Compare with baseline (simplified)
            return avgTime > 1.0 ? avgTime - 1.0 : 0.0
        case .userFeedback:
            return 1.0 - (metrics["userFeedbackScore"] as? Double ?? 0.8)
        case .batteryImpact:
            return metrics["batteryDrainRate"] as? Double ?? 0.0
        case .memoryUsage:
            let usage = metrics["memoryPeakUsage"] as? Int64 ?? 0
            let maxMemory: Int64 = 512 * 1024 * 1024 // 512MB baseline
            return Double(usage) / Double(maxMemory)
        }
    }
    
    private func updateAverageResponseTime(_ responseTime: TimeInterval) {
        let totalTime = performanceMonitor.averageResponseTime * Double(performanceMonitor.successfulRequests - 1)
        performanceMonitor.averageResponseTime = (totalTime + responseTime) / Double(performanceMonitor.successfulRequests)
    }
    
    private func updateUserFeedbackScore(_ score: Double) {
        // Exponential moving average
        let alpha = 0.1
        performanceMonitor.userFeedbackScore = alpha * score + (1 - alpha) * performanceMonitor.userFeedbackScore
    }
    
    private func recordFailure(error: Error) {
        // Log specific error types for analysis
        let errorType = String(describing: type(of: error))
        
        recordSafetyEvent(.errorRecorded, version: updateManager.currentVersion ?? "unknown", details: [
            "errorType": errorType,
            "errorDescription": error.localizedDescription
        ])
    }
    
    // MARK: - Safety Event Logging
    
    private enum SafetyEventType {
        case monitoringStarted
        case rolloutPhaseStarted  
        case safetyCheckPerformed
        case errorRecorded
        case rollbackCompleted
    }
    
    private func recordSafetyEvent(_ eventType: SafetyEventType, version: String, details: [String: Any]) {
        let event: [String: Any] = [
            "timestamp": Date(),
            "eventType": String(describing: eventType),
            "version": version,
            "deviceId": deviceId,
            "details": details
        ]
        
        // In a real implementation, this would be sent to a logging service
        print("Safety Event: \(event)")
        
        // Store locally for debugging
        UserDefaults.standard.set(event, forKey: "lastSafetyEvent")
    }
    
    // MARK: - Background Task Management
    
    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ModelSafetyMonitoring") {
            self.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // MARK: - Persistence
    
    private func loadMonitoringState() {
        // Load previous monitoring state if app was backgrounded
        if let savedState = UserDefaults.standard.dictionary(forKey: "ModelSafetyMonitoringState") {
            // Restore state if needed
        }
    }
    
    private func saveMonitoringState() {
        let state: [String: Any] = [
            "isMonitoring": isMonitoring,
            "rolloutPhase": String(describing: rolloutPhase),
            "performanceMonitor": [
                "startTime": performanceMonitor.startTime,
                "totalRequests": performanceMonitor.totalRequests,
                "successfulRequests": performanceMonitor.successfulRequests,
                "failedRequests": performanceMonitor.failedRequests
            ]
        ]
        
        UserDefaults.standard.set(state, forKey: "ModelSafetyMonitoringState")
    }
    
    // MARK: - Notification Handlers
    
    @objc private func appDidEnterBackground() {
        saveMonitoringState()
    }
    
    @objc private func appWillEnterForeground() {
        loadMonitoringState()
    }
    
    @objc private func memoryWarningReceived() {
        recordPerformanceEvent(.memoryPeakRecorded(usage: Int64(ProcessInfo.processInfo.physicalMemory)))
    }
    
    @objc private func automaticRollbackTriggered(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo["reason"] as? String else {
            return
        }
        
        Task { @MainActor in
            await triggerAutomaticRollback(reason: reason)
        }
    }
}