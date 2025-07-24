import Foundation
import CoreML
import Speech
import CryptoKit

// MARK: - Data Structures

struct UserSpeechProfile: Codable {
    var accentType: AccentType
    var averageSpeakingRate: Double
    var pitchRange: Double
    var preferredLanguage: String
    
    init(accentType: AccentType, averageSpeakingRate: Double, pitchRange: Double, preferredLanguage: String) {
        self.accentType = accentType
        self.averageSpeakingRate = averageSpeakingRate
        self.pitchRange = pitchRange
        self.preferredLanguage = preferredLanguage
    }
}

struct VolumePattern: Codable {
    var average: Float
    var variation: Float
    var peaks: [Float]
    
    init() {
        self.average = 0.5
        self.variation = 0.1
        self.peaks = []
    }
}

enum AccentType: String, Codable, CaseIterable {
    case neutral = "neutral"
    case american = "american"
    case british = "british"
    case australian = "australian"
    case canadian = "canadian"
    case other = "other"
}

struct SpeechPatterns: Codable {
    var wordStress: [String: Float] = [:]
    var pausePatterns: [String: Float] = [:]
    var intonationCurves: [String: [Float]] = [:]
    var commonPhrases: [CommonPhrase] = []
    var wordOrderPatterns: [String: Float] = [:]
    
    init() {}
}

struct CommonPhrase: Codable {
    var phrase: String
    var frequency: Int
    var averageConfidence: Float
    var lastUsed: Date
    
    init(phrase: String, frequency: Int, averageConfidence: Float, lastUsed: Date) {
        self.phrase = phrase
        self.frequency = frequency
        self.averageConfidence = averageConfidence
        self.lastUsed = lastUsed
    }
}

struct SpeakingRhythm: Codable {
    var averageWordsPerMinute: Float
    var pauseDuration: Float
    var averagePauseDuration: TimeInterval
    var breathingPattern: [Float]
    
    init() {
        self.averageWordsPerMinute = 150.0
        self.pauseDuration = 0.3
        self.averagePauseDuration = 0.3
        self.breathingPattern = []
    }
}

struct ContextPattern: Codable {
    var context: String
    var keywords: [String]
    var confidence: Float
    var frequency: Int
    var lastUpdated: Date
    
    init(context: String, keywords: [String] = [], confidence: Float = 0.5, frequency: Int = 1, lastUpdated: Date = Date()) {
        self.context = context
        self.keywords = keywords
        self.confidence = confidence
        self.frequency = frequency
        self.lastUpdated = lastUpdated
    }
}

class SpeechPatternLearning: ObservableObject {
    @Published var isLearningEnabled = true
    @Published var userProfile: UserSpeechProfile?
    @Published var patternCount = 0
    @Published var adaptationAccuracy: Float = 0.0
    
    private let userDefaults = UserDefaults.standard
    private let encryptionKey: SymmetricKey
    
    // Speech patterns
    private var speechPatterns: SpeechPatterns = SpeechPatterns()
    private var pronunciationVariations: [String: Set<String>] = [:]
    private var speakingRhythm: SpeakingRhythm = SpeakingRhythm()
    private var vocabularyPreferences: [String: Float] = [:]
    private var contextualPatterns: [String: ContextPattern] = [:]
    
    // Learning parameters
    private let learningRate: Float = 0.1
    private let minSampleCount = 5
    private let adaptationThreshold: Float = 0.75
    private let maxPatternAge: TimeInterval = 30 * 24 * 3600 // 30 days
    
    // Performance tracking
    private var learningStats = LearningStatistics()
    
    init() {
        // Initialize encryption key for privacy
        if let keyData = userDefaults.data(forKey: "pattern_encryption_key") {
            self.encryptionKey = SymmetricKey(data: keyData)
        } else {
            let newKey = SymmetricKey(size: .bits256)
            userDefaults.set(newKey.withUnsafeBytes { Data($0) }, forKey: "pattern_encryption_key")
            self.encryptionKey = newKey
        }
        
        Task {
            await loadUserPatterns()
        }
    }
    
    // MARK: - Pattern Loading
    
    func loadUserPatterns() async {
        print("🧠 SpeechPatternLearning: Loading user speech patterns")
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadSpeechPatterns() }
            group.addTask { await self.loadPronunciationVariations() }
            group.addTask { await self.loadSpeakingRhythm() }
            group.addTask { await self.loadVocabularyPreferences() }
            group.addTask { await self.loadContextualPatterns() }
            group.addTask { await self.loadUserProfile() }
            group.addTask { await self.loadLearningStats() }
        }
        
        // Clean up old patterns
        await cleanupOldPatterns()
        
        DispatchQueue.main.async {
            self.updateCounts()
            print("✅ SpeechPatternLearning: Patterns loaded (\(self.patternCount) patterns)")
        }
    }
    
    private func loadSpeechPatterns() async {
        if let data = userDefaults.data(forKey: "speech_patterns") {
            do {
                let decryptedData = try await decrypt(data)
                speechPatterns = try JSONDecoder().decode(SpeechPatterns.self, from: decryptedData)
                print("📊 Loaded speech patterns")
            } catch {
                print("❌ Failed to load speech patterns: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadPronunciationVariations() async {
        if let data = userDefaults.data(forKey: "pronunciation_variations") {
            do {
                let decryptedData = try await decrypt(data)
                let decoded = try JSONDecoder().decode([String: [String]].self, from: decryptedData)
                pronunciationVariations = decoded.mapValues { Set($0) }
                print("🗣️ Loaded \(pronunciationVariations.count) pronunciation variations")
            } catch {
                print("❌ Failed to load pronunciation variations: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadSpeakingRhythm() async {
        if let data = userDefaults.data(forKey: "speaking_rhythm") {
            do {
                let decryptedData = try await decrypt(data)
                speakingRhythm = try JSONDecoder().decode(SpeakingRhythm.self, from: decryptedData)
                print("🎵 Loaded speaking rhythm patterns")
            } catch {
                print("❌ Failed to load speaking rhythm: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadVocabularyPreferences() async {
        if let data = userDefaults.data(forKey: "vocabulary_preferences") {
            do {
                let decryptedData = try await decrypt(data)
                vocabularyPreferences = try JSONDecoder().decode([String: Float].self, from: decryptedData)
                print("📝 Loaded \(vocabularyPreferences.count) vocabulary preferences")
            } catch {
                print("❌ Failed to load vocabulary preferences: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadContextualPatterns() async {
        if let data = userDefaults.data(forKey: "contextual_patterns") {
            do {
                let decryptedData = try await decrypt(data)
                contextualPatterns = try JSONDecoder().decode([String: ContextPattern].self, from: decryptedData)
                print("🎯 Loaded \(contextualPatterns.count) contextual patterns")
            } catch {
                print("❌ Failed to load contextual patterns: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadUserProfile() async {
        if let data = userDefaults.data(forKey: "user_speech_profile") {
            do {
                let decryptedData = try await decrypt(data)
                userProfile = try JSONDecoder().decode(UserSpeechProfile.self, from: decryptedData)
                print("👤 Loaded user speech profile")
            } catch {
                print("❌ Failed to load user speech profile: \(error.localizedDescription)")
            }
        } else {
            // Create initial profile
            userProfile = UserSpeechProfile(
                accentType: .american,
                averageSpeakingRate: 150.0,
                pitchRange: 200.0,
                preferredLanguage: "en-US"
            )
        }
    }
    
    private func loadLearningStats() async {
        if let data = userDefaults.data(forKey: "learning_statistics") {
            do {
                let decryptedData = try await decrypt(data)
                learningStats = try JSONDecoder().decode(LearningStatistics.self, from: decryptedData)
                print("📈 Loaded learning statistics")
            } catch {
                print("❌ Failed to load learning statistics: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Pattern Enhancement
    
    func enhanceWithPatterns(_ candidates: [TranscriptionCandidate]) async -> [TranscriptionCandidate] {
        print("🎯 SpeechPatternLearning: Enhancing \(candidates.count) candidates with learned patterns")
        
        guard isLearningEnabled, userProfile != nil else {
            return candidates
        }
        
        var enhancedCandidates: [TranscriptionCandidate] = []
        
        for candidate in candidates {
            let enhancedCandidate = await enhanceCandidate(candidate)
            enhancedCandidates.append(enhancedCandidate)
        }
        
        return enhancedCandidates.sorted { $0.confidence > $1.confidence }
    }
    
    private func enhanceCandidate(_ candidate: TranscriptionCandidate) async -> TranscriptionCandidate {
        var enhancedText = candidate.text
        var confidenceBoost: Float = 0.0
        
        // Apply pronunciation variations
        enhancedText = await applyPronunciationCorrections(enhancedText)
        
        // Apply vocabulary preferences
        let vocabularyBoost = await applyVocabularyPreferences(enhancedText)
        confidenceBoost += vocabularyBoost
        
        // Apply contextual patterns
        let contextBoost = await applyContextualPatterns(enhancedText)
        confidenceBoost += contextBoost
        
        // Apply speaking rhythm adjustments
        let rhythmBoost = await applySpeakingRhythm(candidate.segments)
        confidenceBoost += rhythmBoost
        
        // Apply user-specific speech patterns
        let patternBoost = await applySpeechPatterns(enhancedText)
        confidenceBoost += patternBoost
        
        let newConfidence = min(1.0, candidate.confidence + confidenceBoost)
        
        return TranscriptionCandidate(
            text: enhancedText,
            confidence: newConfidence,
            source: candidate.source,
            segments: candidate.segments
        )
    }
    
    private func applyPronunciationCorrections(_ text: String) async -> String {
        var correctedText = text
        
        for (standardPronunciation, variations) in pronunciationVariations {
            for variation in variations {
                if correctedText.lowercased().contains(variation.lowercased()) {
                    correctedText = correctedText.replacingOccurrences(
                        of: variation,
                        with: standardPronunciation,
                        options: .caseInsensitive
                    )
                }
            }
        }
        
        return correctedText
    }
    
    private func applyVocabularyPreferences(_ text: String) async -> Float {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var boost: Float = 0.0
        
        for word in words {
            if let preference = vocabularyPreferences[word] {
                boost += preference * 0.01 // Small boost based on preference strength
            }
        }
        
        return min(0.1, boost) // Cap the boost
    }
    
    private func applyContextualPatterns(_ text: String) async -> Float {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let timeContext = getTimeContext(hour: currentHour)
        
        if let pattern = contextualPatterns[timeContext] {
            for keyword in pattern.keywords {
                if text.lowercased().contains(keyword.lowercased()) {
                    return pattern.confidence * 0.05
                }
            }
        }
        
        return 0.0
    }
    
    private func applySpeakingRhythm(_ segments: [TranscriptionSegment]) async -> Float {
        guard segments.count > 1 else { return 0.0 }
        
        // Calculate speaking rate from segments
        let totalDuration = segments.last!.timestamp + segments.last!.duration - segments.first!.timestamp
        let wordCount = segments.count
        let wordsPerMinute = Double(wordCount) / (totalDuration / 60.0)
        
        // Compare to user's typical speaking rate
        let expectedRate = userProfile?.averageSpeakingRate ?? 150.0
        let rateDifference = abs(wordsPerMinute - expectedRate) / expectedRate
        
        // Boost confidence if speaking rate matches user's pattern
        if rateDifference < 0.2 { // Within 20% of expected rate
            return 0.02
        }
        
        return 0.0
    }
    
    private func applySpeechPatterns(_ text: String) async -> Float {
        var boost: Float = 0.0
        
        // Check for common phrase patterns
        for pattern in speechPatterns.commonPhrases {
            if text.lowercased().contains(pattern.phrase.lowercased()) {
                boost += Float(pattern.frequency) * 0.001
            }
        }
        
        // Check for word order patterns
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        for i in 0..<words.count - 1 {
            let bigram = "\(words[i]) \(words[i + 1])"
            if let pattern = speechPatterns.wordOrderPatterns[bigram.lowercased()] {
                boost += pattern * 0.002
            }
        }
        
        return min(0.05, boost)
    }
    
    // MARK: - Learning from Results
    
    func learnFromResult(_ result: EnhancedTranscriptionResult) async {
        guard isLearningEnabled else { return }
        
        print("🧠 Learning from transcription result")
        
        let text = result.text
        let confidence = result.confidence
        let segments = result.candidates.first?.segments ?? []
        
        // Learn vocabulary preferences
        await learnVocabularyPreferences(text, confidence: confidence)
        
        // Learn pronunciation patterns
        await learnPronunciationPatterns(text, segments: segments)
        
        // Learn speaking rhythm
        await learnSpeakingRhythm(segments)
        
        // Learn contextual patterns
        await learnContextualPatterns(text, confidence: confidence)
        
        // Update speech patterns
        await updateSpeechPatterns(text, confidence: confidence)
        
        // Update statistics
        await updateLearningStats(result)
        
        // Save learned patterns
        await saveAllPatterns()
        
        DispatchQueue.main.async {
            self.updateCounts()
        }
    }
    
    private func learnVocabularyPreferences(_ text: String, confidence: Float) async {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            if word.count > 2 {
                let currentPreference = vocabularyPreferences[word] ?? 0.0
                let newPreference = currentPreference + (confidence - 0.5) * learningRate
                vocabularyPreferences[word] = max(0.0, min(1.0, newPreference))
            }
        }
    }
    
    private func learnPronunciationPatterns(_ text: String, segments: [TranscriptionSegment]) async {
        // Analyze segments for potential pronunciation variations
        for segment in segments {
            if segment.confidence < adaptationThreshold {
                let segmentText = segment.text.lowercased()
                
                // Find similar words in existing vocabulary
                for (standardWord, variations) in pronunciationVariations {
                    let similarity = calculateStringSimilarity(segmentText, standardWord)
                    if similarity > 0.7 && similarity < 1.0 {
                        // This might be a pronunciation variation
                        var updatedVariations = variations
                        updatedVariations.insert(segmentText)
                        pronunciationVariations[standardWord] = updatedVariations
                    }
                }
            }
        }
    }
    
    private func learnSpeakingRhythm(_ segments: [TranscriptionSegment]) async {
        guard segments.count > 1 else { return }
        
        // Calculate pause durations between segments
        var pauseDurations: [TimeInterval] = []
        for i in 0..<segments.count - 1 {
            let currentEnd = segments[i].timestamp + segments[i].duration
            let nextStart = segments[i + 1].timestamp
            let pauseDuration = nextStart - currentEnd
            if pauseDuration > 0 {
                pauseDurations.append(pauseDuration)
            }
        }
        
        // Update speaking rhythm patterns
        if !pauseDurations.isEmpty {
            let averagePause = pauseDurations.reduce(0, +) / Double(pauseDurations.count)
            speakingRhythm.averagePauseDuration = TimeInterval(updateAverage(
                current: speakingRhythm.averagePauseDuration,
                new: averagePause,
                weight: learningRate
            ))
        }
        
        // Update speaking rate
        let totalDuration = segments.last!.timestamp + segments.last!.duration - segments.first!.timestamp
        let wordsPerMinute = Double(segments.count) / (totalDuration / 60.0)
        
        if let profile = userProfile {
            let updatedRate = updateAverage(
                current: profile.averageSpeakingRate,
                new: wordsPerMinute,
                weight: Double(learningRate)
            )
            
            userProfile = UserSpeechProfile(
                accentType: profile.accentType,
                averageSpeakingRate: updatedRate,
                pitchRange: profile.pitchRange,
                preferredLanguage: profile.preferredLanguage
            )
        }
    }
    
    private func learnContextualPatterns(_ text: String, confidence: Float) async {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let timeContext = getTimeContext(hour: currentHour)
        
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var pattern = contextualPatterns[timeContext] ?? ContextPattern(
            context: timeContext,
            keywords: [],
            confidence: 0.5,
            frequency: 0,
            lastUpdated: Date()
        )
        
        // Add high-confidence words as keywords for this context
        if confidence > adaptationThreshold {
            let newKeywords = words.filter { $0.count > 3 }
            pattern.keywords.append(contentsOf: newKeywords)
            pattern.keywords = Array(Set(pattern.keywords)) // Remove duplicates
        }
        
        pattern.frequency += 1
        pattern.confidence = Float(updateAverage(
            current: Double(pattern.confidence),
            new: Double(confidence),
            weight: Double(learningRate)
        ))
        pattern.lastUpdated = Date()
        
        contextualPatterns[timeContext] = pattern
    }
    
    private func updateSpeechPatterns(_ text: String, confidence: Float) async {
        // Update common phrases
        let phrases = extractPhrases(from: text)
        for phrase in phrases {
            if let existingPhrase = speechPatterns.commonPhrases.first(where: { $0.phrase == phrase }) {
                var updatedPhrase = existingPhrase
                updatedPhrase.frequency += 1
                updatedPhrase.averageConfidence = Float(updateAverage(
                    current: Double(existingPhrase.averageConfidence),
                    new: Double(confidence),
                    weight: Double(learningRate)
                ))
            } else if confidence > adaptationThreshold {
                let newPhrase = CommonPhrase(
                    phrase: phrase,
                    frequency: 1,
                    averageConfidence: confidence,
                    lastUsed: Date()
                )
                speechPatterns.commonPhrases.append(newPhrase)
            }
        }
        
        // Update word order patterns
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        for i in 0..<words.count - 1 {
            let bigram = "\(words[i]) \(words[i + 1])".lowercased()
            let currentFreq = speechPatterns.wordOrderPatterns[bigram] ?? 0.0
            speechPatterns.wordOrderPatterns[bigram] = currentFreq + confidence * learningRate
        }
    }
    
    private func updateLearningStats(_ result: EnhancedTranscriptionResult) async {
        learningStats.totalTranscriptions += 1
        learningStats.totalConfidence += Double(result.confidence)
        learningStats.averageConfidence = learningStats.totalConfidence / Double(learningStats.totalTranscriptions)
        
        if result.confidence > adaptationThreshold {
            learningStats.successfulAdaptations += 1
        }
        
        learningStats.lastLearningSession = Date()
        
        DispatchQueue.main.async {
            self.adaptationAccuracy = Float(self.learningStats.averageConfidence)
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveAllPatterns() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.saveSpeechPatterns() }
            group.addTask { await self.savePronunciationVariations() }
            group.addTask { await self.saveSpeakingRhythm() }
            group.addTask { await self.saveVocabularyPreferences() }
            group.addTask { await self.saveContextualPatterns() }
            group.addTask { await self.saveUserProfile() }
            group.addTask { await self.saveLearningStats() }
        }
    }
    
    private func saveSpeechPatterns() async {
        do {
            let data = try JSONEncoder().encode(speechPatterns)
            let encryptedData = try await encrypt(data)
            userDefaults.set(encryptedData, forKey: "speech_patterns")
        } catch {
            print("❌ Failed to save speech patterns: \(error.localizedDescription)")
        }
    }
    
    private func savePronunciationVariations() async {
        do {
            let encoded = pronunciationVariations.mapValues { Array($0) }
            let data = try JSONEncoder().encode(encoded)
            let encryptedData = try await encrypt(data)
            userDefaults.set(encryptedData, forKey: "pronunciation_variations")
        } catch {
            print("❌ Failed to save pronunciation variations: \(error.localizedDescription)")
        }
    }
    
    private func saveSpeakingRhythm() async {
        do {
            let data = try JSONEncoder().encode(speakingRhythm)
            let encryptedData = try await encrypt(data)
            userDefaults.set(encryptedData, forKey: "speaking_rhythm")
        } catch {
            print("❌ Failed to save speaking rhythm: \(error.localizedDescription)")
        }
    }
    
    private func saveVocabularyPreferences() async {
        do {
            let data = try JSONEncoder().encode(vocabularyPreferences)
            let encryptedData = try await encrypt(data)
            userDefaults.set(encryptedData, forKey: "vocabulary_preferences")
        } catch {
            print("❌ Failed to save vocabulary preferences: \(error.localizedDescription)")
        }
    }
    
    private func saveContextualPatterns() async {
        do {
            let data = try JSONEncoder().encode(contextualPatterns)
            let encryptedData = try await encrypt(data)
            userDefaults.set(encryptedData, forKey: "contextual_patterns")
        } catch {
            print("❌ Failed to save contextual patterns: \(error.localizedDescription)")
        }
    }
    
    private func saveUserProfile() async {
        guard let profile = userProfile else { return }
        
        do {
            let data = try JSONEncoder().encode(profile)
            let encryptedData = try await encrypt(data)
            userDefaults.set(encryptedData, forKey: "user_speech_profile")
        } catch {
            print("❌ Failed to save user speech profile: \(error.localizedDescription)")
        }
    }
    
    private func saveLearningStats() async {
        do {
            let data = try JSONEncoder().encode(learningStats)
            let encryptedData = try await encrypt(data)
            userDefaults.set(encryptedData, forKey: "learning_statistics")
        } catch {
            print("❌ Failed to save learning statistics: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Privacy and Data Management
    
    private func encrypt(_ data: Data) async throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        return sealedBox.combined!
    }
    
    private func decrypt(_ data: Data) async throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }
    
    private func cleanupOldPatterns() async {
        let cutoffDate = Date().addingTimeInterval(-maxPatternAge)
        
        // Remove old contextual patterns
        contextualPatterns = contextualPatterns.filter { $0.value.lastUpdated > cutoffDate }
        
        // Remove old common phrases
        speechPatterns.commonPhrases = speechPatterns.commonPhrases.filter { $0.lastUsed > cutoffDate }
        
        // Clean up low-frequency vocabulary preferences
        vocabularyPreferences = vocabularyPreferences.filter { $0.value > 0.1 }
        
        print("🧹 Cleaned up old patterns")
    }
    
    // MARK: - Helper Methods
    
    private func calculateStringSimilarity(_ str1: String, _ str2: String) -> Double {
        let longer = str1.count > str2.count ? str1 : str2
        let shorter = str1.count > str2.count ? str2 : str1
        
        if longer.isEmpty { return 1.0 }
        
        let longerLength = Double(longer.count)
        let editDistance = levenshteinDistance(shorter, longer)
        
        return (longerLength - Double(editDistance)) / longerLength
    }
    
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        
        let str1Count = str1Array.count
        let str2Count = str2Array.count
        
        if str1Count == 0 { return str2Count }
        if str2Count == 0 { return str1Count }
        
        var matrix = Array(repeating: Array(repeating: 0, count: str2Count + 1), count: str1Count + 1)
        
        for i in 0...str1Count { matrix[i][0] = i }
        for j in 0...str2Count { matrix[0][j] = j }
        
        for i in 1...str1Count {
            for j in 1...str2Count {
                let cost = str1Array[i - 1] == str2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        
        return matrix[str1Count][str2Count]
    }
    
    private func updateAverage(current: Double, new: Double, weight: Double) -> Double {
        return current * (1.0 - weight) + new * weight
    }
    
    private func updateAverage(current: Double, new: Double, weight: Float) -> Float {
        return Float(current * (1.0 - Double(weight)) + new * Double(weight))
    }
    
    private func getTimeContext(hour: Int) -> String {
        switch hour {
        case 6..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "night"
        }
    }
    
    private func extractPhrases(from text: String) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var phrases: [String] = []
        
        // Extract 2-4 word phrases
        for length in 2...min(4, words.count) {
            for start in 0...(words.count - length) {
                let phrase = words[start..<start+length].joined(separator: " ")
                if phrase.count > 5 { // Minimum phrase length
                    phrases.append(phrase)
                }
            }
        }
        
        return phrases
    }
    
    private func updateCounts() {
        patternCount = speechPatterns.commonPhrases.count +
                      pronunciationVariations.count +
                      contextualPatterns.count +
                      speechPatterns.wordOrderPatterns.count
    }
    
    // MARK: - Public Interface
    
    func resetLearning() async {
        speechPatterns = SpeechPatterns()
        pronunciationVariations = [:]
        speakingRhythm = SpeakingRhythm()
        vocabularyPreferences = [:]
        contextualPatterns = [:]
        learningStats = LearningStatistics()
        
        await saveAllPatterns()
        
        DispatchQueue.main.async {
            self.updateCounts()
            self.adaptationAccuracy = 0.0
        }
    }
    
    func exportLearningData() -> LearningDataExport {
        return LearningDataExport(
            patternCount: patternCount,
            adaptationAccuracy: adaptationAccuracy,
            totalTranscriptions: learningStats.totalTranscriptions,
            successfulAdaptations: learningStats.successfulAdaptations,
            averageConfidence: Float(learningStats.averageConfidence),
            lastUpdated: learningStats.lastLearningSession
        )
    }
}

// MARK: - Supporting Data Structures


struct LearningStatistics: Codable {
    var totalTranscriptions: Int = 0
    var successfulAdaptations: Int = 0
    var totalConfidence: Double = 0.0
    var averageConfidence: Double = 0.0
    var lastLearningSession: Date = Date.distantPast
    
    init() {}
}

struct LearningDataExport {
    let patternCount: Int
    let adaptationAccuracy: Float
    let totalTranscriptions: Int
    let successfulAdaptations: Int
    let averageConfidence: Float
    let lastUpdated: Date
}

// MARK: - Extensions