import Foundation
import Contacts
import EventKit
import CoreData
import CryptoKit

class VocabularyManager: ObservableObject {
    @Published var isLoaded = false
    @Published var vocabularyCount = 0
    @Published var domainTermsCount = 0
    
    private let userDefaults = UserDefaults.standard
    private let contactStore = CNContactStore()
    private let eventStore = EKEventStore()
    
    // Vocabulary storage
    private var customVocabulary: Set<String> = []
    private var contactNames: Set<String> = []
    private var calendarEvents: Set<String> = []
    private var frequentTerms: [String: Int] = [:]
    private var domainSpecificTerms: [VocabularyDomain: Set<String>] = [:]
    private var userCorrections: [String: String] = [:]
    
    // Privacy and encryption
    private let encryptionKey: SymmetricKey
    private let vocabularyVersion = "1.0"
    
    // Performance tracking
    private var lastUpdateTime: Date = Date.distantPast
    private let updateInterval: TimeInterval = 3600 // 1 hour
    
    enum VocabularyDomain: String, CaseIterable {
        case contacts = "contacts"
        case calendar = "calendar"
        case email = "email"
        case tasks = "tasks"
        case locations = "locations"
        case apps = "apps"
        case custom = "custom"
        case medical = "medical"
        case technical = "technical"
        case business = "business"
    }
    
    init() {
        // Generate or retrieve encryption key for privacy
        if let keyData = userDefaults.data(forKey: "vocabulary_encryption_key") {
            self.encryptionKey = SymmetricKey(data: keyData)
        } else {
            let newKey = SymmetricKey(size: .bits256)
            userDefaults.set(newKey.withUnsafeBytes { Data($0) }, forKey: "vocabulary_encryption_key")
            self.encryptionKey = newKey
        }
        
        Task {
            await loadUserVocabulary()
        }
    }
    
    // MARK: - Vocabulary Loading
    
    func loadUserVocabulary() async {
        print("📚 VocabularyManager: Loading user vocabulary")
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadCustomVocabulary() }
            group.addTask { await self.loadContactNames() }
            group.addTask { await self.loadCalendarEvents() }
            group.addTask { await self.loadFrequentTerms() }
            group.addTask { await self.loadDomainSpecificTerms() }
            group.addTask { await self.loadUserCorrections() }
        }
        
        DispatchQueue.main.async {
            self.isLoaded = true
            self.updateCounts()
            print("✅ VocabularyManager: Vocabulary loaded (\(self.vocabularyCount) total terms)")
        }
    }
    
    private func loadCustomVocabulary() async {
        if let data = userDefaults.data(forKey: "custom_vocabulary") {
            do {
                let decryptedData = try await decrypt(data)
                let terms = try JSONDecoder().decode([String].self, from: decryptedData)
                customVocabulary = Set(terms)
                print("📝 Loaded \(customVocabulary.count) custom vocabulary terms")
            } catch {
                print("❌ Failed to load custom vocabulary: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadContactNames() async {
        do {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            
            switch status {
            case .authorized:
                let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey] as [CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch: keys)
                
                var names: Set<String> = []
                
                try contactStore.enumerateContacts(with: request) { contact, _ in
                    if !contact.givenName.isEmpty {
                        names.insert(contact.givenName.lowercased())
                    }
                    if !contact.familyName.isEmpty {
                        names.insert(contact.familyName.lowercased())
                        // Add full name
                        let fullName = "\(contact.givenName) \(contact.familyName)".lowercased()
                        names.insert(fullName)
                    }
                    if !contact.nickname.isEmpty {
                        names.insert(contact.nickname.lowercased())
                    }
                }
                
                contactNames = names
                print("👥 Loaded \(contactNames.count) contact names")
                
            case .notDetermined:
                // Request permission
                try await contactStore.requestAccess(for: .contacts)
                await loadContactNames()
                
            case .denied, .restricted, .limited:
                print("⚠️ Contact access denied, restricted, or limited")
                
            @unknown default:
                print("⚠️ Unknown contact authorization status")
            }
        } catch {
            print("❌ Failed to load contact names: \(error.localizedDescription)")
        }
    }
    
    private func loadCalendarEvents() async {
        do {
            let status = EKEventStore.authorizationStatus(for: .event)
            
            switch status {
            case .fullAccess, .writeOnly:
                let calendar = Calendar.current
                let startDate = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                let endDate = calendar.date(byAdding: .month, value: 2, to: Date()) ?? Date()
                
                let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
                let events = eventStore.events(matching: predicate)
                
                var eventTerms: Set<String> = []
                
                for event in events {
                    // Add event title words
                    let titleWords = event.title.lowercased()
                        .components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty && $0.count > 2 }
                    eventTerms.formUnion(titleWords)
                    
                    // Add location if available
                    if let location = event.location, !location.isEmpty {
                        let locationWords = location.lowercased()
                            .components(separatedBy: .whitespacesAndNewlines)
                            .filter { !$0.isEmpty && $0.count > 2 }
                        eventTerms.formUnion(locationWords)
                    }
                }
                
                calendarEvents = eventTerms
                print("📅 Loaded \(calendarEvents.count) calendar terms")
                
            case .notDetermined:
                // Request permission
                try await eventStore.requestFullAccessToEvents()
                await loadCalendarEvents()
                
            case .denied, .restricted:
                print("⚠️ Calendar access denied or restricted")
                
            @unknown default:
                print("⚠️ Unknown calendar authorization status")
            }
        } catch {
            print("❌ Failed to load calendar events: \(error.localizedDescription)")
        }
    }
    
    private func loadFrequentTerms() async {
        if let data = userDefaults.data(forKey: "frequent_terms") {
            do {
                let decryptedData = try await decrypt(data)
                let terms = try JSONDecoder().decode([String: Int].self, from: decryptedData)
                frequentTerms = terms
                print("🔄 Loaded \(frequentTerms.count) frequent terms")
            } catch {
                print("❌ Failed to load frequent terms: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadDomainSpecificTerms() async {
        for domain in VocabularyDomain.allCases {
            await loadDomainTerms(domain)
        }
    }
    
    private func loadDomainTerms(_ domain: VocabularyDomain) async {
        let key = "domain_terms_\(domain.rawValue)"
        
        if let data = userDefaults.data(forKey: key) {
            do {
                let decryptedData = try await decrypt(data)
                let terms = try JSONDecoder().decode([String].self, from: decryptedData)
                domainSpecificTerms[domain] = Set(terms)
                print("🏷️ Loaded \(terms.count) terms for \(domain.rawValue) domain")
            } catch {
                print("❌ Failed to load \(domain.rawValue) domain terms: \(error.localizedDescription)")
            }
        } else {
            // Initialize with default terms for each domain
            domainSpecificTerms[domain] = getDefaultTerms(for: domain)
        }
    }
    
    private func loadUserCorrections() async {
        if let data = userDefaults.data(forKey: "user_corrections") {
            do {
                let decryptedData = try await decrypt(data)
                let corrections = try JSONDecoder().decode([String: String].self, from: decryptedData)
                userCorrections = corrections
                print("✏️ Loaded \(userCorrections.count) user corrections")
            } catch {
                print("❌ Failed to load user corrections: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Vocabulary Enhancement
    
    func applyVocabularyBoosting(_ candidates: [TranscriptionCandidate]) async -> [TranscriptionCandidate] {
        print("🚀 VocabularyManager: Applying vocabulary boosting to \(candidates.count) candidates")
        
        var boostedCandidates: [TranscriptionCandidate] = []
        
        for candidate in candidates {
            let boostedCandidate = await boostCandidate(candidate)
            boostedCandidates.append(boostedCandidate)
        }
        
        // Sort by confidence after boosting
        return boostedCandidates.sorted { $0.confidence > $1.confidence }
    }
    
    private func boostCandidate(_ candidate: TranscriptionCandidate) async -> TranscriptionCandidate {
        let originalText = candidate.text.lowercased()
        var boostedText = originalText
        var confidenceBoost: Float = 0.0
        
        // Apply user corrections first
        for (incorrect, correct) in userCorrections {
            if boostedText.contains(incorrect.lowercased()) {
                boostedText = boostedText.replacingOccurrences(of: incorrect.lowercased(), with: correct.lowercased())
                confidenceBoost += 0.1
            }
        }
        
        // Boost for contact names
        for contactName in contactNames {
            if boostedText.contains(contactName) {
                confidenceBoost += 0.05
            }
        }
        
        // Boost for calendar event terms
        for eventTerm in calendarEvents {
            if boostedText.contains(eventTerm) {
                confidenceBoost += 0.03
            }
        }
        
        // Boost for frequent terms
        let words = boostedText.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            if let frequency = frequentTerms[word] {
                let boost = min(0.02, Float(frequency) / 100.0)
                confidenceBoost += boost
            }
        }
        
        // Boost for domain-specific terms
        for (_, terms) in domainSpecificTerms {
            for term in terms {
                if boostedText.contains(term) {
                    confidenceBoost += 0.02
                }
            }
        }
        
        // Apply vocabulary-specific confidence boost
        let newConfidence = min(1.0, candidate.confidence + confidenceBoost)
        
        return TranscriptionCandidate(
            text: boostedText,
            confidence: newConfidence,
            source: candidate.source,
            segments: candidate.segments
        )
    }
    
    // MARK: - Contextual Strings for Speech Recognition
    
    func getContextualStrings() async -> [String] {
        var contextStrings: [String] = []
        
        // Add high-frequency custom terms
        contextStrings.append(contentsOf: Array(customVocabulary))
        
        // Add contact names
        contextStrings.append(contentsOf: Array(contactNames))
        
        // Add calendar event terms
        contextStrings.append(contentsOf: Array(calendarEvents))
        
        // Add frequent terms (top 100)
        let topFrequentTerms = frequentTerms
            .sorted { $0.value > $1.value }
            .prefix(100)
            .map { $0.key }
        contextStrings.append(contentsOf: topFrequentTerms)
        
        // Add domain-specific terms
        for (_, terms) in domainSpecificTerms {
            contextStrings.append(contentsOf: Array(terms))
        }
        
        // Limit total context strings to avoid performance issues
        return Array(Set(contextStrings)).prefix(500).map { $0 }
    }
    
    // MARK: - Learning from User Interactions
    
    func learnFromTranscription(_ originalText: String, correctedText: String) async {
        print("📖 VocabularyManager: Learning from user correction")
        
        if originalText.lowercased() != correctedText.lowercased() {
            // Store user correction
            userCorrections[originalText.lowercased()] = correctedText.lowercased()
            
            // Add corrected words to custom vocabulary
            let correctedWords = correctedText.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty && $0.count > 2 }
            
            customVocabulary.formUnion(correctedWords)
            
            // Update frequency tracking
            for word in correctedWords {
                frequentTerms[word, default: 0] += 1
            }
            
            await saveUserCorrections()
            await saveCustomVocabulary()
            await saveFrequentTerms()
        }
        
        // Update term frequency regardless of correction
        let words = correctedText.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.count > 2 }
        
        for word in words {
            frequentTerms[word, default: 0] += 1
        }
        
        await saveFrequentTerms()
        
        DispatchQueue.main.async {
            self.updateCounts()
        }
    }
    
    func addCustomTerm(_ term: String, domain: VocabularyDomain = .custom) async {
        print("➕ VocabularyManager: Adding custom term '\(term)' to \(domain.rawValue)")
        
        let cleanedTerm = term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTerm.isEmpty else { return }
        
        if domain == .custom {
            customVocabulary.insert(cleanedTerm)
            await saveCustomVocabulary()
        } else {
            domainSpecificTerms[domain, default: []].insert(cleanedTerm)
            await saveDomainTerms(domain)
        }
        
        // Also add to frequent terms
        frequentTerms[cleanedTerm, default: 0] += 1
        await saveFrequentTerms()
        
        DispatchQueue.main.async {
            self.updateCounts()
        }
    }
    
    func removeCustomTerm(_ term: String, domain: VocabularyDomain = .custom) async {
        let cleanedTerm = term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if domain == .custom {
            customVocabulary.remove(cleanedTerm)
            await saveCustomVocabulary()
        } else {
            domainSpecificTerms[domain]?.remove(cleanedTerm)
            await saveDomainTerms(domain)
        }
        
        DispatchQueue.main.async {
            self.updateCounts()
        }
    }
    
    // MARK: - Privacy-Preserving Sync
    
    func syncVocabularyWithPrivacy() async -> [String: Any] {
        // Create anonymized vocabulary data for sync
        var syncData: [String: Any] = [:]
        
        // Hash frequent terms to preserve privacy
        let hashedFrequentTerms = frequentTerms.compactMapValues { frequency in
            frequency > 5 ? frequency : nil // Only sync terms used more than 5 times
        }
        
        syncData["frequent_terms_count"] = hashedFrequentTerms.count
        syncData["custom_vocabulary_count"] = customVocabulary.count
        syncData["version"] = vocabularyVersion
        syncData["last_updated"] = lastUpdateTime.timeIntervalSince1970
        
        return syncData
    }
    
    // MARK: - Data Persistence
    
    private func saveCustomVocabulary() async {
        do {
            let data = try JSONEncoder().encode(Array(customVocabulary))
            let encryptedData = try await encrypt(data)
            userDefaults.set(encryptedData, forKey: "custom_vocabulary")
        } catch {
            print("❌ Failed to save custom vocabulary: \(error.localizedDescription)")
        }
    }
    
    private func saveFrequentTerms() async {
        do {
            let data = try JSONEncoder().encode(frequentTerms)
            let encryptedData = try await encrypt(data)
            userDefaults.set(encryptedData, forKey: "frequent_terms")
        } catch {
            print("❌ Failed to save frequent terms: \(error.localizedDescription)")
        }
    }
    
    private func saveDomainTerms(_ domain: VocabularyDomain) async {
        guard let terms = domainSpecificTerms[domain] else { return }
        
        do {
            let data = try JSONEncoder().encode(Array(terms))
            let encryptedData = try await encrypt(data)
            let key = "domain_terms_\(domain.rawValue)"
            userDefaults.set(encryptedData, forKey: key)
        } catch {
            print("❌ Failed to save \(domain.rawValue) domain terms: \(error.localizedDescription)")
        }
    }
    
    private func saveUserCorrections() async {
        do {
            let data = try JSONEncoder().encode(userCorrections)
            let encryptedData = try await encrypt(data)
            userDefaults.set(encryptedData, forKey: "user_corrections")
        } catch {
            print("❌ Failed to save user corrections: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Encryption/Decryption
    
    private func encrypt(_ data: Data) async throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        return sealedBox.combined!
    }
    
    private func decrypt(_ data: Data) async throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }
    
    // MARK: - Default Terms
    
    private func getDefaultTerms(for domain: VocabularyDomain) -> Set<String> {
        switch domain {
        case .contacts:
            return []
            
        case .calendar:
            return ["meeting", "appointment", "call", "conference", "lunch", "dinner", "event", "reminder"]
            
        case .email:
            return ["email", "message", "reply", "forward", "attachment", "subject", "inbox", "draft"]
            
        case .tasks:
            return ["task", "todo", "reminder", "deadline", "project", "assignment", "priority", "complete"]
            
        case .locations:
            return ["home", "work", "office", "school", "gym", "store", "restaurant", "airport", "hospital"]
            
        case .apps:
            return ["safari", "mail", "messages", "calendar", "photos", "camera", "settings", "maps"]
            
        case .medical:
            return ["doctor", "appointment", "medication", "prescription", "pharmacy", "hospital", "clinic"]
            
        case .technical:
            return ["computer", "laptop", "phone", "software", "website", "internet", "wifi", "bluetooth"]
            
        case .business:
            return ["client", "customer", "invoice", "payment", "contract", "proposal", "budget", "revenue"]
            
        case .custom:
            return []
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateCounts() {
        vocabularyCount = customVocabulary.count + contactNames.count + calendarEvents.count + frequentTerms.count
        domainTermsCount = domainSpecificTerms.values.reduce(0) { $0 + $1.count }
        lastUpdateTime = Date()
    }
    
    // MARK: - Public Interface
    
    func getAllVocabularyTerms() -> [String] {
        var allTerms: [String] = []
        allTerms.append(contentsOf: customVocabulary)
        allTerms.append(contentsOf: contactNames)
        allTerms.append(contentsOf: calendarEvents)
        allTerms.append(contentsOf: frequentTerms.keys)
        
        for terms in domainSpecificTerms.values {
            allTerms.append(contentsOf: terms)
        }
        
        return Array(Set(allTerms)).sorted()
    }
    
    func getVocabularyStats() -> VocabularyStats {
        return VocabularyStats(
            totalTerms: vocabularyCount,
            customTerms: customVocabulary.count,
            contactNames: contactNames.count,
            calendarEvents: calendarEvents.count,
            frequentTerms: frequentTerms.count,
            domainTerms: domainTermsCount,
            userCorrections: userCorrections.count,
            lastUpdated: lastUpdateTime
        )
    }
    
    func shouldUpdateVocabulary() -> Bool {
        return Date().timeIntervalSince(lastUpdateTime) > updateInterval
    }
}

// MARK: - Supporting Structures

struct VocabularyStats {
    let totalTerms: Int
    let customTerms: Int
    let contactNames: Int
    let calendarEvents: Int
    let frequentTerms: Int
    let domainTerms: Int
    let userCorrections: Int
    let lastUpdated: Date
}

// MARK: - Extensions for Contact and Calendar Access

extension VocabularyManager {
    func requestContactsPermission() async -> Bool {
        do {
            return try await contactStore.requestAccess(for: .contacts)
        } catch {
            print("❌ Failed to request contacts permission: \(error.localizedDescription)")
            return false
        }
    }
    
    func requestCalendarPermission() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            print("❌ Failed to request calendar permission: \(error.localizedDescription)")
            return false
        }
    }
}