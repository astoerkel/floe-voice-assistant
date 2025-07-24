import Foundation
import Network
import UIKit
import SystemConfiguration

@MainActor
class OfflineTransitionManager: ObservableObject {
    
    static let shared = OfflineTransitionManager()
    
    // MARK: - Published Properties
    @Published var currentMode: ProcessingMode = .online
    @Published var transitionState: TransitionState = .idle
    @Published var connectionStatus: ConnectionStatus = ConnectionStatus()
    @Published var featureAvailability: FeatureAvailability = FeatureAvailability()
    @Published var degradedModeActive = false
    @Published var transitionNotifications: [TransitionNotification] = []
    
    // MARK: - Private Properties
    private let networkMonitor = NWPathMonitor()
    private let offlineProcessor: OfflineProcessor
    private let syncManager: SyncManager
    private var networkPath: NWPath?
    private var transitionTimer: Timer?
    private var qualityAssessmentTimer: Timer?
    
    // MARK: - Configuration
    private let transitionThresholds = TransitionThresholds()
    private let qualityAssessmentInterval: TimeInterval = 5.0
    private let gracePeriod: TimeInterval = 3.0 // Wait before switching modes
    
    // MARK: - Data Types
    public enum ProcessingMode {
        case online, offline, hybrid, degraded
        
        var description: String {
            switch self {
            case .online: return "Online Mode"
            case .offline: return "Offline Mode"
            case .hybrid: return "Hybrid Mode"
            case .degraded: return "Degraded Mode"
            }
        }
        
        var icon: String {
            switch self {
            case .online: return "wifi"
            case .offline: return "wifi.slash"
            case .hybrid: return "antenna.radiowaves.left.and.right"
            case .degraded: return "exclamationmark.triangle"
            }
        }
        
        var color: String {
            switch self {
            case .online: return "green"
            case .offline: return "orange"
            case .hybrid: return "blue"
            case .degraded: return "red"
            }
        }
    }
    
    enum TransitionState: Equatable {
        case idle, assessing, transitioning, completed, failed(String)
        
        var description: String {
            switch self {
            case .idle: return "Ready"
            case .assessing: return "Assessing connection..."
            case .transitioning: return "Switching modes..."
            case .completed: return "Mode switched"
            case .failed(let error): return "Failed: \(error)"
            }
        }
    }
    
    public struct ConnectionStatus {
        var isConnected = false
        var quality: ConnectionQuality = .unknown
        var latency: TimeInterval = 0
        var bandwidth: Double = 0 // Mbps
        var stability: Double = 0 // 0-1 scale
        var interfaceType: NWInterface.InterfaceType?
        var lastQualityCheck: Date?
        
        public enum ConnectionQuality {
            case unknown, poor, fair, good, excellent
            
            var threshold: Double {
                switch self {
                case .unknown: return 0.0
                case .poor: return 0.2
                case .fair: return 0.4
                case .good: return 0.6
                case .excellent: return 0.8
                }
            }
            
            var shouldUseOnline: Bool {
                return self == .good || self == .excellent
            }
            
            var supportsHybrid: Bool {
                return self != .unknown && self != .poor
            }
        }
    }
    
    struct FeatureAvailability {
        var voiceProcessing = true
        var realTimeSync = false
        var advancedAI = false
        var mediaStreaming = false
        var backgroundSync = false
        var pushNotifications = false
        var locationServices = true
        var offlineCapabilities = true
        
        mutating func updateForMode(_ mode: ProcessingMode) {
            switch mode {
            case .online:
                realTimeSync = true
                advancedAI = true
                mediaStreaming = true
                backgroundSync = true
                pushNotifications = true
            case .offline:
                realTimeSync = false
                advancedAI = false
                mediaStreaming = false
                backgroundSync = false
                pushNotifications = false
            case .hybrid:
                realTimeSync = true
                advancedAI = true
                mediaStreaming = false
                backgroundSync = true
                pushNotifications = true
            case .degraded:
                realTimeSync = false
                advancedAI = false
                mediaStreaming = false
                backgroundSync = false
                pushNotifications = false
                voiceProcessing = false
            }
        }
    }
    
    struct TransitionNotification: Identifiable {
        let id = UUID()
        let type: NotificationType
        let title: String
        let message: String
        let timestamp: Date
        var isRead = false
        var autoHide = true
        var hideAfter: TimeInterval = 5.0
        
        enum NotificationType {
            case modeChange, degradedMode, connectionRestored, syncCompleted, error
            
            var icon: String {
                switch self {
                case .modeChange: return "arrow.triangle.2.circlepath"
                case .degradedMode: return "exclamationmark.triangle"
                case .connectionRestored: return "wifi"
                case .syncCompleted: return "checkmark.circle"
                case .error: return "xmark.circle"
                }
            }
            
            var priority: Int {
                switch self {
                case .error: return 3
                case .degradedMode: return 2
                case .modeChange, .connectionRestored: return 1
                case .syncCompleted: return 0
                }
            }
        }
    }
    
    struct TransitionThresholds {
        let latencyThreshold: TimeInterval = 2.0 // seconds
        let bandwidthThreshold: Double = 1.0 // Mbps
        let stabilityThreshold: Double = 0.7 // 70%
        let offlineTimeout: TimeInterval = 10.0 // seconds
        let hybridTimeout: TimeInterval = 5.0 // seconds
    }
    
    // MARK: - Initialization
    private init() {
        self.offlineProcessor = OfflineProcessor()
        self.syncManager = SyncManager.shared
        
        setupNetworkMonitoring()
        startQualityAssessment()
        
        // Initial connection assessment
        Task {
            await assessConnectionAndTransition()
        }
    }
    
    // MARK: - Public Interface
    func forceTransition(to mode: ProcessingMode, reason: String = "User requested") async {
        await performTransition(to: mode, reason: reason, forced: true)
    }
    
    func assessConnectionQuality() async -> ConnectionStatus.ConnectionQuality {
        transitionState = .assessing
        
        guard connectionStatus.isConnected else {
            transitionState = .idle
            return .unknown
        }
        
        // Perform network quality tests
        let latency = await measureLatency()
        let bandwidth = await measureBandwidth()
        let stability = await measureStability()
        
        connectionStatus.latency = latency
        connectionStatus.bandwidth = bandwidth
        connectionStatus.stability = stability
        connectionStatus.lastQualityCheck = Date()
        
        // Determine quality based on measurements
        let quality = determineQuality(latency: latency, bandwidth: bandwidth, stability: stability)
        connectionStatus.quality = quality
        
        transitionState = .idle
        return quality
    }
    
    func getRecommendedMode() async -> ProcessingMode {
        guard connectionStatus.isConnected else { return .offline }
        
        let quality = await assessConnectionQuality()
        
        switch quality {
        case .excellent, .good:
            return .online
        case .fair:
            return .hybrid
        case .poor:
            return .offline
        case .unknown:
            return .degraded
        }
    }
    
    func getCurrentCapabilities() -> [String] {
        return offlineProcessor.getAvailableCapabilities().map { $0.description }
    }
    
    func notifyDegradedMode(_ reason: String) {
        degradedModeActive = true
        
        addNotification(
            type: .degradedMode,
            title: "Degraded Mode Active",
            message: reason
        )
        
        // Auto-recover from degraded mode
        Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            if degradedModeActive {
                await attemptRecovery()
            }
        }
    }
    
    func clearNotifications() {
        transitionNotifications.removeAll()
    }
    
    func markNotificationRead(_ notificationId: UUID) {
        if let index = transitionNotifications.firstIndex(where: { $0.id == notificationId }) {
            transitionNotifications[index].isRead = true
        }
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                await self?.handleNetworkPathUpdate(path)
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
        networkMonitor.start(queue: queue)
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) async {
        let wasConnected = connectionStatus.isConnected
        let previousPath = networkPath
        
        networkPath = path
        connectionStatus.isConnected = path.status == .satisfied
        connectionStatus.interfaceType = path.availableInterfaces.first?.type
        
        // Handle connection state changes
        if !wasConnected && connectionStatus.isConnected {
            await handleConnectionRestored()
        } else if wasConnected && !connectionStatus.isConnected {
            await handleConnectionLost()
        } else if connectionStatus.isConnected && pathChanged(from: previousPath, to: path) {
            await handleConnectionTypeChanged()
        }
    }
    
    private func pathChanged(from oldPath: NWPath?, to newPath: NWPath) -> Bool {
        guard let oldPath = oldPath else { return true }
        
        let oldInterface = oldPath.availableInterfaces.first?.type
        let newInterface = newPath.availableInterfaces.first?.type
        
        return oldInterface != newInterface
    }
    
    private func handleConnectionRestored() async {
        addNotification(
            type: .connectionRestored,
            title: "Connection Restored",
            message: "Switching to online mode and syncing data..."
        )
        
        // Give the connection a moment to stabilize
        try? await Task.sleep(nanoseconds: UInt64(gracePeriod * 1_000_000_000))
        
        await assessConnectionAndTransition()
        
        // Start sync process
        await syncManager.syncPendingActions()
        
        degradedModeActive = false
    }
    
    private func handleConnectionLost() async {
        addNotification(
            type: .modeChange,
            title: "Connection Lost",
            message: "Switching to offline mode. Your data will sync when connection is restored."
        )
        
        await performTransition(to: .offline, reason: "Connection lost")
    }
    
    private func handleConnectionTypeChanged() async {
        // Re-assess connection quality when type changes
        await assessConnectionAndTransition()
    }
    
    // MARK: - Quality Assessment
    private func startQualityAssessment() {
        qualityAssessmentTimer = Timer.scheduledTimer(withTimeInterval: qualityAssessmentInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.periodicQualityCheck()
            }
        }
    }
    
    private func periodicQualityCheck() async {
        guard connectionStatus.isConnected else { return }
        guard transitionState == TransitionState.idle else { return }
        
        let quality = await assessConnectionQuality()
        let recommendedMode = await getRecommendedMode()
        
        // Only transition if recommended mode is significantly different
        if shouldTransition(from: currentMode, to: recommendedMode, quality: quality) {
            await performTransition(to: recommendedMode, reason: "Connection quality changed")
        }
    }
    
    private func shouldTransition(from currentMode: ProcessingMode, to recommendedMode: ProcessingMode, quality: ConnectionStatus.ConnectionQuality) -> Bool {
        // Avoid frequent mode switching
        switch (currentMode, recommendedMode) {
        case (.online, .hybrid), (.hybrid, .online):
            // Only switch if quality is stable for a period
            return quality == .excellent || quality == .poor
        case (.offline, .online), (.online, .offline):
            // Always switch for major transitions
            return true
        case (.degraded, _):
            // Always try to recover from degraded mode
            return true
        default:
            return false
        }
    }
    
    // MARK: - Quality Measurement
    private func measureLatency() async -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Ping a reliable server (in real implementation, use your backend)
            let url = URL(string: "https://www.google.com")!
            let request = URLRequest(url: url, timeoutInterval: 5.0)
            _ = try await URLSession.shared.data(for: request)
            
            return CFAbsoluteTimeGetCurrent() - startTime
        } catch {
            return 10.0 // High latency for failed requests
        }
    }
    
    private func measureBandwidth() async -> Double {
        // Simplified bandwidth estimation
        // In a real implementation, you would download a test file and measure speed
        
        guard let interfaceType = connectionStatus.interfaceType else { return 0.0 }
        
        switch interfaceType {
        case .wifi:
            return 50.0 // Assume 50 Mbps for WiFi
        case .cellular:
            return 10.0 // Assume 10 Mbps for cellular
        case .wiredEthernet:
            return 100.0 // Assume 100 Mbps for wired
        default:
            return 1.0 // Conservative estimate for other types
        }
    }
    
    private func measureStability() async -> Double {
        // Measure connection stability over time
        // This would track connection drops, latency variations, etc.
        // For now, return a mock value based on interface type
        
        guard let interfaceType = connectionStatus.interfaceType else { return 0.0 }
        
        switch interfaceType {
        case .wiredEthernet:
            return 0.95
        case .wifi:
            return 0.85
        case .cellular:
            return 0.70
        default:
            return 0.50
        }
    }
    
    private func determineQuality(latency: TimeInterval, bandwidth: Double, stability: Double) -> ConnectionStatus.ConnectionQuality {
        let latencyScore = latency < 0.5 ? 1.0 : (latency < 1.0 ? 0.8 : (latency < 2.0 ? 0.6 : (latency < 5.0 ? 0.4 : 0.2)))
        let bandwidthScore = bandwidth > 20 ? 1.0 : (bandwidth > 10 ? 0.8 : (bandwidth > 5 ? 0.6 : (bandwidth > 1 ? 0.4 : 0.2)))
        let stabilityScore = stability
        
        let overallScore = (latencyScore + bandwidthScore + stabilityScore) / 3.0
        
        switch overallScore {
        case 0.8...1.0:
            return .excellent
        case 0.6..<0.8:
            return .good
        case 0.4..<0.6:
            return .fair
        case 0.2..<0.4:
            return .poor
        default:
            return .unknown
        }
    }
    
    // MARK: - Mode Transitions
    private func assessConnectionAndTransition() async {
        let recommendedMode = await getRecommendedMode()
        
        if currentMode != recommendedMode {
            await performTransition(to: recommendedMode, reason: "Connection assessment")
        }
    }
    
    private func performTransition(to newMode: ProcessingMode, reason: String, forced: Bool = false) async {
        guard transitionState == TransitionState.idle || forced else { return }
        
        let oldMode = currentMode
        transitionState = .transitioning
        
        print("Transitioning from \(oldMode.description) to \(newMode.description). Reason: \(reason)")
        
        do {
            // Prepare for transition
            await prepareForTransition(from: oldMode, to: newMode)
            
            // Update mode
            currentMode = newMode
            
            // Update feature availability
            featureAvailability.updateForMode(newMode)
            
            // Complete transition
            await completeTransition(from: oldMode, to: newMode)
            
            // Notify user
            addNotification(
                type: .modeChange,
                title: "Mode Changed",
                message: "Switched to \(newMode.description). \(getCapabilitiesMessage(for: newMode))"
            )
            
            transitionState = .completed
            
            // Reset to idle after a brief moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.transitionState = .idle
            }
            
            print("Successfully transitioned to \(newMode.description)")
            
        }
    }
    
    private func prepareForTransition(from oldMode: ProcessingMode, to newMode: ProcessingMode) async {
        switch (oldMode, newMode) {
        case (_, .offline):
            // Prepare for offline mode - capabilities are automatically initialized
            break
            
        case (.offline, _):
            // Prepare to go online
            await syncManager.syncPendingActions()
            
        case (_, .degraded):
            // Prepare for degraded mode
            degradedModeActive = true
            
        default:
            break
        }
    }
    
    private func completeTransition(from oldMode: ProcessingMode, to newMode: ProcessingMode) async {
        // Update system settings based on new mode
        await updateSystemSettings(for: newMode)
        
        // Clear degraded mode if transitioning away
        if oldMode == .degraded && newMode != .degraded {
            degradedModeActive = false
        }
        
        // Start/stop background processes as needed
        await configureBackgroundProcesses(for: newMode)
    }
    
    private func updateSystemSettings(for mode: ProcessingMode) async {
        // Configure audio processing
        switch mode {
        case .offline:
            // Use on-device speech recognition only
            UserDefaults.standard.set(true, forKey: "use_offline_speech_only")
        case .online, .hybrid:
            // Use server-assisted speech recognition
            UserDefaults.standard.set(false, forKey: "use_offline_speech_only")
        case .degraded:
            // Minimal processing
            UserDefaults.standard.set(true, forKey: "minimal_processing_mode")
        }
    }
    
    private func configureBackgroundProcesses(for mode: ProcessingMode) async {
        switch mode {
        case .online:
            // Enable all background processes
            syncManager.resumeSync()
            
        case .offline:
            // Pause sync processes
            syncManager.pauseSync()
            
        case .hybrid:
            // Enable selective background processes
            syncManager.resumeSync()
            
        case .degraded:
            // Disable all non-essential processes
            syncManager.pauseSync()
        }
    }
    
    private func attemptRecovery() async {
        guard degradedModeActive else { return }
        
        print("Attempting recovery from degraded mode...")
        
        // Try to assess connection again
        let quality = await assessConnectionQuality()
        
        if quality != .unknown {
            let recommendedMode = await getRecommendedMode()
            await performTransition(to: recommendedMode, reason: "Recovery from degraded mode")
        } else {
            // Schedule another recovery attempt
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                Task {
                    await self.attemptRecovery()
                }
            }
        }
    }
    
    // MARK: - Notifications
    private func addNotification(type: TransitionNotification.NotificationType, title: String, message: String) {
        let notification = TransitionNotification(
            type: type,
            title: title,
            message: message,
            timestamp: Date()
        )
        
        transitionNotifications.append(notification)
        transitionNotifications.sort { $0.type.priority > $1.type.priority }
        
        // Auto-hide notifications
        if notification.autoHide {
            DispatchQueue.main.asyncAfter(deadline: .now() + notification.hideAfter) {
                self.transitionNotifications.removeAll { $0.id == notification.id }
            }
        }
        
        // Haptic feedback for important notifications
        if type.priority >= 2 {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    private func getCapabilitiesMessage(for mode: ProcessingMode) -> String {
        switch mode {
        case .online:
            return "All features available."
        case .offline:
            return "Limited to offline capabilities."
        case .hybrid:
            return "Intelligent online/offline processing."
        case .degraded:
            return "Essential features only."
        }
    }
    
    // MARK: - Cleanup
    deinit {
        networkMonitor.cancel()
        transitionTimer?.invalidate()
        qualityAssessmentTimer?.invalidate()
    }
}