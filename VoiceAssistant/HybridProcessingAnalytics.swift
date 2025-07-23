import Foundation
import SwiftUI

/// Analytics system for hybrid processing tracking
public class HybridProcessingAnalytics: ObservableObject {
    
    public static let shared = HybridProcessingAnalytics()
    
    // MARK: - Published State
    @Published public var currentStats: ProcessingAnalyticsData = ProcessingAnalyticsData()
    @Published public var dailyStats: [Date: ProcessingAnalyticsData] = [:]
    @Published public var weeklyTrends: WeeklyTrends = WeeklyTrends()
    @Published public var costSavings: CostSavingsData = CostSavingsData()
    
    // MARK: - Storage
    private let userDefaults = UserDefaults.standard
    private let analyticsKey = "HybridProcessingAnalytics"
    private let maxDailyEntries = 30 // Keep 30 days of data
    
    // MARK: - Event Tracking
    private var events: [ProcessingEvent] = []
    private let maxEvents = 1000
    
    private init() {
        loadPersistedData()
        startDailyReset()
    }
    
    // MARK: - Event Recording
    
    /// Record a processing event for analytics
    public func recordProcessingEvent(
        location: ProcessingLocation,
        decision: ProcessingDecision?,
        result: HybridProcessingResult?,
        success: Bool,
        error: Error? = nil
    ) async {
        
        let event = ProcessingEvent(
            id: UUID(),
            timestamp: Date(),
            location: location,
            success: success,
            processingTime: result?.processingTime ?? 0,
            confidence: result?.confidence ?? 0,
            cost: result?.cost ?? 0,
            privacyScore: result?.privacyScore ?? 1.0,
            complexityScore: decision?.complexityScore ?? 0,
            batteryLevel: decision?.resourceConstraints.batteryLevel ?? 1.0,
            networkQuality: decision?.networkConditions.quality ?? .unavailable,
            decisionReasoning: decision?.reasoning ?? [],
            errorType: error?.localizedDescription
        )
        
        await MainActor.run {
            recordEvent(event)
            updateCurrentStats()
            updateWeeklyTrends()
            updateCostSavings()
            persistData()
        }
    }
    
    private func recordEvent(_ event: ProcessingEvent) {
        events.append(event)
        
        // Keep events list manageable
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }
    
    // MARK: - Statistics Calculation
    
    private func updateCurrentStats() {
        let today = Calendar.current.startOfDay(for: Date())
        let todayEvents = events.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: today) }
        
        currentStats = ProcessingAnalyticsData(from: todayEvents)
        dailyStats[today] = currentStats
        
        // Clean up old daily stats
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxDailyEntries, to: today) ?? today
        dailyStats = dailyStats.filter { $0.key >= cutoffDate }
    }
    
    private func updateWeeklyTrends() {
        let calendar = Calendar.current
        let now = Date()
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        let weekEvents = events.filter { $0.timestamp >= oneWeekAgo }
        
        weeklyTrends = WeeklyTrends(
            totalProcessings: weekEvents.count,
            onDeviceRatio: calculateLocationRatio(weekEvents, location: .onDevice),
            serverRatio: calculateLocationRatio(weekEvents, location: .server),
            hybridRatio: calculateLocationRatio(weekEvents, location: .hybrid),
            averageConfidence: weekEvents.map { $0.confidence }.average(),
            averageProcessingTime: weekEvents.map { $0.processingTime }.average(),
            successRate: Double(weekEvents.filter { $0.success }.count) / Double(weekEvents.count),
            dailyBreakdown: calculateDailyBreakdown(weekEvents)
        )
    }
    
    private func updateCostSavings() {
        let monthEvents = events.filter { 
            Calendar.current.isDate($0.timestamp, equalTo: Date(), toGranularity: .month)
        }
        
        let onDeviceCost = monthEvents.filter { $0.location == .onDevice }.map { $0.cost }.reduce(0, +)
        let serverCost = monthEvents.filter { $0.location == .server }.map { $0.cost }.reduce(0, +)
        let hybridCost = monthEvents.filter { $0.location == .hybrid }.map { $0.cost }.reduce(0, +)
        
        // Estimate what it would have cost if everything was processed on server
        let estimatedServerOnlyCost = Double(monthEvents.count) * 0.01 // $0.01 per request estimate
        let actualCost = onDeviceCost + serverCost + hybridCost
        
        costSavings = CostSavingsData(
            monthlyOnDeviceCost: onDeviceCost,
            monthlyServerCost: serverCost,
            monthlyHybridCost: hybridCost,
            totalMonthlyCost: actualCost,
            estimatedServerOnlyCost: estimatedServerOnlyCost,
            monthlySavings: max(0, estimatedServerOnlyCost - actualCost),
            savingsPercentage: estimatedServerOnlyCost > 0 ? 
                ((estimatedServerOnlyCost - actualCost) / estimatedServerOnlyCost) * 100 : 0
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculateLocationRatio(_ events: [ProcessingEvent], location: ProcessingLocation) -> Double {
        guard !events.isEmpty else { return 0.0 }
        let locationCount = events.filter { $0.location == location }.count
        return Double(locationCount) / Double(events.count)
    }
    
    private func calculateDailyBreakdown(_ events: [ProcessingEvent]) -> [Date: DailyProcessingData] {
        let groupedByDay = Dictionary(grouping: events) { event in
            Calendar.current.startOfDay(for: event.timestamp)
        }
        
        return groupedByDay.mapValues { dayEvents in
            DailyProcessingData(
                totalProcessings: dayEvents.count,
                onDeviceCount: dayEvents.filter { $0.location == .onDevice }.count,
                serverCount: dayEvents.filter { $0.location == .server }.count,
                hybridCount: dayEvents.filter { $0.location == .hybrid }.count,
                averageConfidence: dayEvents.map { $0.confidence }.average(),
                successRate: Double(dayEvents.filter { $0.success }.count) / Double(dayEvents.count)
            )
        }
    }
    
    // MARK: - Data Persistence
    
    private func persistData() {
        let data = PersistentAnalyticsData(
            events: Array(events.suffix(500)), // Keep only recent events
            dailyStats: dailyStats
        )
        
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.set(encoded, forKey: analyticsKey)
        }
    }
    
    private func loadPersistedData() {
        guard let data = userDefaults.data(forKey: analyticsKey),
              let decoded = try? JSONDecoder().decode(PersistentAnalyticsData.self, from: data) else {
            return
        }
        
        events = decoded.events
        dailyStats = decoded.dailyStats
        
        updateCurrentStats()
        updateWeeklyTrends()
        updateCostSavings()
    }
    
    private func startDailyReset() {
        // Reset daily stats at midnight
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            let now = Date()
            let calendar = Calendar.current
            
            if calendar.component(.hour, from: now) == 0 && 
               calendar.component(.minute, from: now) == 0 {
                Task {
                    await MainActor.run {
                        self.updateCurrentStats()
                        self.persistData()
                    }
                }
            }
        }
    }
    
    // MARK: - Public Analytics Interface
    
    /// Get comprehensive analytics report
    public func getAnalyticsReport() -> AnalyticsReport {
        return AnalyticsReport(
            currentStats: currentStats,
            weeklyTrends: weeklyTrends,
            costSavings: costSavings,
            topDecisionReasons: getTopDecisionReasons(),
            networkQualityImpact: getNetworkQualityImpact(),
            batteryImpactAnalysis: getBatteryImpactAnalysis(),
            privacyScore: getOverallPrivacyScore(),
            performanceMetrics: getPerformanceMetrics()
        )
    }
    
    /// Get decision reasoning analytics
    public func getTopDecisionReasons(limit: Int = 5) -> [ReasonAnalytics] {
        let allReasons = events.flatMap { $0.decisionReasoning }
        let reasonCounts = Dictionary(allReasons.map { ($0, 1) }, uniquingKeysWith: +)
        
        return reasonCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ReasonAnalytics(reason: $0.key, count: $0.value, percentage: Double($0.value) / Double(events.count)) }
    }
    
    /// Get network quality impact analysis
    public func getNetworkQualityImpact() -> NetworkQualityImpact {
        let networkGroups = Dictionary(grouping: events) { $0.networkQuality }
        
        var impacts: [NetworkQuality: NetworkImpactData] = [:]
        
        for (quality, qualityEvents) in networkGroups {
            let onDeviceRatio = calculateLocationRatio(qualityEvents, location: .onDevice)
            let serverRatio = calculateLocationRatio(qualityEvents, location: .server)
            let avgProcessingTime = qualityEvents.map { $0.processingTime }.average()
            let successRate = Double(qualityEvents.filter { $0.success }.count) / Double(qualityEvents.count)
            
            impacts[quality] = NetworkImpactData(
                onDeviceRatio: onDeviceRatio,
                serverRatio: serverRatio,
                averageProcessingTime: avgProcessingTime,
                successRate: successRate,
                sampleSize: qualityEvents.count
            )
        }
        
        return NetworkQualityImpact(impacts: impacts)
    }
    
    /// Get battery impact analysis
    public func getBatteryImpactAnalysis() -> BatteryImpactAnalysis {
        let lowBatteryEvents = events.filter { $0.batteryLevel < 0.3 }
        let highBatteryEvents = events.filter { $0.batteryLevel >= 0.7 }
        
        return BatteryImpactAnalysis(
            lowBatteryOnDeviceRatio: calculateLocationRatio(lowBatteryEvents, location: .onDevice),
            highBatteryOnDeviceRatio: calculateLocationRatio(highBatteryEvents, location: .onDevice),
            batteryOptimizationSavings: calculateBatteryOptimizationSavings(),
            averageProcessingTimeByBattery: calculateProcessingTimeByBattery()
        )
    }
    
    private func calculateBatteryOptimizationSavings() -> Double {
        // Estimate battery savings from on-device processing
        let onDeviceEvents = events.filter { $0.location == .onDevice }
        return Double(onDeviceEvents.count) * 0.001 // Rough estimate: 0.1% battery per on-device request saved
    }
    
    private func calculateProcessingTimeByBattery() -> [String: Double] {
        let lowBattery = events.filter { $0.batteryLevel < 0.3 }.map { $0.processingTime }.average()
        let mediumBattery = events.filter { $0.batteryLevel >= 0.3 && $0.batteryLevel < 0.7 }.map { $0.processingTime }.average()
        let highBattery = events.filter { $0.batteryLevel >= 0.7 }.map { $0.processingTime }.average()
        
        return [
            "low": lowBattery,
            "medium": mediumBattery,
            "high": highBattery
        ]
    }
    
    /// Get overall privacy score
    public func getOverallPrivacyScore() -> Double {
        return events.map { $0.privacyScore }.average()
    }
    
    /// Get performance metrics
    public func getPerformanceMetrics() -> HybridPerformanceMetrics {
        let avgProcessingTime = events.map { $0.processingTime }.average()
        let avgConfidence = events.map { $0.confidence }.average()
        let successRate = Double(events.filter { $0.success }.count) / Double(events.count)
        
        let onDeviceEvents = events.filter { $0.location == .onDevice }
        let serverEvents = events.filter { $0.location == .server }
        let hybridEvents = events.filter { $0.location == .hybrid }
        
        return HybridPerformanceMetrics(
            overallAverageProcessingTime: avgProcessingTime,
            overallAverageConfidence: avgConfidence,
            overallSuccessRate: successRate,
            onDevicePerformance: PerformanceData(
                averageProcessingTime: onDeviceEvents.map { $0.processingTime }.average(),
                averageConfidence: onDeviceEvents.map { $0.confidence }.average(),
                successRate: Double(onDeviceEvents.filter { $0.success }.count) / Double(onDeviceEvents.count)
            ),
            serverPerformance: PerformanceData(
                averageProcessingTime: serverEvents.map { $0.processingTime }.average(),
                averageConfidence: serverEvents.map { $0.confidence }.average(),
                successRate: Double(serverEvents.filter { $0.success }.count) / Double(serverEvents.count)
            ),
            hybridPerformance: PerformanceData(
                averageProcessingTime: hybridEvents.map { $0.processingTime }.average(),
                averageConfidence: hybridEvents.map { $0.confidence }.average(),
                successRate: Double(hybridEvents.filter { $0.success }.count) / Double(hybridEvents.count)
            )
        )
    }
    
    // MARK: - Data Export
    
    /// Export analytics data for user
    public func exportAnalyticsData() -> Data? {
        let exportData = HybridAnalyticsExportData(
            exportDate: Date(),
            totalEvents: events.count,
            dateRange: events.isEmpty ? nil : AnalyticsDateRange(startDate: events.first!.timestamp, endDate: events.last!.timestamp),
            currentStats: currentStats,
            weeklyTrends: weeklyTrends,
            costSavings: costSavings,
            analyticsReport: getAnalyticsReport()
        )
        
        return try? JSONEncoder().encode(exportData)
    }
    
    /// Clear all analytics data
    public func clearAnalyticsData() {
        events.removeAll()
        dailyStats.removeAll()
        currentStats = ProcessingAnalyticsData()
        weeklyTrends = WeeklyTrends()
        costSavings = CostSavingsData()
        
        userDefaults.removeObject(forKey: analyticsKey)
    }
}

// MARK: - Supporting Types

/// Individual processing event
private struct ProcessingEvent: Codable {
    let id: UUID
    let timestamp: Date
    let location: ProcessingLocation
    let success: Bool
    let processingTime: TimeInterval
    let confidence: Double
    let cost: Double
    let privacyScore: Double
    let complexityScore: Double
    let batteryLevel: Float
    let networkQuality: NetworkQuality
    let decisionReasoning: [String]
    let errorType: String?
}

/// Current analytics data
public struct ProcessingAnalyticsData: Codable {
    public let totalProcessings: Int
    public let successfulProcessings: Int
    public let onDeviceCount: Int
    public let serverCount: Int
    public let hybridCount: Int
    public let fallbackCount: Int
    public let averageProcessingTime: Double
    public let averageConfidence: Double
    public let successRate: Double
    public let onDeviceRatio: Double
    public let averageCost: Double
    public let averagePrivacyScore: Double
    
    init() {
        self.totalProcessings = 0
        self.successfulProcessings = 0
        self.onDeviceCount = 0
        self.serverCount = 0
        self.hybridCount = 0
        self.fallbackCount = 0
        self.averageProcessingTime = 0
        self.averageConfidence = 0
        self.successRate = 0
        self.onDeviceRatio = 0
        self.averageCost = 0
        self.averagePrivacyScore = 1.0
    }
    
    fileprivate init(from events: [ProcessingEvent]) {
        self.totalProcessings = events.count
        self.successfulProcessings = events.filter { $0.success }.count
        self.onDeviceCount = events.filter { $0.location == .onDevice }.count
        self.serverCount = events.filter { $0.location == .server }.count
        self.hybridCount = events.filter { $0.location == .hybrid }.count
        self.fallbackCount = events.filter { $0.location == .fallback }.count
        self.averageProcessingTime = events.map { $0.processingTime }.average()
        self.averageConfidence = events.map { $0.confidence }.average()
        self.successRate = events.isEmpty ? 0 : Double(successfulProcessings) / Double(totalProcessings)
        self.onDeviceRatio = events.isEmpty ? 0 : Double(onDeviceCount) / Double(totalProcessings)
        self.averageCost = events.map { $0.cost }.average()
        self.averagePrivacyScore = events.map { $0.privacyScore }.average()
    }
}

/// Weekly trends data
public struct WeeklyTrends: Codable {
    public let totalProcessings: Int
    public let onDeviceRatio: Double
    public let serverRatio: Double
    public let hybridRatio: Double
    public let averageConfidence: Double
    public let averageProcessingTime: Double
    public let successRate: Double
    public let dailyBreakdown: [Date: DailyProcessingData]
    
    init() {
        self.totalProcessings = 0
        self.onDeviceRatio = 0
        self.serverRatio = 0
        self.hybridRatio = 0
        self.averageConfidence = 0
        self.averageProcessingTime = 0
        self.successRate = 0
        self.dailyBreakdown = [:]
    }
    
    init(totalProcessings: Int, onDeviceRatio: Double, serverRatio: Double, hybridRatio: Double, averageConfidence: Double, averageProcessingTime: Double, successRate: Double, dailyBreakdown: [Date: DailyProcessingData]) {
        self.totalProcessings = totalProcessings
        self.onDeviceRatio = onDeviceRatio
        self.serverRatio = serverRatio
        self.hybridRatio = hybridRatio
        self.averageConfidence = averageConfidence
        self.averageProcessingTime = averageProcessingTime
        self.successRate = successRate
        self.dailyBreakdown = dailyBreakdown
    }
}

/// Daily processing data
public struct DailyProcessingData: Codable {
    public let totalProcessings: Int
    public let onDeviceCount: Int
    public let serverCount: Int
    public let hybridCount: Int
    public let averageConfidence: Double
    public let successRate: Double
}

/// Cost savings data
public struct CostSavingsData: Codable {
    public let monthlyOnDeviceCost: Double
    public let monthlyServerCost: Double
    public let monthlyHybridCost: Double
    public let totalMonthlyCost: Double
    public let estimatedServerOnlyCost: Double
    public let monthlySavings: Double
    public let savingsPercentage: Double
    
    init() {
        self.monthlyOnDeviceCost = 0
        self.monthlyServerCost = 0
        self.monthlyHybridCost = 0
        self.totalMonthlyCost = 0
        self.estimatedServerOnlyCost = 0
        self.monthlySavings = 0
        self.savingsPercentage = 0
    }
    
    init(monthlyOnDeviceCost: Double, monthlyServerCost: Double, monthlyHybridCost: Double, totalMonthlyCost: Double, estimatedServerOnlyCost: Double, monthlySavings: Double, savingsPercentage: Double) {
        self.monthlyOnDeviceCost = monthlyOnDeviceCost
        self.monthlyServerCost = monthlyServerCost
        self.monthlyHybridCost = monthlyHybridCost
        self.totalMonthlyCost = totalMonthlyCost
        self.estimatedServerOnlyCost = estimatedServerOnlyCost
        self.monthlySavings = monthlySavings
        self.savingsPercentage = savingsPercentage
    }
}

/// Comprehensive analytics report
public struct AnalyticsReport: Codable {
    public let currentStats: ProcessingAnalyticsData
    public let weeklyTrends: WeeklyTrends
    public let costSavings: CostSavingsData
    public let topDecisionReasons: [ReasonAnalytics]
    public let networkQualityImpact: NetworkQualityImpact
    public let batteryImpactAnalysis: BatteryImpactAnalysis
    public let privacyScore: Double
    public let performanceMetrics: HybridPerformanceMetrics
}

/// Decision reason analytics
public struct ReasonAnalytics: Codable {
    public let reason: String
    public let count: Int
    public let percentage: Double
}

/// Network quality impact data
public struct NetworkQualityImpact: Codable {
    public let impacts: [NetworkQuality: NetworkImpactData]
}

public struct NetworkImpactData: Codable {
    public let onDeviceRatio: Double
    public let serverRatio: Double
    public let averageProcessingTime: Double
    public let successRate: Double
    public let sampleSize: Int
}

/// Battery impact analysis
public struct BatteryImpactAnalysis: Codable {
    public let lowBatteryOnDeviceRatio: Double
    public let highBatteryOnDeviceRatio: Double
    public let batteryOptimizationSavings: Double
    public let averageProcessingTimeByBattery: [String: Double]
}

/// Hybrid processing performance metrics
public struct HybridPerformanceMetrics: Codable {
    public let overallAverageProcessingTime: Double
    public let overallAverageConfidence: Double
    public let overallSuccessRate: Double
    public let onDevicePerformance: PerformanceData
    public let serverPerformance: PerformanceData
    public let hybridPerformance: PerformanceData
}

public struct PerformanceData: Codable {
    public let averageProcessingTime: Double
    public let averageConfidence: Double
    public let successRate: Double
}

/// Data persistence structure
private struct PersistentAnalyticsData: Codable {
    let events: [ProcessingEvent]
    let dailyStats: [Date: ProcessingAnalyticsData]
}

/// Date range for analytics
public struct AnalyticsDateRange: Codable {
    public let startDate: Date
    public let endDate: Date
    
    public init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
}

/// Hybrid analytics export data structure
public struct HybridAnalyticsExportData: Codable {
    public let exportDate: Date
    public let totalEvents: Int
    public let dateRange: AnalyticsDateRange?
    public let currentStats: ProcessingAnalyticsData
    public let weeklyTrends: WeeklyTrends
    public let costSavings: CostSavingsData
    public let analyticsReport: AnalyticsReport
}

// MARK: - Array Extensions

extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0.0 }
        return reduce(0, +) / Double(count)
    }
}

