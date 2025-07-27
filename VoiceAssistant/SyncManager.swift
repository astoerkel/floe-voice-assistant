import Foundation
import Network
import CryptoKit

@MainActor
class SyncManager: ObservableObject {
    
    static let shared = SyncManager()
    
    // MARK: - Published Properties
    @Published var syncStatus: SyncStatus = .idle
    @Published var pendingActionsCount = 0
    @Published var lastSyncTime: Date?
    @Published var syncProgress: SyncProgress = SyncProgress()
    @Published var isConnected = false
    @Published var connectionQuality: ConnectionQuality = .unknown
    
    // MARK: - Private Properties
    private let networkMonitor = NWPathMonitor()
    private let syncQueue = DispatchQueue(label: "sync.queue", qos: .utility)
    private var pendingActions: [PendingAction] = []
    private var syncTimer: Timer?
    private let apiClient: APIClient
    private let dataManager: OfflineDataManager
    
    // MARK: - Constants
    private let maxRetryAttempts = 3
    private let syncInterval: TimeInterval = 30 // 30 seconds
    private let conflictResolutionTimeout: TimeInterval = 10
    
    // MARK: - Data Types
    enum SyncStatus: Equatable {
        case idle, syncing, paused, error(String)
        
        var description: String {
            switch self {
            case .idle: return "Ready to sync"
            case .syncing: return "Syncing..."
            case .paused: return "Sync paused"
            case .error(let message): return "Error: \(message)"
            }
        }
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.syncing, .syncing), (.paused, .paused):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    enum ConnectionQuality {
        case unknown, poor, fair, good, excellent
        
        var shouldSync: Bool {
            switch self {
            case .unknown, .poor: return false
            case .fair, .good, .excellent: return true
            }
        }
        
        var batchSize: Int {
            switch self {
            case .unknown, .poor: return 1
            case .fair: return 3
            case .good: return 5
            case .excellent: return 10
            }
        }
    }
    
    struct SyncProgress {
        var completed: Int = 0
        var total: Int = 0
        var currentAction: String = ""
        
        var percentage: Double {
            guard total > 0 else { return 0 }
            return Double(completed) / Double(total)
        }
    }
    
    struct PendingAction: Codable, Identifiable {
        let id = UUID()
        let type: ActionType
        let data: Data
        let timestamp: Date
        let priority: Priority
        var retryCount: Int
        var lastError: String?
        var conflictResolutionRequired: Bool = false
        
        enum ActionType: String, Codable {
            case createReminder = "create_reminder"
            case updateReminder = "update_reminder"
            case deleteReminder = "delete_reminder"
            case createCalendarEvent = "create_calendar_event"
            case updateCalendarEvent = "update_calendar_event"
            case deleteCalendarEvent = "delete_calendar_event"
            case sendEmail = "send_email"
            case updateUserPreferences = "update_user_preferences"
            case logUsageAnalytics = "log_usage_analytics"
        }
        
        enum Priority: Int, Codable, CaseIterable {
            case low = 0, normal = 1, high = 2, urgent = 3
        }
    }
    
    struct ConflictResolution {
        let actionId: UUID
        let serverData: Data
        let localData: Data
        let conflictType: ConflictType
        let resolutionStrategy: ResolutionStrategy
        
        enum ConflictType {
            case dataModified, dataDeleted, dataCreatedElsewhere
        }
        
        enum ResolutionStrategy {
            case useLocal, useServer, merge, askUser
        }
    }
    
    // MARK: - Initialization
    private init() {
        self.apiClient = APIClient()
        self.dataManager = OfflineDataManager.shared
        
        setupNetworkMonitoring()
        loadPendingActions()
        startPeriodicSync()
    }
    
    // MARK: - Public Interface
    func queueAction(_ type: PendingAction.ActionType, data: Data, priority: PendingAction.Priority = .normal) {
        let action = PendingAction(
            type: type,
            data: data,
            timestamp: Date(),
            priority: priority,
            retryCount: 0
        )
        
        pendingActions.append(action)
        pendingActions.sort { $0.priority.rawValue > $1.priority.rawValue }
        pendingActionsCount = pendingActions.count
        
        savePendingActions()
        
        // Try immediate sync if connected
        if isConnected && connectionQuality.shouldSync {
            Task {
                await trySync()
            }
        }
    }
    
    func syncPendingActions() async {
        guard isConnected && connectionQuality.shouldSync else {
            print("Cannot sync: No suitable connection")
            return
        }
        
        guard !pendingActions.isEmpty else {
            print("No pending actions to sync")
            return
        }
        
        syncStatus = .syncing
        syncProgress = SyncProgress(completed: 0, total: pendingActions.count, currentAction: "Starting sync...")
        
        print("Starting sync of \(pendingActions.count) pending actions")
        
        let batchSize = connectionQuality.batchSize
        let batches = pendingActions.chunked(into: batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            syncProgress.currentAction = "Processing batch \(batchIndex + 1) of \(batches.count)"
            
            await syncBatch(batch)
            
            // Small delay between batches to avoid overwhelming the server
            if batchIndex < batches.count - 1 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        lastSyncTime = Date()
        syncStatus = .idle
        syncProgress = SyncProgress()
        
        print("Sync completed. Remaining actions: \(pendingActions.count)")
    }
    
    func pauseSync() {
        syncStatus = .paused
        syncTimer?.invalidate()
    }
    
    func resumeSync() {
        syncStatus = .idle
        startPeriodicSync()
        
        if isConnected && connectionQuality.shouldSync {
            Task {
                await trySync()
            }
        }
    }
    
    func clearPendingActions() {
        pendingActions.removeAll()
        pendingActionsCount = 0
        savePendingActions()
    }
    
    func retryFailedAction(_ actionId: UUID) async {
        guard let actionIndex = pendingActions.firstIndex(where: { $0.id == actionId }) else {
            return
        }
        
        pendingActions[actionIndex].retryCount = 0
        pendingActions[actionIndex].lastError = nil
        
        let action = pendingActions[actionIndex]
        await syncSingleAction(action, index: actionIndex)
    }
    
    func resolveConflict(_ resolution: ConflictResolution) async {
        guard let actionIndex = pendingActions.firstIndex(where: { $0.id == resolution.actionId }) else {
            return
        }
        
        var action = pendingActions[actionIndex]
        action.conflictResolutionRequired = false
        
        switch resolution.resolutionStrategy {
        case .useLocal:
            await syncSingleAction(action, index: actionIndex)
        case .useServer:
            // Apply server data locally
            await applyServerData(resolution.serverData, for: action.type)
            pendingActions.remove(at: actionIndex)
        case .merge:
            // Merge data and sync
            let mergedData = await mergeData(local: resolution.localData, server: resolution.serverData, type: action.type)
            // Cannot assign to let constant, create new action
            let updatedAction = PendingAction(
                type: action.type,
                data: mergedData,
                timestamp: action.timestamp,
                priority: action.priority,
                retryCount: action.retryCount
            )
            pendingActions[actionIndex] = updatedAction
            await syncSingleAction(action, index: actionIndex)
        case .askUser:
            // Present conflict resolution UI (would be handled by the UI layer)
            break
        }
        
        pendingActionsCount = pendingActions.count
        savePendingActions()
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.updateConnectionQuality(from: path)
                
                if path.status == .satisfied && self?.syncStatus != .syncing {
                    await self?.trySync()
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    private func updateConnectionQuality(from path: NWPath) {
        if path.status != .satisfied {
            connectionQuality = .unknown
            return
        }
        
        // Assess connection quality based on interface type
        if path.usesInterfaceType(.wifi) {
            connectionQuality = .excellent
        } else if path.usesInterfaceType(.cellular) {
            connectionQuality = .good
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionQuality = .excellent
        } else {
            connectionQuality = .fair
        }
        
        // TODO: Add actual network quality testing (latency, bandwidth)
        // For now, simulate based on interface type
    }
    
    // MARK: - Periodic Sync
    private func startPeriodicSync() {
        syncTimer?.invalidate()
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.trySync()
            }
        }
    }
    
    private func trySync() async {
        guard syncStatus != .syncing && syncStatus != .paused else { return }
        guard isConnected && connectionQuality.shouldSync else { return }
        guard !pendingActions.isEmpty else { return }
        
        await syncPendingActions()
    }
    
    // MARK: - Sync Implementation
    private func syncBatch(_ batch: [PendingAction]) async {
        for (index, action) in batch.enumerated() {
            if let actionIndex = pendingActions.firstIndex(where: { $0.id == action.id }) {
                await syncSingleAction(action, index: actionIndex)
            }
            
            syncProgress.completed += 1
        }
    }
    
    private func syncSingleAction(_ action: PendingAction, index: Int) async {
        syncProgress.currentAction = "Syncing \(action.type.rawValue)..."
        
        do {
            let success = try await performSync(for: action)
            
            if success {
                pendingActions.remove(at: index)
                print("Successfully synced action: \(action.type.rawValue)")
            } else {
                await handleSyncFailure(action, at: index, error: "Sync returned false")
            }
        } catch {
            await handleSyncFailure(action, at: index, error: error.localizedDescription)
        }
        
        pendingActionsCount = pendingActions.count
        savePendingActions()
    }
    
    private func performSync(for action: PendingAction) async throws -> Bool {
        switch action.type {
        case .createReminder:
            return try await syncCreateReminder(action.data)
        case .updateReminder:
            return try await syncUpdateReminder(action.data)
        case .deleteReminder:
            return try await syncDeleteReminder(action.data)
        case .createCalendarEvent:
            return try await syncCreateCalendarEvent(action.data)
        case .updateCalendarEvent:
            return try await syncUpdateCalendarEvent(action.data)
        case .deleteCalendarEvent:
            return try await syncDeleteCalendarEvent(action.data)
        case .sendEmail:
            return try await syncSendEmail(action.data)
        case .updateUserPreferences:
            return try await syncUpdateUserPreferences(action.data)
        case .logUsageAnalytics:
            return try await syncLogUsageAnalytics(action.data)
        }
    }
    
    private func handleSyncFailure(_ action: PendingAction, at index: Int, error: String) async {
        var updatedAction = action
        updatedAction.retryCount += 1
        updatedAction.lastError = error
        
        if updatedAction.retryCount >= maxRetryAttempts {
            print("Max retry attempts reached for action: \(action.type.rawValue)")
            
            // Check for conflicts
            if error.contains("conflict") || error.contains("409") {
                updatedAction.conflictResolutionRequired = true
                print("Conflict detected for action: \(action.type.rawValue)")
            }
        }
        
        pendingActions[index] = updatedAction
    }
    
    // MARK: - Specific Sync Operations
    private func syncCreateReminder(_ data: Data) async throws -> Bool {
        let reminder = try JSONDecoder().decode(LocalReminder.self, from: data)
        
        // Convert to backend format and send
        let backendReminder = [
            "text": reminder.text,
            "priority": reminder.priority.rawValue,
            "created_date": ISO8601DateFormatter().string(from: reminder.createdDate)
        ]
        
        // TODO: Implement actual API call when backend is ready
        // For now, simulate success
        return true
    }
    
    private func syncUpdateReminder(_ data: Data) async throws -> Bool {
        let reminder = try JSONDecoder().decode(LocalReminder.self, from: data)
        
        let backendReminder = [
            "id": reminder.id.uuidString,
            "text": reminder.text,
            "completed": reminder.isCompleted,
            "priority": reminder.priority.rawValue
        ] as [String: Any]
        
        // TODO: Implement actual API call when backend is ready
        // For now, simulate success
        return true
    }
    
    private func syncDeleteReminder(_ data: Data) async throws -> Bool {
        let reminderId = try JSONDecoder().decode(UUID.self, from: data)
        // TODO: Implement actual API call when backend is ready
        // For now, simulate success
        return true
    }
    
    private func syncCreateCalendarEvent(_ data: Data) async throws -> Bool {
        // Implementation for calendar event creation
        return true
    }
    
    private func syncUpdateCalendarEvent(_ data: Data) async throws -> Bool {
        // Implementation for calendar event update
        return true
    }
    
    private func syncDeleteCalendarEvent(_ data: Data) async throws -> Bool {
        // Implementation for calendar event deletion
        return true
    }
    
    private func syncSendEmail(_ data: Data) async throws -> Bool {
        // Implementation for email sending
        return true
    }
    
    private func syncUpdateUserPreferences(_ data: Data) async throws -> Bool {
        // Implementation for user preferences update
        return true
    }
    
    private func syncLogUsageAnalytics(_ data: Data) async throws -> Bool {
        // Implementation for usage analytics logging
        return true
    }
    
    // MARK: - Conflict Resolution
    private func applyServerData(_ serverData: Data, for actionType: PendingAction.ActionType) async {
        switch actionType {
        case .createReminder, .updateReminder:
            if let reminder = try? JSONDecoder().decode(LocalReminder.self, from: serverData) {
                await dataManager.saveReminder(reminder)
            }
        case .deleteReminder:
            if let reminderId = try? JSONDecoder().decode(UUID.self, from: serverData) {
                await dataManager.deleteReminder(reminderId)
            }
        default:
            print("Server data application not implemented for \(actionType)")
        }
    }
    
    private func mergeData(local: Data, server: Data, type: PendingAction.ActionType) async -> Data {
        // Implement intelligent data merging based on action type
        // For now, return local data (prefer local changes)
        return local
    }
    
    // MARK: - Persistence
    private func loadPendingActions() {
        guard let data = UserDefaults.standard.data(forKey: "sync_pending_actions"),
              let actions = try? JSONDecoder().decode([PendingAction].self, from: data) else {
            return
        }
        
        pendingActions = actions.sorted { $0.priority.rawValue > $1.priority.rawValue }
        pendingActionsCount = pendingActions.count
    }
    
    private func savePendingActions() {
        if let data = try? JSONEncoder().encode(pendingActions) {
            UserDefaults.standard.set(data, forKey: "sync_pending_actions")
        }
    }
    
    // MARK: - Cleanup
    deinit {
        networkMonitor.cancel()
        syncTimer?.invalidate()
    }
}

// MARK: - Extensions
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Mock API Client Extensions
extension APIClient {
    func createReminder(_ data: [String: Any]) async throws -> Bool {
        // Mock implementation - replace with actual API call
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        return true
    }
    
    func updateReminder(_ id: String, data: [String: Any]) async throws -> Bool {
        // Mock implementation - replace with actual API call
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        return true
    }
    
    func deleteReminder(_ id: String) async throws -> Bool {
        // Mock implementation - replace with actual API call
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        return true
    }
}

// MARK: - Sync Statistics
extension SyncManager {
    func getSyncStatistics() -> SyncStatistics {
        let failedActions = pendingActions.filter { $0.retryCount >= maxRetryAttempts }
        let conflictActions = pendingActions.filter { $0.conflictResolutionRequired }
        
        return SyncStatistics(
            pendingActions: pendingActions.count,
            failedActions: failedActions.count,
            conflictActions: conflictActions.count,
            lastSyncTime: lastSyncTime,
            connectionQuality: connectionQuality,
            averageRetryCount: pendingActions.isEmpty ? 0 : Double(pendingActions.map { $0.retryCount }.reduce(0, +)) / Double(pendingActions.count)
        )
    }
}

struct SyncStatistics {
    let pendingActions: Int
    let failedActions: Int
    let conflictActions: Int
    let lastSyncTime: Date?
    let connectionQuality: SyncManager.ConnectionQuality
    let averageRetryCount: Double
}