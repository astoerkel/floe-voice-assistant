import Foundation
import SwiftUI
import Combine

class OfflineManager: ObservableObject {
    @Published var isConnectedToPhone = false
    @Published var queuedCommands: [QueuedCommand] = []
    @Published var cachedData: CachedData?
    
    private let userDefaults = UserDefaults.standard
    private let phoneConnector = PhoneConnector.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let queuedCommandsKey = "queuedCommands"
    private let cachedDataKey = "cachedData"
    
    init() {
        loadPersistedData()
        observeConnectivity()
    }
    
    private func observeConnectivity() {
        phoneConnector.$isConnected
            .sink { [weak self] isConnected in
                self?.isConnectedToPhone = isConnected
                
                // Auto-sync when connection is restored
                if isConnected && !(self?.queuedCommands.isEmpty ?? true) {
                    Task {
                        await self?.syncQueuedCommands()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadPersistedData() {
        // Load queued commands
        if let queuedData = userDefaults.data(forKey: queuedCommandsKey) {
            do {
                let decoder = JSONDecoder()
                let commands = try decoder.decode([QueuedCommandData].self, from: queuedData)
                queuedCommands = commands.map { QueuedCommand(from: $0) }
            } catch {
                print("❌ OfflineManager: Failed to load queued commands: \(error)")
            }
        }
        
        // Load cached data
        if let cachedDataRaw = userDefaults.data(forKey: cachedDataKey) {
            do {
                let decoder = JSONDecoder()
                cachedData = try decoder.decode(CachedData.self, from: cachedDataRaw)
            } catch {
                print("❌ OfflineManager: Failed to load cached data: \(error)")
            }
        } else {
            // Initialize with sample data
            cachedData = CachedData(
                todayEvents: [
                    "Team Meeting - 9:00 AM",
                    "Review PRs - 11:00 AM",
                    "Lunch with Sarah - 12:30 PM",
                    "Client Call - 3:00 PM"
                ],
                pendingTasksCount: 3,
                nextMeetingTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date())
            )
        }
    }
    
    private func persistData() {
        // Save queued commands
        do {
            let encoder = JSONEncoder()
            let commandData = queuedCommands.map { QueuedCommandData(from: $0) }
            let encodedCommands = try encoder.encode(commandData)
            userDefaults.set(encodedCommands, forKey: queuedCommandsKey)
        } catch {
            print("❌ OfflineManager: Failed to save queued commands: \(error)")
        }
        
        // Save cached data
        if let cachedData = cachedData {
            do {
                let encoder = JSONEncoder()
                let encodedData = try encoder.encode(cachedData)
                userDefaults.set(encodedData, forKey: cachedDataKey)
            } catch {
                print("❌ OfflineManager: Failed to save cached data: \(error)")
            }
        }
    }
    
    func queueVoiceCommand(_ audioData: Data, intent: String = "") {
        let command = QueuedCommand(audioData: audioData, userIntent: intent)
        queuedCommands.append(command)
        persistData()
        
        print("✅ OfflineManager: Queued voice command (intent: \(intent))")
        
        // Try to sync immediately if connected
        if isConnectedToPhone {
            Task {
                await syncQueuedCommands()
            }
        }
    }
    
    func queueTextCommand(_ text: String) {
        let audioData = text.data(using: .utf8) ?? Data()
        queueVoiceCommand(audioData, intent: text)
    }
    
    @MainActor
    func syncQueuedCommands() async {
        guard isConnectedToPhone && !queuedCommands.isEmpty else { return }
        
        print("🔄 OfflineManager: Syncing \(queuedCommands.count) queued commands...")
        
        var successfulSyncs: [UUID] = []
        
        for command in queuedCommands {
            let success = await sendCommandToPhone(command)
            if success {
                successfulSyncs.append(command.id)
            }
        }
        
        // Remove successfully synced commands
        queuedCommands.removeAll { command in
            successfulSyncs.contains(command.id)
        }
        
        persistData()
        
        print("✅ OfflineManager: Synced \(successfulSyncs.count) commands, \(queuedCommands.count) remaining")
    }
    
    private func sendCommandToPhone(_ command: QueuedCommand) async -> Bool {
        return await withCheckedContinuation { continuation in
            guard let watchSession = phoneConnector.session, watchSession.isReachable else {
                continuation.resume(returning: false)
                return
            }
            
            let message: [String: Any] = [
                "type": "queuedCommand",
                "audio": command.audioData,
                "intent": command.userIntent,
                "timestamp": command.timestamp.timeIntervalSince1970,
                "commandId": command.id.uuidString
            ]
            
            watchSession.sendMessage(message, replyHandler: { response in
                if let success = response["success"] as? Bool {
                    continuation.resume(returning: success)
                } else {
                    continuation.resume(returning: false)
                }
            }, errorHandler: { error in
                print("❌ OfflineManager: WatchConnectivity error: \(error)")
                continuation.resume(returning: false)
            })
        }
    }
    
    func updateCachedData(_ newData: CachedData) {
        cachedData = newData
        persistData()
    }
    
    func addCachedEvent(_ event: String) {
        guard let cached = cachedData else { return }
        let newEvents = cached.todayEvents + [event]
        let newCachedData = CachedData(
            todayEvents: newEvents,
            pendingTasksCount: cached.pendingTasksCount,
            nextMeetingTime: cached.nextMeetingTime
        )
        updateCachedData(newCachedData)
    }
    
    func clearQueuedCommands() {
        queuedCommands.removeAll()
        persistData()
    }
    
    func getLocalIntentRecognition(for text: String) -> String {
        let lowercased = text.lowercased()
        
        // Simple local intent recognition
        if lowercased.contains("meeting") || lowercased.contains("schedule") {
            return "calendar_query"
        } else if lowercased.contains("email") || lowercased.contains("message") {
            return "email_query"
        } else if lowercased.contains("task") || lowercased.contains("todo") {
            return "task_management"
        } else if lowercased.contains("reminder") {
            return "reminder"
        } else if lowercased.contains("weather") {
            return "weather_query"
        } else if lowercased.contains("time") {
            return "time_query"
        } else {
            return "general_query"
        }
    }
    
    func getOfflineResponse(for intent: String) -> String {
        switch intent {
        case "time_query":
            return "Current time is \(Date().formatted(.dateTime.hour().minute()))"
        case "weather_query":
            return "Weather information requires internet connection"
        case "calendar_query":
            let events = cachedData?.todayEvents ?? []
            return events.isEmpty ? "No cached events found" : "Today's events: \(events.joined(separator: ", "))"
        case "task_management":
            let count = cachedData?.pendingTasksCount ?? 0
            return "You have \(count) pending tasks"
        default:
            return "This request requires internet connection"
        }
    }
}

// MARK: - Codable Support
extension CachedData: Codable {
    enum CodingKeys: String, CodingKey {
        case lastSyncTime, todayEvents, pendingTasksCount, nextMeetingTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastSyncTime = try container.decode(Date.self, forKey: .lastSyncTime)
        todayEvents = try container.decode([String].self, forKey: .todayEvents)
        pendingTasksCount = try container.decode(Int.self, forKey: .pendingTasksCount)
        nextMeetingTime = try container.decodeIfPresent(Date.self, forKey: .nextMeetingTime)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lastSyncTime, forKey: .lastSyncTime)
        try container.encode(todayEvents, forKey: .todayEvents)
        try container.encode(pendingTasksCount, forKey: .pendingTasksCount)
        try container.encodeIfPresent(nextMeetingTime, forKey: .nextMeetingTime)
    }
}

private struct QueuedCommandData: Codable {
    let id: String
    let audioData: Data
    let timestamp: Date
    let userIntent: String
    
    init(from command: QueuedCommand) {
        self.id = command.id.uuidString
        self.audioData = command.audioData
        self.timestamp = command.timestamp
        self.userIntent = command.userIntent
    }
}

private extension QueuedCommand {
    init(from data: QueuedCommandData) {
        self.init(audioData: data.audioData, userIntent: data.userIntent)
    }
}