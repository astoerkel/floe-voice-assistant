//
//  OfflineEnhancementManager.swift
//  VoiceAssistant
//
//  Manages enhanced offline capabilities including caching, background sync, and improved intent handling
//

import Foundation
import CoreML
import NaturalLanguage
import BackgroundTasks
import UIKit

@MainActor
class OfflineEnhancementManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var enhancedCacheStatus: CacheStatus = .initializing
    @Published var backgroundSyncEnabled = true
    @Published var smartCachingEnabled = true
    @Published var totalCachedItems = 0
    @Published var lastCacheUpdate: Date?
    
    // MARK: - Enhanced Capabilities
    enum CacheStatus: Equatable {
        case initializing
        case ready
        case updating
        case error(String)
        
        var displayText: String {
            switch self {
            case .initializing: return "Initializing offline cache..."
            case .ready: return "Offline cache ready"
            case .updating: return "Updating cache..."
            case .error(let message): return "Cache error: \(message)"
            }
        }
        
        static func == (lhs: CacheStatus, rhs: CacheStatus) -> Bool {
            switch (lhs, rhs) {
            case (.initializing, .initializing), (.ready, .ready), (.updating, .updating):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    // MARK: - Cache Categories
    struct CachedData {
        let contacts: [Contact]
        let calendarEvents: [CalendarEvent]
        let weatherData: WeatherCache?
        let frequentCommands: [String]
        let userPreferences: [String: Any]
        let lastUpdated: Date
    }
    
    struct Contact {
        let id: String
        let name: String
        let phoneNumbers: [String]
        let emails: [String]
    }
    
    struct WeatherCache {
        let location: String
        let temperature: Double
        let condition: String
        let forecast: [DayForecast]
        let lastUpdated: Date
        
        struct DayForecast {
            let date: Date
            let high: Double
            let low: Double
            let condition: String
        }
    }
    
    // MARK: - Private Properties
    private let cacheManager = SmartCacheManager()
    private let backgroundTaskIdentifier = "com.amitstoerkel.VoiceAssistant.backgroundSync"
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Initialization
    init() {
        setupBackgroundSync()
        initializeCache()
    }
    
    // MARK: - Public Methods
    
    /// Initialize enhanced offline capabilities
    func initializeCache() {
        enhancedCacheStatus = .initializing
        
        Task {
            await cacheManager.initializeCache()
            totalCachedItems = await cacheManager.getTotalCachedItems()
            lastCacheUpdate = await cacheManager.getLastUpdateTime()
            enhancedCacheStatus = .ready
            
            print("✅ OfflineEnhancementManager: Cache initialized with \(totalCachedItems) items")
        }
    }
    
    /// Refresh cached data when online
    func refreshCacheData() {
        guard enhancedCacheStatus != .updating else { return }
        
        enhancedCacheStatus = .updating
        
        Task {
            // Cache contacts
            await cacheManager.cacheContacts()
            
            // Cache calendar events (next 30 days)
            await cacheManager.cacheCalendarEvents()
            
            // Cache weather for current location
            await cacheManager.cacheWeatherData()
            
            // Cache frequently used commands
            await cacheManager.cacheFrequentCommands()
            
            // Update metrics
            totalCachedItems = await cacheManager.getTotalCachedItems()
            lastCacheUpdate = Date()
            enhancedCacheStatus = .ready
            
            print("✅ OfflineEnhancementManager: Cache refresh completed")
        }
    }
    
    /// Get cached data for offline use
    func getCachedData() async -> CachedData? {
        return await cacheManager.getCachedData()
    }
    
    /// Enhanced intent processing with cached data
    func processOfflineIntent(_ text: String, context: VoiceProcessingContext) async -> OfflineResponse {
        // Use cached data to provide more accurate offline responses
        let cachedData = await getCachedData()
        
        // Enhanced intent classification with context
        let intent = await classifyEnhancedIntent(text, context: context, cachedData: cachedData)
        
        switch intent {
        case .contactLookup(let name):
            return await handleContactLookup(name: name, cachedData: cachedData)
        case .calendarQuery(let timeframe):
            return await handleCalendarQuery(timeframe: timeframe, cachedData: cachedData)
        case .weatherQuery:
            return await handleWeatherQuery(cachedData: cachedData)
        case .frequentCommand(let command):
            return await handleFrequentCommand(command, cachedData: cachedData)
        default:
            return OfflineResponse(
                text: "I can help with that, but I need an internet connection for this request.",
                audioBase64: nil,
                confidence: 0.7,
                requiresSync: true
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBackgroundSync() {
        guard backgroundSyncEnabled else { return }
        
        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
    }
    
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await self.performBackgroundCacheUpdate()
            task.setTaskCompleted(success: true)
        }
    }
    
    private func performBackgroundCacheUpdate() async {
        print("🔄 OfflineEnhancementManager: Performing background cache update")
        
        // Update essential cache data in background
        await cacheManager.backgroundUpdateCache()
        
        let items = await cacheManager.getTotalCachedItems()
        await MainActor.run {
            totalCachedItems = items
            lastCacheUpdate = Date()
        }
    }
    
    private func classifyEnhancedIntent(
        _ text: String,
        context: VoiceProcessingContext,
        cachedData: CachedData?
    ) async -> EnhancedOfflineIntent {
        let lowercased = text.lowercased()
        
        // Contact queries
        if lowercased.contains("call") || lowercased.contains("text") || lowercased.contains("contact") {
            let contactName = extractContactName(from: text)
            return .contactLookup(name: contactName)
        }
        
        // Calendar queries
        if lowercased.contains("meeting") || lowercased.contains("calendar") || lowercased.contains("schedule") {
            let timeframe = extractTimeframe(from: text)
            return .calendarQuery(timeframe: timeframe)
        }
        
        // Weather queries
        if lowercased.contains("weather") || lowercased.contains("temperature") {
            return .weatherQuery
        }
        
        // Check if this is a frequent command
        if let cachedData = cachedData,
           cachedData.frequentCommands.contains(where: { $0.lowercased().contains(lowercased) }) {
            return .frequentCommand(text)
        }
        
        // Fallback
        return .general(text)
    }
    
    private func handleContactLookup(name: String, cachedData: CachedData?) async -> OfflineResponse {
        guard let cachedData = cachedData else {
            return OfflineResponse(
                text: "I don't have contact information cached. Please connect to the internet.",
                audioBase64: nil,
                confidence: 0.5,
                requiresSync: true
            )
        }
        
        let matchingContacts = cachedData.contacts.filter { contact in
            contact.name.lowercased().contains(name.lowercased())
        }
        
        if let contact = matchingContacts.first {
            let responseText = "I found \(contact.name). They have \(contact.phoneNumbers.count) phone numbers and \(contact.emails.count) email addresses in your contacts."
            return OfflineResponse(
                text: responseText,
                audioBase64: nil,
                confidence: 0.9,
                requiresSync: false
            )
        } else {
            return OfflineResponse(
                text: "I couldn't find \(name) in your cached contacts.",
                audioBase64: nil,
                confidence: 0.8,
                requiresSync: false
            )
        }
    }
    
    private func handleCalendarQuery(timeframe: String, cachedData: CachedData?) async -> OfflineResponse {
        guard let cachedData = cachedData else {
            return OfflineResponse(
                text: "I don't have calendar data cached. Please connect to the internet.",
                audioBase64: nil,
                confidence: 0.5,
                requiresSync: true
            )
        }
        
        let today = Date()
        let relevantEvents = cachedData.calendarEvents.filter { event in
            Calendar.current.isDate(event.startTime, inSameDayAs: today)
        }
        
        if relevantEvents.isEmpty {
            return OfflineResponse(
                text: "You don't have any events scheduled for today based on your cached calendar.",
                audioBase64: nil,
                confidence: 0.8,
                requiresSync: false
            )
        } else {
            let eventText = relevantEvents.count == 1 ? "1 event" : "\(relevantEvents.count) events"
            return OfflineResponse(
                text: "You have \(eventText) scheduled for today. The first one is \(relevantEvents.first!.title) at \(formatTime(relevantEvents.first!.startTime)).",
                audioBase64: nil,
                confidence: 0.9,
                requiresSync: false
            )
        }
    }
    
    private func handleWeatherQuery(cachedData: CachedData?) async -> OfflineResponse {
        guard let cachedData = cachedData,
              let weather = cachedData.weatherData else {
            return OfflineResponse(
                text: "I don't have weather data cached. Please connect to the internet for current weather.",
                audioBase64: nil,
                confidence: 0.5,
                requiresSync: true
            )
        }
        
        let age = Date().timeIntervalSince(weather.lastUpdated)
        let ageHours = Int(age / 3600)
        
        let responseText = "Based on cached data from \(ageHours) hours ago, it's \(Int(weather.temperature))°F and \(weather.condition) in \(weather.location)."
        
        return OfflineResponse(
            text: responseText,
            audioBase64: nil,
            confidence: 0.7,
            requiresSync: true // Weather should be refreshed when online
        )
    }
    
    private func handleFrequentCommand(_ command: String, cachedData: CachedData?) async -> OfflineResponse {
        // Handle frequently used commands with cached responses
        return OfflineResponse(
            text: "I've noted your request for '\(command)'. I'll process this when we're back online.",
            audioBase64: nil,
            confidence: 0.8,
            requiresSync: true
        )
    }
    
    // MARK: - Helper Methods
    
    private func extractContactName(from text: String) -> String {
        // Simple extraction - could be enhanced with NLP
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        if let callIndex = words.firstIndex(where: { $0.lowercased().contains("call") }),
           callIndex + 1 < words.count {
            return words[callIndex + 1]
        }
        return "someone"
    }
    
    private func extractTimeframe(from text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("today") { return "today" }
        if lowercased.contains("tomorrow") { return "tomorrow" }
        if lowercased.contains("week") { return "this week" }
        return "today"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

enum EnhancedOfflineIntent {
    case contactLookup(name: String)
    case calendarQuery(timeframe: String)
    case weatherQuery
    case frequentCommand(String)
    case general(String)
}

struct OfflineResponse {
    let text: String
    let audioBase64: String?
    let confidence: Double
    let requiresSync: Bool
}

// MARK: - Smart Cache Manager

actor SmartCacheManager {
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "EnhancedOfflineCache"
    
    func initializeCache() async {
        // Initialize cache storage
        print("📦 SmartCacheManager: Initializing cache")
    }
    
    func cacheContacts() async {
        // Cache contact information
        print("👥 SmartCacheManager: Caching contacts")
    }
    
    func cacheCalendarEvents() async {
        // Cache calendar events
        print("📅 SmartCacheManager: Caching calendar events")
    }
    
    func cacheWeatherData() async {
        // Cache weather information
        print("🌤️ SmartCacheManager: Caching weather data")
    }
    
    func cacheFrequentCommands() async {
        // Cache frequently used commands
        print("🎯 SmartCacheManager: Caching frequent commands")
    }
    
    func getTotalCachedItems() async -> Int {
        return 0 // Placeholder
    }
    
    func getLastUpdateTime() async -> Date? {
        return userDefaults.object(forKey: "\(cacheKey)_lastUpdate") as? Date
    }
    
    func getCachedData() async -> OfflineEnhancementManager.CachedData? {
        // Return cached data
        return nil // Placeholder
    }
    
    func backgroundUpdateCache() async {
        print("🔄 SmartCacheManager: Background cache update")
    }
}