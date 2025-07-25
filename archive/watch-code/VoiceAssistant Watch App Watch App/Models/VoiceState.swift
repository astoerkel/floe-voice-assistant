import Foundation
import SwiftUI

enum VoiceState {
    case idle
    case listening
    case processing
    case responding
    case error
}

struct QueuedCommand {
    let id: UUID
    let audioData: Data
    let timestamp: Date
    let userIntent: String
    
    init(audioData: Data, userIntent: String = "") {
        self.id = UUID()
        self.audioData = audioData
        self.timestamp = Date()
        self.userIntent = userIntent
    }
}

struct CachedData {
    let lastSyncTime: Date
    let todayEvents: [String]
    let pendingTasksCount: Int
    let nextMeetingTime: Date?
    
    init(todayEvents: [String] = [], pendingTasksCount: Int = 0, nextMeetingTime: Date? = nil) {
        self.lastSyncTime = Date()
        self.todayEvents = todayEvents
        self.pendingTasksCount = pendingTasksCount
        self.nextMeetingTime = nextMeetingTime
    }
}

class WatchAppState: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var voiceState: VoiceState = .idle
    @Published var queuedCommandsCount: Int = 0
    @Published var isOfflineMode: Bool = false
    
    enum ConnectionStatus {
        case connected
        case disconnected
        case connecting
    }
}