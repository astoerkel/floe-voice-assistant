import Foundation
import UIKit
import Network
import CoreML

// MARK: - Supporting Types

public enum ProcessorThermalState: Int, CaseIterable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3
    
    var description: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious" 
        case .critical: return "Critical"
        }
    }
}

/// Decision engine for intelligent processing routing
public class ProcessingDecisionEngine: ObservableObject {
    
    // MARK: - Configuration
    private var configuration: ProcessingDecisionConfiguration
    
    // MARK: - Monitoring
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ProcessingDecisionEngine")
    
    // MARK: - State
    @Published public var currentNetworkQuality: NetworkQuality = .unavailable
    @Published public var currentBatteryLevel: Float = 1.0
    @Published public var currentThermalState: ProcessorThermalState = .nominal
    @Published public var currentMemoryPressure: Float = 0.0
    
    // MARK: - Analytics
    private var decisionHistory: [ProcessingDecision] = []
    private let maxHistorySize = 100
    
    public init(configuration: ProcessingDecisionConfiguration = .default) {
        self.configuration = configuration
        startMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Main Decision Making
    
    /// Make intelligent processing decision based on multiple factors
    public func makeProcessingDecision(
        text: String,
        audioData: Data? = nil,
        context: VoiceProcessingContext
    ) async -> ProcessingDecision {
        
        let startTime = Date()
        
        // Step 1: Assess query complexity
        let complexityScore = assessQueryComplexity(text: text, audioData: audioData)
        
        // Step 2: Evaluate resource constraints
        let resourceConstraints = getCurrentResourceConstraints()
        
        // Step 3: Check privacy requirements
        let privacyRequired = assessPrivacyRequirements(text: text, context: context)
        
        // Step 4: Assess on-device capability
        let onDeviceCapability = assessOnDeviceCapability(
            text: text,
            complexityScore: complexityScore,
            resourceConstraints: resourceConstraints
        )
        
        // Step 5: Evaluate network conditions
        let networkConditions = assessNetworkConditions()
        
        // Step 6: Apply user preferences
        let userPreferences = getUserPreferences()
        
        // Step 7: Make final decision
        let recommendedLocation = determineOptimalLocation(
            complexityScore: complexityScore,
            onDeviceCapability: onDeviceCapability,
            resourceConstraints: resourceConstraints,
            privacyRequired: privacyRequired,
            networkConditions: networkConditions,
            userPreferences: userPreferences
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        let decision = ProcessingDecision(
            recommendedLocation: recommendedLocation,
            complexityScore: complexityScore,
            onDeviceCapability: onDeviceCapability,
            resourceConstraints: resourceConstraints,
            privacyRequired: privacyRequired,
            networkConditions: networkConditions,
            confidence: calculateDecisionConfidence(
                location: recommendedLocation,
                factors: (complexityScore, onDeviceCapability, resourceConstraints, privacyRequired, networkConditions)
            ),
            reasoning: generateDecisionReasoning(
                location: recommendedLocation,
                complexityScore: complexityScore,
                onDeviceCapability: onDeviceCapability,
                resourceConstraints: resourceConstraints,
                privacyRequired: privacyRequired,
                networkConditions: networkConditions
            ),
            decisionTime: processingTime,
            timestamp: Date()
        )
        
        // Store decision for analytics
        recordDecision(decision)
        
        return decision
    }
    
    // MARK: - Complexity Assessment
    
    private func assessQueryComplexity(text: String, audioData: Data?) -> Double {
        var complexity = 0.0
        
        // Text-based complexity factors
        let words = text.split(separator: " ")
        let wordCount = words.count
        let avgWordLength = words.map { $0.count }.reduce(0, +) / max(wordCount, 1)
        let hasQuestions = text.contains("?") || text.lowercased().hasPrefix("what") || text.lowercased().hasPrefix("how")
        let hasComplexPhrases = detectComplexPhrases(in: text)
        let hasNumbers = text.rangeOfCharacter(from: .decimalDigits) != nil
        let hasProperNouns = detectProperNouns(in: text)
        
        // Base complexity from word count (0.0 - 0.4)
        complexity += min(Double(wordCount) / 50.0, 0.4)
        
        // Word length complexity (0.0 - 0.2)
        complexity += min(Double(avgWordLength) / 25.0, 0.2)
        
        // Question complexity (0.15)
        if hasQuestions {
            complexity += 0.15
        }
        
        // Complex phrases (0.1)
        if hasComplexPhrases {
            complexity += 0.1
        }
        
        // Numbers complexity (0.05)
        if hasNumbers {
            complexity += 0.05
        }
        
        // Proper nouns complexity (0.1)
        if hasProperNouns {
            complexity += 0.1
        }
        
        // Audio complexity
        if let audioData = audioData {
            let audioDuration = estimateAudioDuration(audioData)
            complexity += min(audioDuration / 30.0, 0.2) // Max 0.2 for 30+ seconds
        }
        
        return min(complexity, 1.0)
    }
    
    private func detectComplexPhrases(in text: String) -> Bool {
        let complexPhrases = [
            "explain", "analyze", "compare", "summarize", "translate",
            "research", "investigate", "calculate complex", "detailed",
            "comprehensive", "in-depth", "thorough"
        ]
        
        let lowercaseText = text.lowercased()
        return complexPhrases.contains { lowercaseText.contains($0) }
    }
    
    private func detectProperNouns(in text: String) -> Bool {
        let words = text.split(separator: " ")
        return words.contains { word in
            let firstChar = word.first
            return firstChar?.isUppercase == true && word.count > 2
        }
    }
    
    private func estimateAudioDuration(_ audioData: Data) -> Double {
        // Rough estimate: 1 second of M4A audio ≈ 8KB
        return Double(audioData.count) / 8192.0
    }
    
    // MARK: - Resource Assessment
    
    private func getCurrentResourceConstraints() -> ResourceConstraints {
        updateDeviceMetrics()
        
        return ResourceConstraints(
            batteryLevel: currentBatteryLevel,
            networkQuality: currentNetworkQuality,
            memoryPressure: currentMemoryPressure,
            thermalState: thermalStateToString(currentThermalState)
        )
    }
    
    private func updateDeviceMetrics() {
        // Battery level
        UIDevice.current.isBatteryMonitoringEnabled = true
        currentBatteryLevel = UIDevice.current.batteryLevel
        
        // Thermal state
        let thermalState = ProcessInfo.processInfo.thermalState
        currentThermalState = ProcessorThermalState(rawValue: thermalState.rawValue) ?? .nominal
        
        // Memory pressure (simplified)
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemoryMB = Double(memoryInfo.resident_size) / 1024.0 / 1024.0
            currentMemoryPressure = Float(min(usedMemoryMB / 1024.0, 1.0)) // Normalize to 0-1
        }
    }
    
    private func thermalStateToString(_ state: ProcessorThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
    
    // MARK: - Network Assessment
    
    private func startMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.currentNetworkQuality = self?.assessNetworkQuality(path) ?? .unavailable
            }
        }
        networkMonitor.start(queue: queue)
    }
    
    private func assessNetworkQuality(_ path: NWPath) -> NetworkQuality {
        guard path.status == .satisfied else {
            return .unavailable
        }
        
        if path.isExpensive {
            return .fair // Cellular
        }
        
        if path.usesInterfaceType(.wifi) {
            return .excellent
        } else if path.usesInterfaceType(.cellular) {
            return .good
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .excellent
        }
        
        return .fair
    }
    
    private func assessNetworkConditions() -> NetworkConditions {
        return NetworkConditions(
            quality: currentNetworkQuality,
            isMetered: networkMonitor.currentPath.isExpensive,
            estimatedBandwidth: estimateBandwidth(),
            latency: estimateLatency()
        )
    }
    
    private func estimateBandwidth() -> Double {
        // Simplified bandwidth estimation based on connection type
        switch currentNetworkQuality {
        case .excellent: return 100.0 // Mbps
        case .good: return 50.0
        case .fair: return 10.0
        case .poor: return 1.0
        case .unavailable: return 0.0
        }
    }
    
    private func estimateLatency() -> Double {
        // Simplified latency estimation in milliseconds
        switch currentNetworkQuality {
        case .excellent: return 20.0
        case .good: return 50.0
        case .fair: return 150.0
        case .poor: return 500.0
        case .unavailable: return 10000.0
        }
    }
    
    // MARK: - Privacy Assessment
    
    private func assessPrivacyRequirements(text: String, context: VoiceProcessingContext) -> Bool {
        // Check for privacy-sensitive content
        let privacySensitiveKeywords = [
            "password", "ssn", "social security", "credit card", "personal",
            "private", "confidential", "secret", "address", "phone number",
            "email", "bank", "account", "medical", "health"
        ]
        
        let lowercaseText = text.lowercased()
        let containsSensitiveInfo = privacySensitiveKeywords.contains { lowercaseText.contains($0) }
        
        // Check user privacy preferences
        let userPrefersPrivacy = configuration.privacyMode == .maximum
        
        return containsSensitiveInfo || userPrefersPrivacy
    }
    
    // MARK: - On-Device Capability Assessment
    
    private func assessOnDeviceCapability(
        text: String,
        complexityScore: Double,
        resourceConstraints: ResourceConstraints
    ) -> Double {
        
        var capability = 1.0 // Start with full capability
        
        // Reduce based on complexity
        capability -= min(complexityScore * 0.5, 0.4)
        
        // Reduce based on battery level
        if resourceConstraints.batteryLevel < 0.2 {
            capability -= 0.3
        } else if resourceConstraints.batteryLevel < 0.5 {
            capability -= 0.1
        }
        
        // Reduce based on thermal state
        switch currentThermalState {
        case .serious:
            capability -= 0.2
        case .critical:
            capability -= 0.5
        default:
            break
        }
        
        // Reduce based on memory pressure
        if resourceConstraints.memoryPressure > 0.8 {
            capability -= 0.3
        } else if resourceConstraints.memoryPressure > 0.6 {
            capability -= 0.1
        }
        
        // Check for supported capabilities
        let supportedCapabilities = getSupportedCapabilities(for: text)
        if supportedCapabilities.isEmpty {
            capability -= 0.4
        }
        
        return max(capability, 0.0)
    }
    
    private func getSupportedCapabilities(for text: String) -> [OnDeviceCapability] {
        var capabilities: [OnDeviceCapability] = []
        let lowercaseText = text.lowercased()
        
        if lowercaseText.contains("time") || lowercaseText.contains("date") {
            capabilities.append(.timeQueries)
        }
        
        if lowercaseText.contains("calculate") || lowercaseText.contains("math") {
            capabilities.append(.basicCalculations)
        }
        
        if lowercaseText.contains("calendar") || lowercaseText.contains("meeting") {
            capabilities.append(.cachedCalendar)
        }
        
        if lowercaseText.contains("contact") || lowercaseText.contains("call") {
            capabilities.append(.cachedContacts)
        }
        
        if lowercaseText.contains("weather") {
            capabilities.append(.cachedWeather)
        }
        
        if lowercaseText.contains("reminder") || lowercaseText.contains("note") {
            capabilities.append(.simpleReminders)
        }
        
        return capabilities
    }
    
    // MARK: - User Preferences
    
    private func getUserPreferences() -> UserProcessingPreferences {
        return UserProcessingPreferences(
            preferOnDevice: configuration.preferOnDevice,
            privacyMode: configuration.privacyMode,
            costOptimization: configuration.costOptimization,
            batteryOptimization: configuration.batteryOptimization
        )
    }
    
    // MARK: - Decision Logic
    
    private func determineOptimalLocation(
        complexityScore: Double,
        onDeviceCapability: Double,
        resourceConstraints: ResourceConstraints,
        privacyRequired: Bool,
        networkConditions: NetworkConditions,
        userPreferences: UserProcessingPreferences
    ) -> ProcessingLocation {
        
        // Privacy override - always prefer on-device for sensitive content
        if privacyRequired && onDeviceCapability > 0.3 {
            return .onDevice
        }
        
        // Network unavailable - must use on-device
        if networkConditions.quality == .unavailable {
            return onDeviceCapability > 0.2 ? .onDevice : .fallback
        }
        
        // Low on-device capability - prefer server
        if onDeviceCapability < 0.2 {
            return networkConditions.quality != .unavailable ? .server : .fallback
        }
        
        // High complexity with poor network - use on-device if capable
        if complexityScore > 0.7 && networkConditions.quality == .poor {
            return onDeviceCapability > 0.5 ? .onDevice : .fallback
        }
        
        // Battery optimization mode
        if userPreferences.batteryOptimization && resourceConstraints.batteryLevel < 0.3 {
            return networkConditions.quality >= .good ? .server : .fallback
        }
        
        // Privacy mode preferences
        switch userPreferences.privacyMode {
        case .maximum:
            return onDeviceCapability > 0.3 ? .onDevice : .fallback
        case .performance:
            return networkConditions.quality >= .good ? .server : .onDevice
        case .balanced:
            break // Continue with balanced logic
        }
        
        // Balanced decision making
        let onDeviceScore = calculateOnDeviceScore(
            capability: onDeviceCapability,
            complexity: complexityScore,
            resources: resourceConstraints
        )
        
        let serverScore = calculateServerScore(
            complexity: complexityScore,
            network: networkConditions,
            privacy: privacyRequired
        )
        
        let hybridScore = calculateHybridScore(
            onDeviceScore: onDeviceScore,
            serverScore: serverScore,
            complexity: complexityScore
        )
        
        // Choose the highest scoring option
        let maxScore = max(onDeviceScore, serverScore, hybridScore)
        
        if maxScore == hybridScore && maxScore > 0.6 {
            return .hybrid
        } else if maxScore == onDeviceScore {
            return .onDevice
        } else if maxScore == serverScore {
            return .server
        } else {
            return .fallback
        }
    }
    
    private func calculateOnDeviceScore(
        capability: Double,
        complexity: Double,
        resources: ResourceConstraints
    ) -> Double {
        var score = capability
        
        // Bonus for low complexity
        if complexity < 0.3 {
            score += 0.2
        }
        
        // Penalty for resource constraints
        if resources.batteryLevel < 0.2 {
            score -= 0.3
        }
        
        if currentThermalState == .serious || currentThermalState == .critical {
            score -= 0.2
        }
        
        return max(score, 0.0)
    }
    
    private func calculateServerScore(
        complexity: Double,
        network: NetworkConditions,
        privacy: Bool
    ) -> Double {
        var score = 0.7 // Base server capability
        
        // Bonus for high complexity
        if complexity > 0.6 {
            score += 0.2
        }
        
        // Network quality impact
        switch network.quality {
        case .excellent:
            score += 0.2
        case .good:
            score += 0.1
        case .fair:
            score -= 0.1
        case .poor:
            score -= 0.3
        case .unavailable:
            score = 0.0
        }
        
        // Privacy penalty
        if privacy {
            score -= 0.4
        }
        
        // Metered connection penalty
        if network.isMetered {
            score -= 0.2
        }
        
        return max(score, 0.0)
    }
    
    private func calculateHybridScore(
        onDeviceScore: Double,
        serverScore: Double,
        complexity: Double
    ) -> Double {
        // Hybrid is good when both options are viable
        let minScore = min(onDeviceScore, serverScore)
        let avgScore = (onDeviceScore + serverScore) / 2.0
        
        // Hybrid works best for medium complexity
        let complexityBonus = complexity > 0.3 && complexity < 0.7 ? 0.1 : 0.0
        
        return minScore * 0.7 + avgScore * 0.3 + complexityBonus
    }
    
    // MARK: - Decision Confidence & Reasoning
    
    private func calculateDecisionConfidence(
        location: ProcessingLocation,
        factors: (Double, Double, ResourceConstraints, Bool, NetworkConditions)
    ) -> Double {
        let (complexity, capability, resources, privacy, network) = factors
        
        var confidence = 0.5 // Base confidence
        
        switch location {
        case .onDevice:
            confidence += capability * 0.3
            if privacy { confidence += 0.2 }
            if resources.batteryLevel > 0.5 { confidence += 0.1 }
            if complexity < 0.5 { confidence += 0.1 }
            
        case .server:
            if network.quality == .excellent { confidence += 0.3 }
            else if network.quality == .good { confidence += 0.2 }
            if complexity > 0.6 { confidence += 0.2 }
            if !privacy { confidence += 0.1 }
            
        case .hybrid:
            confidence += (capability + min(0.8, Double(network.quality.hashValue) / 4.0)) * 0.15
            
        case .fallback:
            confidence = 0.3 // Low confidence for fallback
        }
        
        return min(confidence, 1.0)
    }
    
    private func generateDecisionReasoning(
        location: ProcessingLocation,
        complexityScore: Double,
        onDeviceCapability: Double,
        resourceConstraints: ResourceConstraints,
        privacyRequired: Bool,
        networkConditions: NetworkConditions
    ) -> [String] {
        var reasoning: [String] = []
        
        switch location {
        case .onDevice:
            reasoning.append("On-device processing selected")
            if privacyRequired {
                reasoning.append("Privacy-sensitive content detected")
            }
            if onDeviceCapability > 0.7 {
                reasoning.append("High on-device capability")
            }
            if complexityScore < 0.4 {
                reasoning.append("Low query complexity")
            }
            if networkConditions.quality == .poor || networkConditions.quality == .unavailable {
                reasoning.append("Poor network conditions")
            }
            
        case .server:
            reasoning.append("Server processing selected")
            if complexityScore > 0.6 {
                reasoning.append("High query complexity requires advanced AI")
            }
            if networkConditions.quality == .excellent {
                reasoning.append("Excellent network conditions")
            }
            if onDeviceCapability < 0.3 {
                reasoning.append("Limited on-device capability")
            }
            
        case .hybrid:
            reasoning.append("Hybrid processing selected")
            reasoning.append("Both on-device and server processing viable")
            if complexityScore > 0.3 && complexityScore < 0.7 {
                reasoning.append("Medium complexity suitable for hybrid approach")
            }
            
        case .fallback:
            reasoning.append("Fallback processing selected")
            if networkConditions.quality == .unavailable {
                reasoning.append("No network connection available")
            }
            if onDeviceCapability < 0.2 {
                reasoning.append("Insufficient on-device capability")
            }
        }
        
        return reasoning
    }
    
    // MARK: - Analytics & History
    
    private func recordDecision(_ decision: ProcessingDecision) {
        decisionHistory.append(decision)
        
        // Keep history size manageable
        if decisionHistory.count > maxHistorySize {
            decisionHistory.removeFirst(decisionHistory.count - maxHistorySize)
        }
    }
    
    public func getDecisionAnalytics() -> DecisionAnalytics {
        let recentDecisions = Array(decisionHistory.suffix(50))
        
        let locationCounts = recentDecisions.reduce(into: [ProcessingLocation: Int]()) { counts, decision in
            counts[decision.recommendedLocation, default: 0] += 1
        }
        
        let avgConfidence = recentDecisions.map { $0.confidence }.reduce(0, +) / Double(max(recentDecisions.count, 1))
        let avgDecisionTime = recentDecisions.map { $0.decisionTime }.reduce(0, +) / Double(max(recentDecisions.count, 1))
        
        return DecisionAnalytics(
            totalDecisions: decisionHistory.count,
            recentDecisions: recentDecisions.count,
            locationDistribution: locationCounts,
            averageConfidence: avgConfidence,
            averageDecisionTime: avgDecisionTime,
            mostCommonReasons: getMostCommonReasons(from: recentDecisions)
        )
    }
    
    private func getMostCommonReasons(from decisions: [ProcessingDecision]) -> [String] {
        let allReasons = decisions.flatMap { $0.reasoning }
        let reasonCounts = allReasons.reduce(into: [String: Int]()) { counts, reason in
            counts[reason, default: 0] += 1
        }
        
        return reasonCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    // MARK: - Configuration Management
    
    public func updateConfiguration(_ newConfiguration: ProcessingDecisionConfiguration) {
        self.configuration = newConfiguration
    }
}

// MARK: - Supporting Types

/// Processing decision result
public struct ProcessingDecision {
    public let recommendedLocation: ProcessingLocation
    public let complexityScore: Double
    public let onDeviceCapability: Double
    public let resourceConstraints: ResourceConstraints
    public let privacyRequired: Bool
    public let networkConditions: NetworkConditions
    public let confidence: Double
    public let reasoning: [String]
    public let decisionTime: TimeInterval
    public let timestamp: Date
    
    public static func onDeviceFallback() -> ProcessingDecision {
        return ProcessingDecision(
            recommendedLocation: .onDevice,
            complexityScore: 0.0,
            onDeviceCapability: 1.0,
            resourceConstraints: ResourceConstraints(batteryLevel: 1.0, networkQuality: .unavailable, memoryPressure: 0.0, thermalState: "nominal"),
            privacyRequired: false,
            networkConditions: NetworkConditions(quality: .unavailable, isMetered: false, estimatedBandwidth: 0, latency: 0),
            confidence: 0.8,
            reasoning: ["Fallback to on-device processing"],
            decisionTime: 0.001,
            timestamp: Date()
        )
    }
    
    public static func basicFallback() -> ProcessingDecision {
        return ProcessingDecision(
            recommendedLocation: .fallback,
            complexityScore: 0.0,
            onDeviceCapability: 0.0,
            resourceConstraints: ResourceConstraints(batteryLevel: 0.0, networkQuality: .unavailable, memoryPressure: 1.0, thermalState: "critical"),
            privacyRequired: false,
            networkConditions: NetworkConditions(quality: .unavailable, isMetered: false, estimatedBandwidth: 0, latency: 0),
            confidence: 0.3,
            reasoning: ["Basic fallback processing only"],
            decisionTime: 0.001,
            timestamp: Date()
        )
    }
}

/// Network conditions assessment
public struct NetworkConditions {
    public let quality: NetworkQuality
    public let isMetered: Bool
    public let estimatedBandwidth: Double // Mbps
    public let latency: Double // milliseconds
}

/// User processing preferences
public struct UserProcessingPreferences {
    public let preferOnDevice: Bool
    public let privacyMode: PrivacyMode
    public let costOptimization: Bool
    public let batteryOptimization: Bool
}

/// Processing decision configuration
public struct ProcessingDecisionConfiguration {
    public let preferOnDevice: Bool
    public let batteryThreshold: Float
    public let networkQualityThreshold: NetworkQuality
    public let privacyMode: PrivacyMode
    public let costOptimization: Bool
    public let batteryOptimization: Bool
    
    public static let `default` = ProcessingDecisionConfiguration(
        preferOnDevice: true,
        batteryThreshold: 0.2,
        networkQualityThreshold: .good,
        privacyMode: .balanced,
        costOptimization: true,
        batteryOptimization: true
    )
}

/// Decision analytics
public struct DecisionAnalytics {
    public let totalDecisions: Int
    public let recentDecisions: Int
    public let locationDistribution: [ProcessingLocation: Int]
    public let averageConfidence: Double
    public let averageDecisionTime: TimeInterval
    public let mostCommonReasons: [String]
}