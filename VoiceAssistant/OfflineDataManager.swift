import Foundation
import CryptoKit
import EventKit
import Contacts
import CoreLocation

@MainActor
class OfflineDataManager: ObservableObject {
    
    static let shared = OfflineDataManager()
    
    // MARK: - Published Properties
    @Published var cachedDataSize: Int64 = 0
    @Published var lastCacheUpdate: Date?
    @Published var cacheStatus: CacheStatus = .empty
    @Published var storageUsage: StorageUsage = StorageUsage()
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let encryption = DataEncryption()
    private let calendar = Calendar.current
    private var cacheDirectory: URL
    private var dataDirectory: URL
    
    // MARK: - Cache Configuration
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 3600 // 7 days
    private let compressionEnabled = true
    
    // MARK: - Data Types
    enum CacheStatus {
        case empty, loading, cached, outdated, error
        
        var description: String {
            switch self {
            case .empty: return "No cached data"
            case .loading: return "Loading data..."
            case .cached: return "Data cached"
            case .outdated: return "Cache outdated"
            case .error: return "Cache error"
            }
        }
    }
    
    struct StorageUsage {
        var calendars: Int64 = 0
        var contacts: Int64 = 0
        var reminders: Int64 = 0
        var weather: Int64 = 0
        var conversations: Int64 = 0
        var media: Int64 = 0
        var total: Int64 { calendars + contacts + reminders + weather + conversations + media }
        
        func formattedSize(_ bytes: Int64) -> String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: bytes)
        }
    }
    
    // MARK: - Initialization
    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.dataDirectory = documentsPath.appendingPathComponent("VoiceAssistantData")
        self.cacheDirectory = dataDirectory.appendingPathComponent("Cache")
        
        setupDirectories()
        calculateStorageUsage()
        
        // Start periodic cleanup
        startPeriodicMaintenance()
    }
    
    // MARK: - Calendar Caching
    func cacheCalendarEvents() async {
        guard await requestCalendarAccess() else {
            print("Calendar access denied")
            return
        }
        
        cacheStatus = .loading
        
        do {
            let events = await fetchCalendarEvents()
            let cachedEvents = events.map { CachedCalendarEvent(from: $0) }
            
            let data = try JSONEncoder().encode(cachedEvents)
            let encryptedData = try encryption.encrypt(data)
            
            let cacheFile = cacheDirectory.appendingPathComponent("calendar_events.cache")
            try encryptedData.write(to: cacheFile)
            
            await updateStorageUsage(\.calendars, size: Int64(encryptedData.count))
            cacheStatus = .cached
            lastCacheUpdate = Date()
            
            print("Cached \(events.count) calendar events")
        } catch {
            print("Failed to cache calendar events: \(error)")
            cacheStatus = .error
        }
    }
    
    func getCachedCalendarEvents() async -> [CachedCalendarEvent] {
        do {
            let cacheFile = cacheDirectory.appendingPathComponent("calendar_events.cache")
            guard fileManager.fileExists(atPath: cacheFile.path) else { return [] }
            
            let encryptedData = try Data(contentsOf: cacheFile)
            let data = try encryption.decrypt(encryptedData)
            let events = try JSONDecoder().decode([CachedCalendarEvent].self, from: data)
            
            // Filter out old events (older than 30 days)
            let cutoffDate = Date().addingTimeInterval(-30 * 24 * 3600)
            return events.filter { $0.date > cutoffDate }
        } catch {
            print("Failed to load cached calendar events: \(error)")
            return []
        }
    }
    
    func hasCalendarCache() -> Bool {
        let cacheFile = cacheDirectory.appendingPathComponent("calendar_events.cache")
        return fileManager.fileExists(atPath: cacheFile.path)
    }
    
    // MARK: - Contact Caching
    func cacheContacts() async {
        guard await requestContactsAccess() else {
            print("Contacts access denied")
            return
        }
        
        do {
            let contacts = await fetchContacts()
            let cachedContacts = contacts.map { CachedContact(from: $0) }
            
            let data = try JSONEncoder().encode(cachedContacts)
            let encryptedData = try encryption.encrypt(data)
            
            let cacheFile = cacheDirectory.appendingPathComponent("contacts.cache")
            try encryptedData.write(to: cacheFile)
            
            await updateStorageUsage(\.contacts, size: Int64(encryptedData.count))
            
            print("Cached \(contacts.count) contacts")
        } catch {
            print("Failed to cache contacts: \(error)")
        }
    }
    
    func getCachedContacts() async -> [CachedContact] {
        do {
            let cacheFile = cacheDirectory.appendingPathComponent("contacts.cache")
            guard fileManager.fileExists(atPath: cacheFile.path) else { return [] }
            
            let encryptedData = try Data(contentsOf: cacheFile)
            let data = try encryption.decrypt(encryptedData)
            return try JSONDecoder().decode([CachedContact].self, from: data)
        } catch {
            print("Failed to load cached contacts: \(error)")
            return []
        }
    }
    
    func hasContactsAccess() -> Bool {
        return CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }
    
    // MARK: - Weather Caching
    func cacheWeatherData(_ weatherData: WeatherData) async {
        do {
            let data = try JSONEncoder().encode(weatherData)
            let encryptedData = try encryption.encrypt(data)
            
            let cacheFile = cacheDirectory.appendingPathComponent("weather.cache")
            try encryptedData.write(to: cacheFile)
            
            await updateStorageUsage(\.weather, size: Int64(encryptedData.count))
            
            print("Cached weather data for \(weatherData.location)")
        } catch {
            print("Failed to cache weather data: \(error)")
        }
    }
    
    func getCachedWeatherData() async -> WeatherData? {
        do {
            let cacheFile = cacheDirectory.appendingPathComponent("weather.cache")
            guard fileManager.fileExists(atPath: cacheFile.path) else { return nil }
            
            let encryptedData = try Data(contentsOf: cacheFile)
            let data = try encryption.decrypt(encryptedData)
            let weatherData = try JSONDecoder().decode(WeatherData.self, from: data)
            
            // Check if data is fresh (less than 1 hour old)
            if weatherData.timestamp.timeIntervalSinceNow > -3600 {
                return weatherData
            }
            
            return nil
        } catch {
            print("Failed to load cached weather data: \(error)")
            return nil
        }
    }
    
    func hasWeatherCache() -> Bool {
        let cacheFile = cacheDirectory.appendingPathComponent("weather.cache")
        guard fileManager.fileExists(atPath: cacheFile.path) else { return false }
        
        // Check if cache is recent (less than 6 hours old)
        do {
            let attributes = try fileManager.attributesOfItem(atPath: cacheFile.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                return modificationDate.timeIntervalSinceNow > -21600 // 6 hours
            }
        } catch {}
        
        return false
    }
    
    // MARK: - Reminders Management  
    func saveReminder(_ reminder: LocalReminder) async {
        do {
            var reminders = await getStoredReminders()
            reminders.append(reminder)
            
            let data = try JSONEncoder().encode(reminders)
            let encryptedData = try encryption.encrypt(data)
            
            let reminderFile = dataDirectory.appendingPathComponent("reminders.data")
            try encryptedData.write(to: reminderFile)
            
            await updateStorageUsage(\.reminders, size: Int64(encryptedData.count))
            
            print("Saved reminder: \(reminder.text)")
        } catch {
            print("Failed to save reminder: \(error)")
        }
    }
    
    func getStoredReminders() async -> [LocalReminder] {
        do {
            let reminderFile = dataDirectory.appendingPathComponent("reminders.data")
            guard fileManager.fileExists(atPath: reminderFile.path) else { return [] }
            
            let encryptedData = try Data(contentsOf: reminderFile)
            let data = try encryption.decrypt(encryptedData)
            return try JSONDecoder().decode([LocalReminder].self, from: data)
        } catch {
            print("Failed to load reminders: \(error)")
            return []
        }
    }
    
    func updateReminder(_ reminder: LocalReminder) async {
        do {
            var reminders = await getStoredReminders()
            if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[index] = reminder
                
                let data = try JSONEncoder().encode(reminders)
                let encryptedData = try encryption.encrypt(data)
                
                let reminderFile = dataDirectory.appendingPathComponent("reminders.data")
                try encryptedData.write(to: reminderFile)
                
                await updateStorageUsage(\.reminders, size: Int64(encryptedData.count))
            }
        } catch {
            print("Failed to update reminder: \(error)")
        }
    }
    
    func deleteReminder(_ reminderId: UUID) async {
        do {
            var reminders = await getStoredReminders()
            reminders.removeAll { $0.id == reminderId }
            
            let data = try JSONEncoder().encode(reminders)
            let encryptedData = try encryption.encrypt(data)
            
            let reminderFile = dataDirectory.appendingPathComponent("reminders.data")
            try encryptedData.write(to: reminderFile)
            
            await updateStorageUsage(\.reminders, size: Int64(encryptedData.count))
        } catch {
            print("Failed to delete reminder: \(error)")
        }
    }
    
    // MARK: - Conversation Caching
    func cacheConversation(_ messages: [ConversationMessage]) async {
        do {
            let data = try JSONEncoder().encode(messages)
            let encryptedData = try encryption.encrypt(data)
            
            let conversationFile = dataDirectory.appendingPathComponent("conversation_cache.data")
            try encryptedData.write(to: conversationFile)
            
            await updateStorageUsage(\.conversations, size: Int64(encryptedData.count))
        } catch {
            print("Failed to cache conversation: \(error)")
        }
    }
    
    func getCachedConversation() async -> [ConversationMessage] {
        do {
            let conversationFile = dataDirectory.appendingPathComponent("conversation_cache.data")
            guard fileManager.fileExists(atPath: conversationFile.path) else { return [] }
            
            let encryptedData = try Data(contentsOf: conversationFile)
            let data = try encryption.decrypt(encryptedData)
            return try JSONDecoder().decode([ConversationMessage].self, from: data)
        } catch {
            print("Failed to load cached conversation: \(error)")
            return []
        }
    }
    
    // MARK: - Predictive Pre-loading
    func preloadUserData() async {
        print("Starting predictive data pre-loading...")
        
        // Pre-load calendar events for next week
        await cacheCalendarEvents()
        
        // Pre-load contacts if permission granted
        if hasContactsAccess() {
            await cacheContacts()
        }
        
        // Pre-load weather data if location available
        if let location = await getCurrentLocation() {
            await preloadWeatherData(for: location)
        }
        
        print("Predictive pre-loading completed")
    }
    
    private func preloadWeatherData(for location: CLLocation) async {
        // This would integrate with weather API
        // For now, create mock weather data
        let weatherData = WeatherData(
            location: "Current Location",
            temperature: 72.0,
            condition: "Partly Cloudy",
            humidity: 45,
            windSpeed: 8.5,
            timestamp: Date()
        )
        
        await cacheWeatherData(weatherData)
    }
    
    // MARK: - Data Synchronization
    func syncCachedData() async {
        print("Syncing cached data with server...")
        
        // This would integrate with the backend API
        // For now, just update the last sync time
        lastCacheUpdate = Date()
        
        // Sync reminders to server
        let reminders = await getStoredReminders()
        for reminder in reminders where !reminder.synced {
            await syncReminderToServer(reminder)
        }
        
        print("Data sync completed")
    }
    
    private func syncReminderToServer(_ reminder: LocalReminder) async {
        // This would make API call to sync reminder
        // For now, just mark as synced
        var updatedReminder = reminder
        updatedReminder.synced = true
        await updateReminder(updatedReminder)
    }
    
    // MARK: - Storage Management
    func getCachedDataSize() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: cachedDataSize)
    }
    
    func cleanupOldData() async {
        let cutoffDate = Date().addingTimeInterval(-maxCacheAge)
        
        do {
            let cacheContents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            
            for fileURL in cacheContents {
                let attributes = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                if let modificationDate = attributes.contentModificationDate,
                   modificationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                    print("Cleaned up old cache file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("Failed to cleanup old data: \(error)")
        }
        
        calculateStorageUsage()
    }
    
    func clearAllCache() async {
        do {
            let cacheContents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in cacheContents {
                try fileManager.removeItem(at: fileURL)
            }
            
            storageUsage = StorageUsage()
            cachedDataSize = 0
            cacheStatus = .empty
            
            print("Cleared all cached data")
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }
    
    func optimizeStorage() async {
        print("Optimizing storage...")
        
        // Remove old cache files
        await cleanupOldData()
        
        // Compress large files if needed
        if compressionEnabled {
            await compressLargeFiles()
        }
        
        // Update storage calculations
        calculateStorageUsage()
        
        print("Storage optimization completed")
    }
    
    private func compressLargeFiles() async {
        // Implementation for compressing large cache files
        // This would use NSData compression APIs
        print("Compressing large cache files...")
    }
    
    // MARK: - Private Implementation
    private func setupDirectories() {
        do {
            try fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to setup directories: \(error)")
        }
    }
    
    private func calculateStorageUsage() {
        Task {
            var usage = StorageUsage()
            
            do {
                // Calculate cache sizes
                let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
                while let fileURL = enumerator?.nextObject() as? URL {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                        let fileSize = Int64(resourceValues.fileSize ?? 0)
                        
                        switch fileURL.lastPathComponent {
                        case let name where name.contains("calendar"):
                            usage.calendars += fileSize
                        case let name where name.contains("contact"):
                            usage.contacts += fileSize
                        case let name where name.contains("reminder"):
                            usage.reminders += fileSize
                        case let name where name.contains("weather"):
                            usage.weather += fileSize
                        case let name where name.contains("conversation"):
                            usage.conversations += fileSize
                        default:
                            usage.media += fileSize
                        }
                }
                
                await MainActor.run {
                    self.storageUsage = usage
                    self.cachedDataSize = usage.total
                }
            } catch {
                print("Failed to calculate storage usage: \(error)")
            }
        }
    }
    
    private func updateStorageUsage(_ category: WritableKeyPath<StorageUsage, Int64>, size: Int64) async {
        storageUsage[keyPath: category] = size
        cachedDataSize = storageUsage.total
    }
    
    private func startPeriodicMaintenance() {
        Task {
            while true {
                // Run maintenance every 6 hours
                try? await Task.sleep(nanoseconds: 6 * 3600 * 1_000_000_000)
                await cleanupOldData()
                
                // Optimize storage if cache is getting large
                if cachedDataSize > maxCacheSize * 3/4 {
                    await optimizeStorage()
                }
            }
        }
    }
    
    // MARK: - Permission Requests
    private func requestCalendarAccess() async -> Bool {
        let eventStore = EKEventStore()
        
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            return true
        case .notDetermined:
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                return false
            }
        default:
            return false
        }
    }
    
    private func requestContactsAccess() async -> Bool {
        let contactStore = CNContactStore()
        
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            return true
        case .notDetermined:
            do {
                return try await contactStore.requestAccess(for: .contacts)
            } catch {
                return false
            }
        default:
            return false
        }
    }
    
    // MARK: - Data Fetching
    private func fetchCalendarEvents() async -> [EKEvent] {
        let eventStore = EKEventStore()
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate) ?? startDate
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    private func fetchContacts() async -> [CNContact] {
        let contactStore = CNContactStore()
        let keysToFetch = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
        
        do {
            var contacts: [CNContact] = []
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            
            try contactStore.enumerateContacts(with: request) { contact, _ in
                contacts.append(contact)
            }
            
            return contacts
        } catch {
            print("Failed to fetch contacts: \(error)")
            return []
        }
    }
    
    private func getCurrentLocation() async -> CLLocation? {
        // This would use CoreLocation to get current location
        // For privacy reasons, returning nil by default
        return nil
    }
}

// MARK: - Data Encryption
private class DataEncryption {
    private let key: SymmetricKey
    
    init() {
        // Generate or retrieve encryption key from Keychain
        if let keyData = KeychainManager.getEncryptionKey() {
            self.key = SymmetricKey(data: keyData)
        } else {
            self.key = SymmetricKey(size: .bits256)
            KeychainManager.saveEncryptionKey(key.withUnsafeBytes { Data($0) })
        }
    }
    
    func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }
    
    func decrypt(_ encryptedData: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
}

// MARK: - Keychain Management
private class KeychainManager {
    private static let service = "VoiceAssistant.OfflineData"
    private static let account = "EncryptionKey"
    
    static func saveEncryptionKey(_ keyData: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData
        ]
        
        SecItemDelete(query as CFDictionary) // Remove any existing key
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func getEncryptionKey() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        return status == errSecSuccess ? (result as? Data) : nil
    }
}

// MARK: - Supporting Models Extensions
extension CachedCalendarEvent {
    init(from event: EKEvent) {
        self.id = event.eventIdentifier
        self.title = event.title
        self.date = event.startDate
        self.duration = event.endDate.timeIntervalSince(event.startDate)
        self.location = event.location
    }
}

extension CachedContact: Codable {
    init(from contact: CNContact) {
        self.id = contact.identifier
        self.name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        self.phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
        self.emailAddresses = contact.emailAddresses.map { $0.value as String }
    }
}

struct CachedContact {
    let id: String
    let name: String
    let phoneNumbers: [String]
    let emailAddresses: [String]
}

struct WeatherData: Codable {
    let location: String
    let temperature: Double
    let condition: String
    let humidity: Int
    let windSpeed: Double
    let timestamp: Date
}

extension LocalReminder {
    var synced: Bool {
        get { UserDefaults.standard.bool(forKey: "reminder_synced_\(id.uuidString)") }
        set { UserDefaults.standard.set(newValue, forKey: "reminder_synced_\(id.uuidString)") }
    }
}

extension LocalReminder: Codable {
    enum CodingKeys: String, CodingKey {
        case id, text, createdDate, isCompleted, priority
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        priority = try container.decode(Priority.self, forKey: .priority)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(priority, forKey: .priority)
    }
}