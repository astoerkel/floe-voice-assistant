import Foundation

@MainActor
class SimpleConversationManager: ObservableObject {
    @Published var conversationHistory: [ConversationMessage] = []
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "SimpleConversationHistory"
    private let maxHistoryItems = 50 // Keep it simple with fewer messages
    
    init() {
        loadConversationHistory()
    }
    
    func addMessage(_ message: ConversationMessage) {
        conversationHistory.append(message)
        
        // Keep only the most recent messages
        if conversationHistory.count > maxHistoryItems {
            conversationHistory.removeFirst(conversationHistory.count - maxHistoryItems)
        }
        
        saveConversationHistory()
    }
    
    func clearHistory() {
        conversationHistory.removeAll()
        saveConversationHistory()
    }
    
    private func loadConversationHistory() {
        guard let data = userDefaults.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([ConversationMessage].self, from: data) else {
            print("📱 No conversation history found")
            return
        }
        
        conversationHistory = decoded
        print("📱 Loaded \(conversationHistory.count) conversation messages")
    }
    
    private func saveConversationHistory() {
        guard let data = try? JSONEncoder().encode(conversationHistory) else {
            print("❌ Failed to encode conversation history")
            return
        }
        
        userDefaults.set(data, forKey: historyKey)
        print("💾 Saved \(conversationHistory.count) conversation messages")
    }
}