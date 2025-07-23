import Foundation
import CoreML
import NaturalLanguage
import CryptoKit

@MainActor
public class OfflineProcessor: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isOfflineMode = false
    @Published var queuedCommandsCount = 0
    @Published var offlineCapabilities: Set<OfflineCapability> = []
    @Published var connectionQuality: ConnectionQuality = .excellent
    
    // MARK: - Private Properties
    private let dataManager: OfflineDataManager
    private let syncManager: SyncManager
    private let intentClassifier: IntentClassifier
    private let offlineHandlers: [String: OfflineHandler] = [:]
    private var queuedCommands: [QueuedCommand] = []
    
    // MARK: - Core ML Models
    private var intentModel: MLModel?
    private var responseModel: MLModel?
    private var speechEnhancementModel: MLModel?
    
    // MARK: - Offline Capabilities
    enum OfflineCapability: String, CaseIterable {
        case calendar = "Calendar Queries"
        case reminders = "Reminders & Notes"
        case timeDate = "Time & Date"
        case calculations = "Calculations"
        case deviceControl = "Device Control"
        case basicConversation = "Basic Conversation"
        case weatherCache = "Cached Weather"
        case contactLookup = "Contact Lookup"
        
        var description: String {
            switch self {
            case .calendar:
                return "Query cached calendar events and create basic reminders"
            case .reminders:
                return "Create and manage notes and reminders locally"
            case .timeDate:
                return "Get current time, date, and timezone information"
            case .calculations:
                return "Perform mathematical calculations and unit conversions"
            case .deviceControl:
                return "Control device settings like brightness, Do Not Disturb"
            case .basicConversation:
                return "Handle basic greetings and conversational responses"
            case .weatherCache:
                return "Access previously cached weather information"
            case .contactLookup:
                return "Look up contact information from local contacts"
            }
        }
        
        var icon: String {
            switch self {
            case .calendar: return "calendar"
            case .reminders: return "note.text"
            case .timeDate: return "clock"
            case .calculations: return "function"
            case .deviceControl: return "iphone"
            case .basicConversation: return "bubble.left"
            case .weatherCache: return "cloud.sun"
            case .contactLookup: return "person.circle"
            }
        }
    }
    
    // MARK: - Connection Quality
    enum ConnectionQuality {
        case offline, poor, fair, good, excellent
        
        var shouldUseOffline: Bool {
            return self == .offline || self == .poor
        }
        
        var description: String {
            switch self {
            case .offline: return "No Connection"
            case .poor: return "Poor Connection"
            case .fair: return "Fair Connection"
            case .good: return "Good Connection"
            case .excellent: return "Excellent Connection"
            }
        }
        
        var color: String {
            switch self {
            case .offline: return "red"
            case .poor: return "orange"
            case .fair: return "yellow"
            case .good: return "blue"
            case .excellent: return "green"
            }
        }
    }
    
    // MARK: - Data Models
    struct QueuedCommand {
        let id = UUID()
        let text: String
        let timestamp: Date
        let audioData: Data?
        let priority: CommandPriority
        let requiredCapabilities: Set<OfflineCapability>
        var processingAttempts = 0
        var lastProcessingError: String?
        
        enum CommandPriority: Int, CaseIterable {
            case low = 0, normal = 1, high = 2, urgent = 3
        }
    }
    
    struct OfflineResponse {
        let text: String
        let audioBase64: String?
        let confidence: Double
        let source: ResponseSource
        let capabilities: Set<OfflineCapability>
        let processingTime: TimeInterval
        let requiresSync: Bool
        let metadata: [String: Any]
        
        enum ResponseSource {
            case coreML, template, cache, hybrid
        }
    }
    
    // MARK: - Initialization
    public init() {
        self.dataManager = OfflineDataManager.shared
        self.syncManager = SyncManager.shared
        self.intentClassifier = IntentClassifier()
        
        initializeOfflineCapabilities()
        loadCoreMLModels()
        setupNetworkMonitoring()
        loadQueuedCommands()
    }
    
    // MARK: - Public Interface
    func processCommand(_ text: String, audioData: Data? = nil) async -> OfflineResponse {
        let startTime = Date()
        
        // Assess connection and determine processing mode
        let shouldProcessOffline = connectionQuality.shouldUseOffline || isForceOfflineMode()
        
        if shouldProcessOffline {
            return await processOfflineCommand(text, audioData: audioData, startTime: startTime)
        } else {
            // Queue for online processing with fallback to offline
            return await processWithFallback(text, audioData: audioData, startTime: startTime)
        }
    }
    
    func queueCommandForLater(_ text: String, audioData: Data?, priority: QueuedCommand.CommandPriority = .normal) {
        let command = QueuedCommand(
            text: text,
            timestamp: Date(),
            audioData: audioData,
            priority: priority,
            requiredCapabilities: determineRequiredCapabilities(for: text)
        )
        
        queuedCommands.append(command)
        queuedCommandsCount = queuedCommands.count
        saveQueuedCommands()
        
        // Try to process if connection improves
        Task {
            await syncQueuedCommands()
        }
    }
    
    func syncWhenConnectionRestored() async {
        guard connectionQuality != .offline else { return }
        
        await syncManager.syncPendingActions()
        await syncQueuedCommands()
        await dataManager.syncCachedData()
    }
    
    func getAvailableCapabilities() -> Set<OfflineCapability> {
        return offlineCapabilities
    }
    
    func getOfflineStatus() -> OfflineStatus {
        return OfflineStatus(
            isOffline: isOfflineMode,
            connectionQuality: connectionQuality,
            queuedCommands: queuedCommandsCount,
            availableCapabilities: Array(offlineCapabilities),
            lastSyncTime: syncManager.lastSyncTime,
            cachedDataSize: dataManager.getCachedDataSize()
        )
    }
    
    // MARK: - Private Implementation
    private func initializeOfflineCapabilities() {
        // Initialize all supported offline capabilities
        offlineCapabilities = Set(OfflineCapability.allCases)
        
        // Remove capabilities that require additional setup
        if !dataManager.hasCalendarCache() {
            offlineCapabilities.remove(.calendar)
        }
        
        if !dataManager.hasWeatherCache() {
            offlineCapabilities.remove(.weatherCache)
        }
        
        if !dataManager.hasContactsAccess() {
            offlineCapabilities.remove(.contactLookup)
        }
    }
    
    private func loadCoreMLModels() {
        Task {
            do {
                // Load intent classification model
                if let modelURL = Bundle.main.url(forResource: "OfflineIntentClassifier", withExtension: "mlmodelc") {
                    intentModel = try MLModel(contentsOf: modelURL)
                }
                
                // Load response generation model
                if let responseURL = Bundle.main.url(forResource: "OfflineResponseGenerator", withExtension: "mlmodelc") {
                    responseModel = try MLModel(contentsOf: responseURL)
                }
                
                // Load speech enhancement model
                if let speechURL = Bundle.main.url(forResource: "OfflineSpeechEnhancer", withExtension: "mlmodelc") {
                    speechEnhancementModel = try MLModel(contentsOf: speechURL)
                }
            } catch {
                print("Failed to load Core ML models: \(error)")
                // Continue with algorithmic fallbacks
            }
        }
    }
    
    private func setupNetworkMonitoring() {
        // Monitor network quality and update connection status
        // This would integrate with Network framework in a real implementation
        Task {
            while true {
                await updateConnectionQuality()
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
    }
    
    private func updateConnectionQuality() async {
        // Simulate network quality assessment
        // In real implementation, this would use Network framework
        let previousQuality = connectionQuality
        
        // Mock network quality detection
        let random = Double.random(in: 0...1)
        connectionQuality = switch random {
        case 0.0..<0.1: .offline
        case 0.1..<0.3: .poor
        case 0.3..<0.6: .fair
        case 0.6..<0.8: .good
        default: .excellent
        }
        
        isOfflineMode = connectionQuality == .offline
        
        // If connection improved, try to sync
        if previousQuality.shouldUseOffline && !connectionQuality.shouldUseOffline {
            await syncWhenConnectionRestored()
        }
    }
    
    private func processOfflineCommand(_ text: String, audioData: Data?, startTime: Date) async -> OfflineResponse {
        // Classify intent using Core ML or fallback
        let intent = await classifyIntent(text)
        
        // Process based on capability
        let response = await generateOfflineResponse(for: intent, text: text)
        
        // Generate audio if possible
        let audioBase64 = await generateOfflineAudio(for: response.text)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return OfflineResponse(
            text: response.text,
            audioBase64: audioBase64,
            confidence: response.confidence,
            source: response.source,
            capabilities: response.capabilities,
            processingTime: processingTime,
            requiresSync: response.requiresSync,
            metadata: response.metadata
        )
    }
    
    private func processWithFallback(_ text: String, audioData: Data?, startTime: Date) async -> OfflineResponse {
        do {
            // Try online processing first
            // This would integrate with the existing API client
            // For now, fallback to offline processing
            return await processOfflineCommand(text, audioData: audioData, startTime: startTime)
        } catch {
            // Fallback to offline processing
            return await processOfflineCommand(text, audioData: audioData, startTime: startTime)
        }
    }
    
    private func classifyIntent(_ text: String) async -> IntentClassification {
        if let model = intentModel {
            return await classifyWithCoreML(text, model: model)
        } else {
            return classifyWithFallback(text)
        }
    }
    
    private func classifyWithCoreML(_ text: String, model: MLModel) async -> IntentClassification {
        // Implement Core ML intent classification
        // This is a mock implementation
        return IntentClassification(
            intent: .timeQuery,
            confidence: 0.85,
            parameters: extractParameters(from: text)
        )
    }
    
    private func classifyWithFallback(_ text: String) -> IntentClassification {
        let lowercaseText = text.lowercased()
        
        // Pattern matching for intent classification
        if lowercaseText.contains("time") || lowercaseText.contains("clock") {
            return IntentClassification(intent: .timeQuery, confidence: 0.9)
        } else if lowercaseText.contains("date") || lowercaseText.contains("today") {
            return IntentClassification(intent: .dateQuery, confidence: 0.9)
        } else if lowercaseText.contains("calculate") || lowercaseText.contains("math") {
            return IntentClassification(intent: .calculation, confidence: 0.8)
        } else if lowercaseText.contains("remind") || lowercaseText.contains("note") {
            return IntentClassification(intent: .reminder, confidence: 0.8)
        } else if lowercaseText.contains("calendar") || lowercaseText.contains("meeting") {
            return IntentClassification(intent: .calendar, confidence: 0.8)
        } else {
            return IntentClassification(intent: .general, confidence: 0.5)
        }
    }
    
    private func generateOfflineResponse(for intent: IntentClassification, text: String) async -> (text: String, confidence: Double, source: OfflineResponse.ResponseSource, capabilities: Set<OfflineCapability>, requiresSync: Bool, metadata: [String: Any]) {
        
        switch intent.intent {
        case .timeQuery:
            let timeResponse = OfflineIntentHandlers.handleTimeQuery(intent.parameters)
            return (
                text: timeResponse,
                confidence: 0.95,
                source: .template,
                capabilities: [.timeDate],
                requiresSync: false,
                metadata: ["intent": "time_query"]
            )
            
        case .dateQuery:
            let dateResponse = OfflineIntentHandlers.handleDateQuery(intent.parameters)
            return (
                text: dateResponse,
                confidence: 0.95,
                source: .template,
                capabilities: [.timeDate],
                requiresSync: false,
                metadata: ["intent": "date_query"]
            )
            
        case .calculation:
            let calcResponse = OfflineIntentHandlers.handleCalculation(text, parameters: intent.parameters)
            return (
                text: calcResponse,
                confidence: 0.8,
                source: .template,
                capabilities: [.calculations],
                requiresSync: false,
                metadata: ["intent": "calculation"]
            )
            
        case .reminder:
            let reminderResponse = await OfflineIntentHandlers.handleReminder(text, parameters: intent.parameters, dataManager: dataManager)
            return (
                text: reminderResponse,
                confidence: 0.9,
                source: .template,
                capabilities: [.reminders],
                requiresSync: true,
                metadata: ["intent": "reminder", "action": "create"]
            )
            
        case .calendar:
            let calendarResponse = await OfflineIntentHandlers.handleCalendarQuery(intent.parameters, dataManager: dataManager)
            return (
                text: calendarResponse,
                confidence: 0.8,
                source: .cache,
                capabilities: [.calendar],
                requiresSync: false,
                metadata: ["intent": "calendar_query"]
            )
            
        case .deviceControl:
            let deviceResponse = OfflineIntentHandlers.handleDeviceControl(text, parameters: intent.parameters)
            return (
                text: deviceResponse,
                confidence: 0.7,
                source: .template,
                capabilities: [.deviceControl],
                requiresSync: false,
                metadata: ["intent": "device_control"]
            )
            
        default:
            let generalResponse = await generateGeneralResponse(text)
            return (
                text: generalResponse,
                confidence: 0.6,
                source: .template,
                capabilities: [.basicConversation],
                requiresSync: false,
                metadata: ["intent": "general"]
            )
        }
    }
    
    private func generateOfflineAudio(for text: String) async -> String? {
        // In a real implementation, this would use offline TTS
        // For now, return nil to indicate no offline audio available
        return nil
    }
    
    private func generateGeneralResponse(_ text: String) async -> String {
        let responses = [
            "I understand you want to \(text.lowercased()), but I need an internet connection for that.",
            "I can help with that when we're back online. For now, I can help with time, calculations, or reminders.",
            "That's a great question! I'll need to connect to the internet to give you the best answer.",
            "I'm working in offline mode right now. I can help with basic tasks like time, math, or creating reminders."
        ]
        return responses.randomElement() ?? "I'm currently offline but ready to help when connection is restored."
    }
    
    private func extractParameters(from text: String) -> [String: Any] {
        var parameters: [String: Any] = [:]
        
        // Extract common parameters using NL framework
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let substring = String(text[range])
                switch tag {
                case .personalName:
                    parameters["person"] = substring
                case .placeName:
                    parameters["location"] = substring
                case .organizationName:
                    parameters["organization"] = substring
                default:
                    break
                }
            }
            return true
        }
        
        return parameters
    }
    
    private func determineRequiredCapabilities(for text: String) -> Set<OfflineCapability> {
        let intent = classifyWithFallback(text)
        
        switch intent.intent {
        case .timeQuery, .dateQuery:
            return [.timeDate]
        case .calculation:
            return [.calculations]
        case .reminder:
            return [.reminders]
        case .calendar:
            return [.calendar]
        case .deviceControl:
            return [.deviceControl]
        default:
            return [.basicConversation]
        }
    }
    
    private func isForceOfflineMode() -> Bool {
        // Check if user has enabled force offline mode
        return UserDefaults.standard.bool(forKey: "force_offline_mode")
    }
    
    private func syncQueuedCommands() async {
        guard !connectionQuality.shouldUseOffline else { return }
        
        let commandsToProcess = queuedCommands.sorted { $0.priority.rawValue > $1.priority.rawValue }
        
        for command in commandsToProcess {
            do {
                // Try to process command online
                // This would integrate with existing API client
                // For now, just remove from queue
                if let index = queuedCommands.firstIndex(where: { $0.id == command.id }) {
                    queuedCommands.remove(at: index)
                }
            } catch {
                // Keep in queue for later retry
                if let index = queuedCommands.firstIndex(where: { $0.id == command.id }) {
                    queuedCommands[index].processingAttempts += 1
                    queuedCommands[index].lastProcessingError = error.localizedDescription
                }
            }
        }
        
        queuedCommandsCount = queuedCommands.count
        saveQueuedCommands()
    }
    
    private func loadQueuedCommands() {
        if let data = UserDefaults.standard.data(forKey: "queued_commands"),
           let commands = try? JSONDecoder().decode([QueuedCommandCodable].self, from: data) {
            queuedCommands = commands.map { $0.toQueuedCommand() }
            queuedCommandsCount = queuedCommands.count
        }
    }
    
    private func saveQueuedCommands() {
        let codableCommands = queuedCommands.map { QueuedCommandCodable(from: $0) }
        if let data = try? JSONEncoder().encode(codableCommands) {
            UserDefaults.standard.set(data, forKey: "queued_commands")
        }
    }
}

// MARK: - Supporting Types
struct IntentClassification {
    let intent: Intent
    let confidence: Double
    let parameters: [String: Any]
    
    init(intent: Intent, confidence: Double, parameters: [String: Any] = [:]) {
        self.intent = intent
        self.confidence = confidence
        self.parameters = parameters
    }
    
    enum Intent {
        case timeQuery, dateQuery, calculation, reminder, calendar, deviceControl, general
    }
}

struct OfflineStatus {
    let isOffline: Bool
    let connectionQuality: OfflineProcessor.ConnectionQuality
    let queuedCommands: Int
    let availableCapabilities: [OfflineProcessor.OfflineCapability]
    let lastSyncTime: Date?
    let cachedDataSize: String
}

// MARK: - Codable Support for QueuedCommand
private struct QueuedCommandCodable: Codable {
    let text: String
    let timestamp: Date
    let audioData: Data?
    let priority: Int
    let requiredCapabilities: [String]
    let processingAttempts: Int
    let lastProcessingError: String?
    
    init(from command: OfflineProcessor.QueuedCommand) {
        self.text = command.text
        self.timestamp = command.timestamp
        self.audioData = command.audioData
        self.priority = command.priority.rawValue
        self.requiredCapabilities = command.requiredCapabilities.map { $0.rawValue }
        self.processingAttempts = command.processingAttempts
        self.lastProcessingError = command.lastProcessingError
    }
    
    func toQueuedCommand() -> OfflineProcessor.QueuedCommand {
        let priority = OfflineProcessor.QueuedCommand.CommandPriority(rawValue: self.priority) ?? .normal
        let capabilities = Set(requiredCapabilities.compactMap { OfflineProcessor.OfflineCapability(rawValue: $0) })
        
        var command = OfflineProcessor.QueuedCommand(
            text: text,
            timestamp: timestamp,
            audioData: audioData,
            priority: priority,
            requiredCapabilities: capabilities
        )
        command.processingAttempts = processingAttempts
        command.lastProcessingError = lastProcessingError
        
        return command
    }
}