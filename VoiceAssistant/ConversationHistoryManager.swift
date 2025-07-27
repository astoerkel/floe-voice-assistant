//
//  ConversationHistoryManager.swift
//  VoiceAssistant
//
//  Manages persistent conversation history storage and retrieval
//

import Foundation
import Combine

@MainActor
class ConversationHistoryManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var conversationHistory: [ConversationMessage] = []
    @Published var isLoading = false
    @Published var lastSyncDate: Date?
    
    // MARK: - Configuration
    private let maxHistoryItems = 1000 // Maximum messages to keep
    private let maxDaysToKeep = 30 // Days to keep conversation history
    private let userDefaults = UserDefaults.standard
    private let historyKey = "ConversationHistory"
    private let lastSyncKey = "ConversationHistoryLastSync"
    
    // MARK: - Current Session
    private var currentSessionId: String = UUID().uuidString
    private var sessionStartTime = Date()
    
    // MARK: - Initialization
    init() {
        loadConversationHistory()
        startNewSession()
    }
    
    // MARK: - Public Methods
    
    /// Add a new message to the conversation history
    func addMessage(_ message: ConversationMessage) {
        conversationHistory.append(message)
        saveConversationHistory()
        
        // Log the addition
        let messageType = message.isUser ? "User" : "Assistant"
        print("💬 ConversationHistoryManager: Added \(messageType) message: '\(message.text.prefix(50))'")
    }
    
    /// Start a new conversation session
    func startNewSession() {
        currentSessionId = UUID().uuidString
        sessionStartTime = Date()
        print("🆕 ConversationHistoryManager: Started new session: \(currentSessionId)")
    }
    
    /// Get the current session ID
    func getCurrentSessionId() -> String {
        return currentSessionId
    }
    
    /// Get messages from the current session only
    func getCurrentSessionMessages() -> [ConversationMessage] {
        return conversationHistory.filter { message in
            message.timestamp >= sessionStartTime
        }
    }
    
    /// Get recent messages (last N messages)
    func getRecentMessages(limit: Int = 20) -> [ConversationMessage] {
        return Array(conversationHistory.suffix(limit))
    }
    
    /// Search messages by text content
    func searchMessages(query: String) -> [ConversationMessage] {
        let lowercaseQuery = query.lowercased()
        return conversationHistory.filter { message in
            message.text.lowercased().contains(lowercaseQuery)
        }
    }
    
    /// Get messages from a specific date range
    func getMessages(from startDate: Date, to endDate: Date) -> [ConversationMessage] {
        return conversationHistory.filter { message in
            message.timestamp >= startDate && message.timestamp <= endDate
        }
    }
    
    /// Clear all conversation history
    func clearAllHistory() {
        conversationHistory.removeAll()
        saveConversationHistory()
        print("🗑️ ConversationHistoryManager: Cleared all conversation history")
    }
    
    /// Clear old messages beyond the retention policy
    func clearOldMessages() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxDaysToKeep, to: Date()) ?? Date()
        let originalCount = conversationHistory.count
        
        conversationHistory = conversationHistory.filter { message in
            message.timestamp >= cutoffDate
        }
        
        let removedCount = originalCount - conversationHistory.count
        if removedCount > 0 {
            saveConversationHistory()
            print("🧹 ConversationHistoryManager: Removed \(removedCount) old messages")
        }
    }
    
    /// Get conversation statistics
    func getStatistics() -> ConversationStatistics {
        let totalMessages = conversationHistory.count
        let userMessages = conversationHistory.filter { $0.isUser }.count
        let assistantMessages = totalMessages - userMessages
        
        let oldestMessage = conversationHistory.first?.timestamp
        let newestMessage = conversationHistory.last?.timestamp
        
        let todayMessages = conversationHistory.filter { message in
            Calendar.current.isDateInToday(message.timestamp)
        }.count
        
        return ConversationStatistics(
            totalMessages: totalMessages,
            userMessages: userMessages,
            assistantMessages: assistantMessages,
            todayMessages: todayMessages,
            oldestMessageDate: oldestMessage,
            newestMessageDate: newestMessage,
            currentSessionMessages: getCurrentSessionMessages().count
        )
    }
    
    // MARK: - Private Methods
    
    /// Load conversation history from persistent storage
    private func loadConversationHistory() {
        isLoading = true
        
        if let data = userDefaults.data(forKey: historyKey) {
            do {
                let loadedHistory = try JSONDecoder().decode([ConversationMessage].self, from: data)
                conversationHistory = loadedHistory
                lastSyncDate = userDefaults.object(forKey: lastSyncKey) as? Date
                
                print("✅ ConversationHistoryManager: Loaded \(loadedHistory.count) messages from storage")
                
                // Clean up old messages after loading
                clearOldMessages()
                
            } catch {
                print("❌ ConversationHistoryManager: Failed to load history: \(error.localizedDescription)")
                conversationHistory = []
            }
        } else {
            print("📝 ConversationHistoryManager: No existing history found, starting fresh")
            conversationHistory = []
        }
        
        isLoading = false
    }
    
    /// Save conversation history to persistent storage
    private func saveConversationHistory() {
        do {
            // Limit the number of messages to prevent storage bloat
            let messagesToSave = Array(conversationHistory.suffix(maxHistoryItems))
            
            let data = try JSONEncoder().encode(messagesToSave)
            userDefaults.set(data, forKey: historyKey)
            userDefaults.set(Date(), forKey: lastSyncKey)
            lastSyncDate = Date()
            
            print("💾 ConversationHistoryManager: Saved \(messagesToSave.count) messages to storage")
            
        } catch {
            print("❌ ConversationHistoryManager: Failed to save history: \(error.localizedDescription)")
        }
    }
    
    /// Export conversation history for backup or sharing
    func exportHistory() -> String? {
        do {
            let data = try JSONEncoder().encode(conversationHistory)
            return String(data: data, encoding: .utf8)
        } catch {
            print("❌ ConversationHistoryManager: Failed to export history: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Import conversation history from backup
    func importHistory(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            print("❌ ConversationHistoryManager: Invalid JSON string for import")
            return false
        }
        
        do {
            let importedHistory = try JSONDecoder().decode([ConversationMessage].self, from: data)
            
            // Merge with existing history, avoiding duplicates
            let existingIds = Set(conversationHistory.map { $0.id })
            let newMessages = importedHistory.filter { !existingIds.contains($0.id) }
            
            conversationHistory.append(contentsOf: newMessages)
            conversationHistory.sort { $0.timestamp < $1.timestamp }
            
            saveConversationHistory()
            print("✅ ConversationHistoryManager: Imported \(newMessages.count) new messages")
            return true
            
        } catch {
            print("❌ ConversationHistoryManager: Failed to import history: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Supporting Types

struct ConversationStatistics {
    let totalMessages: Int
    let userMessages: Int
    let assistantMessages: Int
    let todayMessages: Int
    let oldestMessageDate: Date?
    let newestMessageDate: Date?
    let currentSessionMessages: Int
    
    var averageMessagesPerDay: Double {
        guard let oldest = oldestMessageDate, let newest = newestMessageDate else { return 0 }
        let days = max(1, Calendar.current.dateComponents([.day], from: oldest, to: newest).day ?? 1)
        return Double(totalMessages) / Double(days)
    }
}

// MARK: - Extensions

extension ConversationHistoryManager {
    
    /// Get formatted conversation export for sharing
    func getFormattedConversationExport() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var export = "# Floe Voice Assistant Conversation History\n"
        export += "Exported on: \(formatter.string(from: Date()))\n"
        export += "Total Messages: \(conversationHistory.count)\n\n"
        
        for message in conversationHistory {
            let sender = message.isUser ? "You" : "Floe"
            export += "**\(sender)** (\(formatter.string(from: message.timestamp))):\n"
            export += "\(message.text)\n\n"
        }
        
        return export
    }
}