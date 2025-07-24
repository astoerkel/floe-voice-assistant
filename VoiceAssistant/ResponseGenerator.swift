import Foundation
import CoreML
import NaturalLanguage

/// High-level response generator that orchestrates natural language response generation,
/// personalization, conversation continuity, and response variations
@MainActor
class ResponseGenerator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isGenerating = false
    @Published var generationStatistics = ResponseGenerationStats()
    @Published var lastPersonalizationUpdate: Date?
    
    // MARK: - Core Components
    private let coreMLManager: CoreMLManager?
    private let personalizationEngine: PersonalizationEngine
    private let responseCache: ResponseCache
    private let responseTemplates: ResponseTemplateManager
    private let variationEngine: ResponseVariationEngine
    private let ttsService: TTSServiceProtocol
    
    // MARK: - Configuration
    private let maxCacheSize = 1000
    private let maxGenerationTime: TimeInterval = 2.0
    private let useOnDeviceFirst = true
    private let generateAudioResponses = true
    
    // MARK: - Initialization
    @MainActor init(coreMLManager: CoreMLManager? = nil, ttsService: TTSServiceProtocol? = nil) {
        self.coreMLManager = coreMLManager
        self.personalizationEngine = PersonalizationEngine()
        self.responseCache = ResponseCache(maxSize: maxCacheSize)
        self.responseTemplates = ResponseTemplateManager()
        self.variationEngine = ResponseVariationEngine()
        
        // Initialize TTS service with platform-specific implementation
        if let ttsService = ttsService {
            self.ttsService = ttsService
        } else {
            #if os(watchOS)
            self.ttsService = WatchTTSService()
            #else
            self.ttsService = iPhoneTTSService()
            #endif
        }
        
        // Register for personalization updates
        NotificationCenter.default.addObserver(
            forName: .personalizationUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lastPersonalizationUpdate = Date()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Main Response Generation
    
    /// Generates a natural language response using Core ML models and personalization
    /// - Parameters:
    ///   - query: The user's query or command
    ///   - context: Current conversation context
    ///   - responseType: Type of response needed
    ///   - userPreferences: User's current preferences
    /// - Returns: Generated response with metadata
    func generateResponse(
        for query: String,
        context: ConversationContext,
        responseType: ResponseType,
        userPreferences: UserPreferences? = nil
    ) async -> ResponseGenerationResult {
        
        let startTime = Date()
        isGenerating = true
        generationStatistics.totalRequests += 1
        
        defer {
            isGenerating = false
            let duration = Date().timeIntervalSince(startTime)
            generationStatistics.averageGenerationTime = 
                (generationStatistics.averageGenerationTime * Double(generationStatistics.totalRequests - 1) + duration) / 
                Double(generationStatistics.totalRequests)
        }
        
        // Step 1: Check cache for similar responses
        let cacheKey = generateCacheKey(query: query, type: responseType, context: context)
        if let cachedResponse = await responseCache.getResponse(for: cacheKey) {
            generationStatistics.cacheHits += 1
            
            // Apply variations to avoid repetition
            let variedResponse = await variationEngine.applyVariation(
                to: cachedResponse,
                context: context,
                preferences: userPreferences ?? personalizationEngine.currentPreferences
            )
            
            return ResponseGenerationResult(
                response: variedResponse,
                confidence: 0.9,
                source: .cache,
                processingTime: Date().timeIntervalSince(startTime),
                personalized: true
            )
        }
        
        // Step 2: Try Core ML generation first if enabled
        var textResult: ResponseGenerationResult
        
        if useOnDeviceFirst {
            if let mlResult = await generateWithCoreML(
                query: query,
                context: context,
                responseType: responseType,
                preferences: userPreferences
            ) {
                generationStatistics.coreMLGenerations += 1
                textResult = mlResult
            } else {
                // Fallback to template-based generation
                textResult = await generateWithTemplates(
                    query: query,
                    context: context,
                    responseType: responseType,
                    preferences: userPreferences
                )
                generationStatistics.templateGenerations += 1
            }
        } else {
            // Use template-based generation
            textResult = await generateWithTemplates(
                query: query,
                context: context,
                responseType: responseType,
                preferences: userPreferences
            )
            generationStatistics.templateGenerations += 1
        }
        
        // Step 3: Generate audio for the response if enabled
        var audioBase64: String?
        var ttsProcessingTime: TimeInterval?
        
        if generateAudioResponses {
            let ttsStartTime = Date()
            audioBase64 = await generateAudioResponse(for: textResult.response, preferences: userPreferences)
            ttsProcessingTime = Date().timeIntervalSince(ttsStartTime)
            
            if audioBase64 != nil {
                generationStatistics.audioGenerations += 1
            } else {
                generationStatistics.audioFailures += 1
            }
        }
        
        // Create final result with audio
        let finalResult = ResponseGenerationResult(
            response: textResult.response,
            audioBase64: audioBase64,
            confidence: textResult.confidence,
            source: textResult.source,
            processingTime: textResult.processingTime,
            personalized: textResult.personalized,
            ttsProcessingTime: ttsProcessingTime,
            metadata: textResult.metadata
        )
        
        // Cache the response for future use
        await responseCache.cacheResponse(finalResult.response, for: cacheKey)
        
        return finalResult
    }
    
    // MARK: - Core ML Generation
    
    private func generateWithCoreML(
        query: String,
        context: ConversationContext,
        responseType: ResponseType,
        preferences: UserPreferences?
    ) async -> ResponseGenerationResult? {
        
        guard let coreMLManager = coreMLManager else {
            return nil
        }
        
        guard let model = try? await coreMLManager.getModel("response_generation", type: ResponseGenerationModel.self) else {
            return nil
        }
        
        let input = ResponseGenerationInput(
            query: query,
            context: context,
            responseType: responseType,
            userPreferences: preferences ?? personalizationEngine.currentPreferences,
            conversationHistory: context.recentMessages.map { $0.text },
            timeContext: TimeContext.current()
        )
        
        do {
            let startTime = Date()
            
            // Use the custom model's prediction interface 
            let responseOutput = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ResponseGenerationOutput, Error>) in
                model.predict(input: input) { (result: Result<ResponseGenerationOutput, MLModelError>) in
                    switch result {
                    case .success(let output):
                        continuation.resume(returning: output)
                    case .failure(let error):
                        continuation.resume(throwing: CoreMLResponseError.predictionFailed(error.localizedDescription))
                    }
                }
            }
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            // Apply personalization
            let personalizedResponse = await personalizationEngine.personalizeResponse(
                responseOutput.generatedText,
                for: preferences ?? personalizationEngine.currentPreferences
            )
            
            // Apply variations for personality
            let variedResponse = await variationEngine.applyVariation(
                to: personalizedResponse,
                context: context,
                preferences: preferences ?? personalizationEngine.currentPreferences
            )
            
            return ResponseGenerationResult(
                response: variedResponse,
                confidence: Double(responseOutput.confidence),
                source: .coreML,
                processingTime: processingTime,
                personalized: true,
                metadata: responseOutput.metadata
            )
            
        } catch {
            print("Core ML generation failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Template-Based Generation
    
    private func generateWithTemplates(
        query: String,
        context: ConversationContext,
        responseType: ResponseType,
        preferences: UserPreferences?
    ) async -> ResponseGenerationResult {
        
        let startTime = Date()
        
        // Get appropriate template
        let template = responseTemplates.getTemplate(
            for: responseType,
            query: query,
            context: context
        )
        
        // Fill template with context-specific information
        let baseResponse = responseTemplates.fillTemplate(
            template,
            with: extractTemplateVariables(from: query, context: context)
        )
        
        // Apply personalization
        let personalizedResponse = await personalizationEngine.personalizeResponse(
            baseResponse,
            for: preferences ?? personalizationEngine.currentPreferences
        )
        
        // Apply variations
        let variedResponse = await variationEngine.applyVariation(
            to: personalizedResponse,
            context: context,
            preferences: preferences ?? personalizationEngine.currentPreferences
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return ResponseGenerationResult(
            response: variedResponse,
            confidence: 0.75, // Lower confidence for template-based
            source: .template,
            processingTime: processingTime,
            personalized: true
        )
    }
    
    // MARK: - Conversation Continuity
    
    /// Updates conversation context after a response is generated
    func updateConversationContext(
        _ context: inout ConversationContext,
        with result: ResponseGenerationResult,
        userQuery: String
    ) {
        // Add to conversation history
        context.recentMessages.append(
            ConversationMessage(text: userQuery, isUser: true, timestamp: Date())
        )
        context.recentMessages.append(
            ConversationMessage(text: result.response, isUser: false, timestamp: Date())
        )
        
        // Keep only recent messages for context
        if context.recentMessages.count > 10 {
            context.recentMessages = Array(context.recentMessages.suffix(10))
        }
        
        // Update context with response metadata
        context.lastResponseType = result.metadata?["responseType"] as? String
        context.lastResponseConfidence = result.confidence
        context.conversationTurn += 1
    }
    
    // MARK: - TTS Generation
    
    /// Generates audio response using TTS service
    private func generateAudioResponse(
        for text: String,
        preferences: UserPreferences? = nil
    ) async -> String? {
        
        // Check if we should skip TTS based on text content
        guard shouldGenerateAudio(for: text) else {
            return nil
        }
        
        // Apply personalization to voice settings
        var voiceSettings = TTSVoiceSettings.default
        if let prefs = preferences {
            voiceSettings = adaptVoiceSettings(voiceSettings, for: prefs)
        }
        
        // Generate audio using TTS service
        return await withCheckedContinuation { continuation in
            ttsService.synthesizeText(text, settings: voiceSettings) { result in
                switch result {
                case .success(let audioData):
                    let base64String = audioData.base64EncodedString()
                    continuation.resume(returning: base64String)
                case .failure(let error):
                    print("TTS generation failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Determines if audio should be generated for the given text
    private func shouldGenerateAudio(for text: String) -> Bool {
        // Skip very short or empty responses
        guard text.count >= 3 else { return false }
        
        // Skip responses that are primarily technical/system messages
        let systemKeywords = ["error", "failed", "invalid", "timeout", "connection"]
        let lowerText = text.lowercased()
        
        if systemKeywords.contains(where: { lowerText.contains($0) }) {
            return false
        }
        
        return true
    }
    
    /// Adapts TTS voice settings based on user preferences
    private func adaptVoiceSettings(
        _ settings: TTSVoiceSettings,
        for preferences: UserPreferences
    ) -> TTSVoiceSettings {
        
        var adaptedSettings = settings
        
        // Adjust speaking rate based on response length preference
        switch preferences.responseLength {
        case .short, .brief:
            adaptedSettings.speakingRate = min(1.2, settings.speakingRate * 1.1)
        case .long, .detailed:
            adaptedSettings.speakingRate = max(0.8, settings.speakingRate * 0.95)
        case .medium:
            // Keep default rate
            break
        }
        
        // Adjust pitch based on personality traits
        let enthusiasm = preferences.personalityTraits.enthusiasm
        if enthusiasm > 0.7 {
            adaptedSettings.pitch = min(2.0, settings.pitch + 0.2)
        } else if enthusiasm < 0.3 {
            adaptedSettings.pitch = max(-2.0, settings.pitch - 0.1)
        }
        
        // Adjust voice based on formality level
        if preferences.formalityLevel > 0.7 {
            adaptedSettings.voiceName = "en-GB-Chirp3-HD-Sulafat" // More formal voice
        } else if preferences.formalityLevel < 0.3 {
            adaptedSettings.voiceName = "en-US-Neural2-C" // More casual voice
        }
        
        return adaptedSettings
    }
    
    // MARK: - Helper Methods
    
    private func generateCacheKey(
        query: String,
        type: ResponseType,
        context: ConversationContext
    ) -> String {
        let queryHash = query.lowercased().hash
        let typeHash = type.rawValue.hash
        let contextHash = context.contextSummary.hash
        
        return "response_\(queryHash)_\(typeHash)_\(contextHash)"
    }
    
    private func extractTemplateVariables(
        from query: String,
        context: ConversationContext
    ) -> [String: String] {
        var variables: [String: String] = [:]
        
        // Basic time/date variables
        let now = Date()
        let formatter = DateFormatter()
        
        formatter.timeStyle = .short
        variables["time"] = formatter.string(from: now)
        
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        variables["date"] = formatter.string(from: now)
        
        formatter.dateFormat = "EEEE"
        variables["weekday"] = formatter.string(from: now)
        
        // Extract entities from query using NL framework
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = query
        
        tagger.enumerateTags(in: query.startIndex..<query.endIndex, 
                           unit: .word, 
                           scheme: .nameType) { tag, tokenRange in
            if let tag = tag {
                let token = String(query[tokenRange])
                variables["entity_\(tag.rawValue.lowercased())"] = token
            }
            return true
        }
        
        // Context-specific variables
        variables["conversation_turn"] = "\(context.conversationTurn)"
        if let lastType = context.lastResponseType {
            variables["last_response_type"] = lastType
        }
        
        return variables
    }
}

// MARK: - Supporting Types

struct ResponseGenerationResult {
    let response: String
    let audioBase64: String?
    let confidence: Double
    let source: ResponseSource
    let processingTime: TimeInterval
    let personalized: Bool
    let ttsProcessingTime: TimeInterval?
    let metadata: [String: Any]?
    
    init(
        response: String,
        audioBase64: String? = nil,
        confidence: Double,
        source: ResponseSource,
        processingTime: TimeInterval,
        personalized: Bool,
        ttsProcessingTime: TimeInterval? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.response = response
        self.audioBase64 = audioBase64
        self.confidence = confidence
        self.source = source
        self.processingTime = processingTime
        self.personalized = personalized
        self.ttsProcessingTime = ttsProcessingTime
        self.metadata = metadata
    }
}

enum ResponseSource {
    case coreML
    case template
    case cache
}

// Using ResponseType from SharedTypes.swift
// Extended enum for ResponseGenerator-specific types
enum ExtendedResponseType: String, CaseIterable {
    case calendar = "calendar"
    case email = "email"
    case task = "task"
    case weather = "weather"
    case timeDate = "time_date"
    case confirmation = "confirmation"
    case clarification = "clarification"
    case error = "error"
    case greeting = "greeting"
    case general = "general"
}

// Using ConversationContext from SharedTypes.swift

// Using TimeContext from SharedTypes.swift


struct ResponseGenerationStats {
    var totalRequests: Int = 0
    var cacheHits: Int = 0
    var coreMLGenerations: Int = 0
    var templateGenerations: Int = 0
    var audioGenerations: Int = 0
    var audioFailures: Int = 0
    var averageGenerationTime: TimeInterval = 0.0
    var averageTTSTime: TimeInterval = 0.0
    
    var cacheHitRate: Double {
        totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0.0
    }
    
    var coreMLUsageRate: Double {
        totalRequests > 0 ? Double(coreMLGenerations) / Double(totalRequests) : 0.0
    }
    
    var audioSuccessRate: Double {
        let totalAudioAttempts = audioGenerations + audioFailures
        return totalAudioAttempts > 0 ? Double(audioGenerations) / Double(totalAudioAttempts) : 0.0
    }
    
    var audioGenerationRate: Double {
        totalRequests > 0 ? Double(audioGenerations) / Double(totalRequests) : 0.0
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let personalizationUpdated = Notification.Name("personalizationUpdated")
}

// MARK: - CoreML Error Handling

enum CoreMLResponseError: LocalizedError {
    case modelNotLoaded(String)
    case invalidOutput(String)
    case predictionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded(let message):
            return "Core ML model not loaded: \(message)"
        case .invalidOutput(let message):
            return "Invalid Core ML output: \(message)"
        case .predictionFailed(let message):
            return "Core ML prediction failed: \(message)"
        }
    }
}