import Foundation
import Combine
import os.log

/// Local usage insights tracking with privacy-preserving analytics
/// Tracks most used commands, peak usage times, feature adoption, and personalization effectiveness
@MainActor
public class UsageInsights: ObservableObject {
    
    // MARK: - Types
    
    public struct CommandUsage {
        let command: String
        let count: Int
        let lastUsed: Date
        let averageConfidence: Double
        let successRate: Double
        let category: CommandCategory
        
        public init(command: String, count: Int, lastUsed: Date, averageConfidence: Double, successRate: Double, category: CommandCategory) {
            self.command = command
            self.count = count
            self.lastUsed = lastUsed
            self.averageConfidence = averageConfidence
            self.successRate = successRate
            self.category = category
        }
    }
    
    public struct PeakUsageTime {
        let hour: Int
        let usageCount: Int
        let averageResponseTime: TimeInterval
        let primaryCommands: [String]
        
        public var displayHour: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "ha"
            let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
            return formatter.string(from: date)
        }
        
        public init(hour: Int, usageCount: Int, averageResponseTime: TimeInterval, primaryCommands: [String]) {
            self.hour = hour
            self.usageCount = usageCount
            self.averageResponseTime = averageResponseTime
            self.primaryCommands = primaryCommands
        }
    }
    
    public struct FeatureAdoption {
        let featureName: String
        let adoptionRate: Double
        let firstUsed: Date?
        let lastUsed: Date?
        let usageGrowth: Double
        let userSatisfaction: Double
        
        public init(featureName: String, adoptionRate: Double, firstUsed: Date?, lastUsed: Date?, usageGrowth: Double, userSatisfaction: Double) {
            self.featureName = featureName
            self.adoptionRate = adoptionRate
            self.firstUsed = firstUsed
            self.lastUsed = lastUsed
            self.usageGrowth = usageGrowth
            self.userSatisfaction = userSatisfaction
        }
    }
    
    public struct PersonalizationEffectiveness {
        let responseAdaptationRate: Double
        let userCorrectionFrequency: Double
        let preferenceAccuracy: Double
        let contextAwareness: Double
        let improvementOverTime: Double
        
        public init(responseAdaptationRate: Double, userCorrectionFrequency: Double, preferenceAccuracy: Double, contextAwareness: Double, improvementOverTime: Double) {
            self.responseAdaptationRate = responseAdaptationRate
            self.userCorrectionFrequency = userCorrectionFrequency
            self.preferenceAccuracy = preferenceAccuracy
            self.contextAwareness = contextAwareness
            self.improvementOverTime = improvementOverTime
        }
    }
    
    public struct UsageSession {
        let id: UUID
        let startTime: Date
        let endTime: Date?
        let commandCount: Int
        let averageResponseTime: TimeInterval
        let successfulCommands: Int
        let context: SessionContext
        
        public var duration: TimeInterval {
            return (endTime ?? Date()).timeIntervalSince(startTime)
        }
        
        public var successRate: Double {
            return commandCount > 0 ? Double(successfulCommands) / Double(commandCount) : 0.0
        }
        
        public init(startTime: Date, context: SessionContext) {
            self.id = UUID()
            self.startTime = startTime
            self.endTime = nil
            self.commandCount = 0
            self.averageResponseTime = 0
            self.successfulCommands = 0
            self.context = context
        }
    }
    
    public enum CommandCategory: String, CaseIterable {
        case calendar = "calendar"
        case email = "email"
        case tasks = "tasks"
        case weather = "weather"
        case time = "time"
        case general = "general"
        case device = "device"
        case unknown = "unknown"
        
        public var displayName: String {
            return rawValue.capitalized
        }
    }
    
    public enum SessionContext: String {
        case morning = "morning"
        case afternoon = "afternoon"
        case evening = "evening"
        case night = "night"
        case weekend = "weekend"
        case workday = "workday"
    }
    
    // MARK: - Published Properties
    
    @Published public private(set) var mostUsedCommands: [CommandUsage] = []
    @Published public private(set) var peakUsageTimes: [PeakUsageTime] = []
    @Published public private(set) var featureAdoption: [FeatureAdoption] = []
    @Published public private(set) var personalizationEffectiveness: PersonalizationEffectiveness
    @Published public private(set) var totalCommandsToday: Int = 0
    @Published public private(set) var averageSessionLength: TimeInterval = 0
    @Published public private(set) var isTracking: Bool = false
    @Published public private(set) var lastUpdateDate: Date?
    
    // MARK: - Private Properties
    
    private var commandHistory: [CommandHistoryEntry] = []
    private var sessions: [UsageSession] = []
    private var currentSession: UsageSession?
    private var featureUsage: [String: FeatureUsageData] = [:]
    private var personalizationData: PersonalizationTrackingData
    
    private let maxHistoryEntries = 50000
    private let dataRetentionDays = 90
    private let updateInterval: TimeInterval = 300 // 5 minutes
    private var updateTimer: Timer?
    
    private let logger = Logger(subsystem: "com.voiceassistant.analytics", category: "UsageInsights")
    private let differentialPrivacy: DifferentialPrivacyManager
    
    // MARK: - Initialization
    
    public init(differentialPrivacy: DifferentialPrivacyManager = DifferentialPrivacyManager()) {
        self.differentialPrivacy = differentialPrivacy
        self.personalizationEffectiveness = PersonalizationEffectiveness(
            responseAdaptationRate: 0.0,
            userCorrectionFrequency: 0.0,
            preferenceAccuracy: 0.0,
            contextAwareness: 0.0,
            improvementOverTime: 0.0
        )
        self.personalizationData = PersonalizationTrackingData()
        
        loadPersistedData()
    }
    
    deinit {
        updateTimer?.invalidate()
        endCurrentSession()
        persistData()
    }
    
    // MARK: - Public Interface
    
    /// Start usage tracking
    public func startTracking() {
        guard !isTracking else { return }
        
        isTracking = true
        startNewSession()
        startUpdateTimer()
        
        logger.info("Started usage insights tracking")
    }
    
    /// Stop usage tracking
    public func stopTracking() {
        guard isTracking else { return }
        
        isTracking = false
        updateTimer?.invalidate()
        endCurrentSession()
        persistData()
        
        logger.info("Stopped usage insights tracking")
    }
    
    /// Record a command usage
    public func recordCommand(
        _ command: String,
        category: CommandCategory = .unknown,
        confidence: Double,
        responseTime: TimeInterval,
        success: Bool,
        context: [String: Any] = [:]
    ) {
        guard isTracking else { return }
        
        let entry = CommandHistoryEntry(
            command: command,
            category: category,
            confidence: confidence,
            responseTime: responseTime,
            success: success,
            context: context,
            timestamp: Date()
        )
        
        addCommandEntry(entry)
        updateCurrentSession(with: entry)
        
        logger.debug("Recorded command: \(command), success: \(success), confidence: \(confidence)")
    }
    
    /// Record feature usage
    public func recordFeatureUsage(
        _ featureName: String,
        satisfaction: Double? = nil,
        context: [String: Any] = [:]
    ) {
        guard isTracking else { return }
        
        if featureUsage[featureName] == nil {
            featureUsage[featureName] = FeatureUsageData(
                name: featureName,
                firstUsed: Date(),
                usageCount: 0,
                satisfactionScores: [],
                contexts: []
            )
        }
        
        featureUsage[featureName]?.usageCount += 1
        featureUsage[featureName]?.lastUsed = Date()
        
        if let satisfaction = satisfaction {
            featureUsage[featureName]?.satisfactionScores.append(satisfaction)
        }
        
        featureUsage[featureName]?.contexts.append(context)
        
        // Limit stored contexts to prevent memory bloat
        if let count = featureUsage[featureName]?.contexts.count, count > 100 {
            featureUsage[featureName]?.contexts.removeFirst()
        }
        
        logger.debug("Recorded feature usage: \(featureName)")
    }
    
    /// Record personalization event
    public func recordPersonalizationEvent(
        type: PersonalizationEventType,
        effectiveness: Double,
        userCorrection: Bool = false,
        contextMatch: Bool = true
    ) {
        guard isTracking else { return }
        
        let event = PersonalizationEvent(
            type: type,
            effectiveness: effectiveness,
            userCorrection: userCorrection,
            contextMatch: contextMatch,
            timestamp: Date()
        )
        
        personalizationData.events.append(event)
        
        // Limit stored events
        if personalizationData.events.count > 1000 {
            personalizationData.events.removeFirst()
        }
        
        logger.debug("Recorded personalization event: \(type.rawValue)")
    }
    
    /// Get usage insights for specific command
    public func getCommandInsights(for command: String) -> CommandInsights? {
        let entries = commandHistory.filter { $0.command == command }
        guard !entries.isEmpty else { return nil }
        
        let totalCount = entries.count
        let successCount = entries.filter { $0.success }.count
        let avgConfidence = entries.map { $0.confidence }.reduce(0, +) / Double(entries.count)
        let avgResponseTime = entries.map { $0.responseTime }.reduce(0, +) / Double(entries.count)
        let lastUsed = entries.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date()
        
        let hourlyUsage = Dictionary(grouping: entries) { entry in
            Calendar.current.component(.hour, from: entry.timestamp)
        }.mapValues { $0.count }
        
        return CommandInsights(
            command: command,
            totalUsage: totalCount,
            successRate: Double(successCount) / Double(totalCount),
            averageConfidence: avgConfidence,
            averageResponseTime: avgResponseTime,
            lastUsed: lastUsed,
            hourlyDistribution: hourlyUsage,
            trendingUp: calculateTrend(for: entries)
        )
    }
    
    /// Get privacy-preserving usage statistics
    public func getPrivateUsageStatistics() async throws -> [String: Any] {
        let commands = commandHistory.map { $0.command }
        let timestamps = commandHistory.map { $0.timestamp }
        
        return try differentialPrivacy.createUsageStatistics(
            commands: commands,
            timestamps: timestamps
        )
    }
    
    /// Export usage data for user review
    public func exportUsageData() throws -> Data {
        let exportData = UsageInsightsExport(
            commandUsage: mostUsedCommands,
            peakTimes: peakUsageTimes,
            featureAdoption: featureAdoption,
            personalization: personalizationEffectiveness,
            sessions: sessions.suffix(50).map { $0 }, // Last 50 sessions
            exportDate: Date(),
            dataRetentionDays: dataRetentionDays,
            privacyLevel: "high"
        )
        
        return try JSONEncoder().encode(exportData)
    }
    
    /// Clear all usage data
    public func clearUsageData() {
        commandHistory.removeAll()
        sessions.removeAll()
        currentSession = nil
        featureUsage.removeAll()
        personalizationData = PersonalizationTrackingData()
        
        mostUsedCommands.removeAll()
        peakUsageTimes.removeAll()
        featureAdoption.removeAll()
        personalizationEffectiveness = PersonalizationEffectiveness(
            responseAdaptationRate: 0.0,
            userCorrectionFrequency: 0.0,
            preferenceAccuracy: 0.0,
            contextAwareness: 0.0,
            improvementOverTime: 0.0
        )
        
        totalCommandsToday = 0
        averageSessionLength = 0
        lastUpdateDate = nil
        
        persistData()
        logger.info("Cleared all usage data")
    }
    
    // MARK: - Private Methods
    
    private func addCommandEntry(_ entry: CommandHistoryEntry) {
        commandHistory.append(entry)
        
        // Maintain history limit
        if commandHistory.count > maxHistoryEntries {
            commandHistory.removeFirst(commandHistory.count - maxHistoryEntries)
        }
        
        // Clean up old entries based on retention policy
        cleanupOldEntries()
    }
    
    private func cleanupOldEntries() {
        let cutoffDate = Date().addingTimeInterval(-Double(dataRetentionDays) * 24 * 3600)
        commandHistory.removeAll { $0.timestamp < cutoffDate }
        sessions.removeAll { $0.startTime < cutoffDate }
    }
    
    private func startNewSession() {
        endCurrentSession()
        
        let context = determineCurrentContext()
        currentSession = UsageSession(startTime: Date(), context: context)
        
        logger.debug("Started new usage session with context: \(context.rawValue)")
    }
    
    private func endCurrentSession() {
        guard var session = currentSession else { return }
        
        // Update session with final data
        session = UsageSession(
            id: session.id,
            startTime: session.startTime,
            endTime: Date(),
            commandCount: session.commandCount,
            averageResponseTime: session.averageResponseTime,
            successfulCommands: session.successfulCommands,
            context: session.context
        )
        
        sessions.append(session)
        currentSession = nil
        
        logger.debug("Ended usage session: \(session.commandCount) commands, \(session.duration)s duration")
    }
    
    private func updateCurrentSession(with entry: CommandHistoryEntry) {
        guard var session = currentSession else { return }
        
        let newCommandCount = session.commandCount + 1
        let newSuccessfulCommands = session.successfulCommands + (entry.success ? 1 : 0)
        let newAverageResponseTime = (session.averageResponseTime * Double(session.commandCount) + entry.responseTime) / Double(newCommandCount)
        
        currentSession = UsageSession(
            id: session.id,
            startTime: session.startTime,
            endTime: session.endTime,
            commandCount: newCommandCount,
            averageResponseTime: newAverageResponseTime,
            successfulCommands: newSuccessfulCommands,
            context: session.context
        )
    }
    
    private func determineCurrentContext() -> SessionContext {
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date())
        
        // Weekend vs workday
        if weekday == 1 || weekday == 7 {
            return .weekend
        }
        
        // Time of day
        switch hour {
        case 6..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<22:
            return .evening
        default:
            return .night
        }
    }
    
    private func startUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateInsights()
            }
        }
    }
    
    private func updateInsights() {
        updateMostUsedCommands()
        updatePeakUsageTimes()
        updateFeatureAdoption()
        updatePersonalizationEffectiveness()
        updateDailySummary()
        
        lastUpdateDate = Date()
        persistData()
        
        logger.debug("Updated usage insights")
    }
    
    private func updateMostUsedCommands() {
        let commandGroups = Dictionary(grouping: commandHistory) { $0.command }
        
        mostUsedCommands = commandGroups.compactMap { (command, entries) in
            let count = entries.count
            let lastUsed = entries.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date()
            let avgConfidence = entries.map { $0.confidence }.reduce(0, +) / Double(entries.count)
            let successCount = entries.filter { $0.success }.count
            let successRate = Double(successCount) / Double(entries.count)
            let category = entries.first?.category ?? .unknown
            
            return CommandUsage(
                command: command,
                count: count,
                lastUsed: lastUsed,
                averageConfidence: avgConfidence,
                successRate: successRate,
                category: category
            )
        }.sorted { $0.count > $1.count }
    }
    
    private func updatePeakUsageTimes() {
        let hourGroups = Dictionary(grouping: commandHistory) { entry in
            Calendar.current.component(.hour, from: entry.timestamp)
        }
        
        peakUsageTimes = hourGroups.compactMap { (hour, entries) in
            let count = entries.count
            let avgResponseTime = entries.map { $0.responseTime }.reduce(0, +) / Double(entries.count)
            let commandCounts = Dictionary(entries.map { ($0.command, 1) }, uniquingKeysWith: +)
            let topCommands = commandCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
            
            return PeakUsageTime(
                hour: hour,
                usageCount: count,
                averageResponseTime: avgResponseTime,
                primaryCommands: Array(topCommands)
            )
        }.sorted { $0.usageCount > $1.usageCount }
    }
    
    private func updateFeatureAdoption() {
        let totalSessions = max(sessions.count, 1)
        
        featureAdoption = featureUsage.values.compactMap { usage in
            let adoptionRate = Double(usage.usageCount) / Double(totalSessions)
            let avgSatisfaction = usage.satisfactionScores.isEmpty ? 0.0 : 
                usage.satisfactionScores.reduce(0, +) / Double(usage.satisfactionScores.count)
            
            // Calculate usage growth (simplified)
            let recentUsage = usage.contexts.suffix(10).count
            let olderUsage = usage.contexts.prefix(usage.contexts.count - recentUsage).count
            let usageGrowth = olderUsage > 0 ? Double(recentUsage - olderUsage) / Double(olderUsage) : 0.0
            
            return FeatureAdoption(
                featureName: usage.name,
                adoptionRate: adoptionRate,
                firstUsed: usage.firstUsed,
                lastUsed: usage.lastUsed,
                usageGrowth: usageGrowth,
                userSatisfaction: avgSatisfaction
            )
        }.sorted { $0.adoptionRate > $1.adoptionRate }
    }
    
    private func updatePersonalizationEffectiveness() {
        let events = personalizationData.events
        guard !events.isEmpty else { return }
        
        let responseAdaptationEvents = events.filter { $0.type == .responseAdaptation }
        let correctionEvents = events.filter { $0.userCorrection }
        let contextEvents = events.filter { $0.contextMatch }
        
        let adaptationRate = responseAdaptationEvents.map { $0.effectiveness }.reduce(0, +) / Double(max(responseAdaptationEvents.count, 1))
        let correctionFrequency = Double(correctionEvents.count) / Double(events.count)
        let contextAwareness = Double(contextEvents.count) / Double(events.count)
        
        // Calculate improvement over time (compare recent vs older events)
        let recentEvents = events.suffix(events.count / 2)
        let olderEvents = events.prefix(events.count / 2)
        
        let recentEffectiveness = recentEvents.map { $0.effectiveness }.reduce(0, +) / Double(max(recentEvents.count, 1))
        let olderEffectiveness = olderEvents.map { $0.effectiveness }.reduce(0, +) / Double(max(olderEvents.count, 1))
        let improvement = recentEffectiveness - olderEffectiveness
        
        personalizationEffectiveness = PersonalizationEffectiveness(
            responseAdaptationRate: adaptationRate,
            userCorrectionFrequency: correctionFrequency,
            preferenceAccuracy: adaptationRate,
            contextAwareness: contextAwareness,
            improvementOverTime: improvement
        )
    }
    
    private func updateDailySummary() {
        let today = Calendar.current.startOfDay(for: Date())
        let todayEntries = commandHistory.filter { 
            Calendar.current.startOfDay(for: $0.timestamp) == today 
        }
        
        totalCommandsToday = todayEntries.count
        
        if !sessions.isEmpty {
            averageSessionLength = sessions.map { $0.duration }.reduce(0, +) / Double(sessions.count)
        }
    }
    
    private func calculateTrend(for entries: [CommandHistoryEntry]) -> Bool {
        guard entries.count >= 10 else { return false }
        
        let recentEntries = Array(entries.suffix(5))
        let olderEntries = Array(entries.prefix(entries.count - 5).suffix(5))
        
        return recentEntries.count > olderEntries.count
    }
    
    private func persistData() {
        let data = UsageInsightsData(
            commandHistory: Array(commandHistory.suffix(1000)), // Store last 1000 entries
            sessions: Array(sessions.suffix(100)), // Store last 100 sessions
            featureUsage: featureUsage,
            personalizationData: personalizationData,
            lastUpdate: lastUpdateDate
        )
        
        do {
            let encoded = try JSONEncoder().encode(data)
            UserDefaults.standard.set(encoded, forKey: "UsageInsights.data")
            logger.debug("Persisted usage insights data")
        } catch {
            logger.error("Failed to persist usage insights data: \(error)")
        }
    }
    
    private func loadPersistedData() {
        guard let data = UserDefaults.standard.data(forKey: "UsageInsights.data") else {
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode(UsageInsightsData.self, from: data)
            commandHistory = decoded.commandHistory
            sessions = decoded.sessions
            featureUsage = decoded.featureUsage
            personalizationData = decoded.personalizationData
            lastUpdateDate = decoded.lastUpdate
            
            // Update insights based on loaded data
            updateInsights()
            
            logger.debug("Loaded persisted usage insights data")
        } catch {
            logger.error("Failed to load persisted usage insights data: \(error)")
        }
    }
}

// MARK: - Supporting Types

private struct CommandHistoryEntry: Codable {
    let command: String
    let category: UsageInsights.CommandCategory
    let confidence: Double
    let responseTime: TimeInterval
    let success: Bool
    let context: [String: AnyCodable] // Use AnyCodable for flexible context storage
    let timestamp: Date
    
    init(command: String, category: UsageInsights.CommandCategory, confidence: Double, responseTime: TimeInterval, success: Bool, context: [String: Any], timestamp: Date) {
        self.command = command
        self.category = category
        self.confidence = confidence
        self.responseTime = responseTime
        self.success = success
        self.context = context.mapValues { AnyCodable($0) }
        self.timestamp = timestamp
    }
}

private struct FeatureUsageData: Codable {
    let name: String
    let firstUsed: Date
    var lastUsed: Date?
    var usageCount: Int
    var satisfactionScores: [Double]
    var contexts: [[String: AnyCodable]]
    
    init(name: String, firstUsed: Date, usageCount: Int, satisfactionScores: [Double], contexts: [[String: Any]]) {
        self.name = name
        self.firstUsed = firstUsed
        self.usageCount = usageCount
        self.satisfactionScores = satisfactionScores
        self.contexts = contexts.map { $0.mapValues { AnyCodable($0) } }
    }
}

private struct PersonalizationTrackingData: Codable {
    var events: [PersonalizationEvent] = []
}

private struct PersonalizationEvent: Codable {
    let type: PersonalizationEventType
    let effectiveness: Double
    let userCorrection: Bool
    let contextMatch: Bool
    let timestamp: Date
}

public enum PersonalizationEventType: String, Codable {
    case responseAdaptation = "response_adaptation"
    case contextLearning = "context_learning"
    case preferenceUpdate = "preference_update"
    case vocabularyLearning = "vocabulary_learning"
}

public struct CommandInsights {
    let command: String
    let totalUsage: Int
    let successRate: Double
    let averageConfidence: Double
    let averageResponseTime: TimeInterval
    let lastUsed: Date
    let hourlyDistribution: [Int: Int]
    let trendingUp: Bool
}

private struct UsageInsightsData: Codable {
    let commandHistory: [CommandHistoryEntry]
    let sessions: [UsageInsights.UsageSession]
    let featureUsage: [String: FeatureUsageData]
    let personalizationData: PersonalizationTrackingData
    let lastUpdate: Date?
}

private struct UsageInsightsExport: Codable {
    let commandUsage: [UsageInsights.CommandUsage]
    let peakTimes: [UsageInsights.PeakUsageTime]
    let featureAdoption: [UsageInsights.FeatureAdoption]
    let personalization: UsageInsights.PersonalizationEffectiveness
    let sessions: [UsageInsights.UsageSession]
    let exportDate: Date
    let dataRetentionDays: Int
    let privacyLevel: String
}

// Helper for encoding Any values in Codable contexts
private struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            value = try container.decode(String.self)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else {
            try container.encode(String(describing: value))
        }
    }
}

// MARK: - Extensions

extension UsageInsights.CommandUsage: Codable {}
extension UsageInsights.PeakUsageTime: Codable {}
extension UsageInsights.FeatureAdoption: Codable {}
extension UsageInsights.PersonalizationEffectiveness: Codable {}
extension UsageInsights.UsageSession: Codable {}
extension UsageInsights.CommandCategory: Codable {}
extension UsageInsights.SessionContext: Codable {}

// Custom initializer for UsageSession to handle mutable fields
extension UsageInsights.UsageSession {
    init(id: UUID, startTime: Date, endTime: Date?, commandCount: Int, averageResponseTime: TimeInterval, successfulCommands: Int, context: UsageInsights.SessionContext) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.commandCount = commandCount
        self.averageResponseTime = averageResponseTime
        self.successfulCommands = successfulCommands
        self.context = context
    }
}