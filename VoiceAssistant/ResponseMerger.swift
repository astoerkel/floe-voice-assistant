import Foundation
import AVFoundation

/// Intelligent response merger for hybrid processing results
public class ResponseMerger: ObservableObject {
    
    // MARK: - Merge Strategy
    public enum MergeStrategy {
        case useOnDevice       // Use on-device result only
        case useServer         // Use server result only
        case combineResponses  // Merge both responses intelligently
        case useHighestConfidence // Use result with highest confidence
        case contextAware      // Merge based on context and content type
    }
    
    // MARK: - Merge Result
    public struct MergedResult {
        public let response: String
        public let audioBase64: String?
        public let confidence: Double
        public let cost: Double
        public let privacyScore: Double
        public let mergeStrategy: MergeStrategy
        public let primarySource: ProcessingLocation
        public let mergingTime: TimeInterval
        public let metadata: [String: Any]
    }
    
    // MARK: - Configuration
    private var configuration: ResponseMergerConfiguration
    
    public init(configuration: ResponseMergerConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Main Merging Interface
    
    /// Intelligently merge on-device and server processing results
    public func mergeResults(
        onDeviceResult: HybridProcessingResult,
        serverResult: HybridProcessingResult,
        decision: ProcessingDecision
    ) async -> MergedResult {
        
        let startTime = Date()
        
        // Step 1: Determine optimal merge strategy
        let strategy = determineMergeStrategy(
            onDeviceResult: onDeviceResult,
            serverResult: serverResult,
            decision: decision
        )
        
        // Step 2: Execute merging based on strategy
        let mergedResult = await executeStrategy(
            strategy: strategy,
            onDeviceResult: onDeviceResult,
            serverResult: serverResult,
            decision: decision
        )
        
        let mergingTime = Date().timeIntervalSince(startTime)
        
        return MergedResult(
            response: mergedResult.response,
            audioBase64: mergedResult.audioBase64,
            confidence: mergedResult.confidence,
            cost: mergedResult.cost,
            privacyScore: mergedResult.privacyScore,
            mergeStrategy: strategy,
            primarySource: mergedResult.primarySource,
            mergingTime: mergingTime,
            metadata: mergedResult.metadata
        )
    }
    
    // MARK: - Strategy Determination
    
    private func determineMergeStrategy(
        onDeviceResult: HybridProcessingResult,
        serverResult: HybridProcessingResult,
        decision: ProcessingDecision
    ) -> MergeStrategy {
        
        // If one result failed, use the other
        if onDeviceResult.confidence < 0.1 {
            return .useServer
        }
        if serverResult.confidence < 0.1 {
            return .useOnDevice
        }
        
        // Privacy-first: prefer on-device for sensitive content
        if decision.privacyRequired && onDeviceResult.confidence > 0.3 {
            return .useOnDevice
        }
        
        // Large confidence difference: use higher confidence result
        let confidenceDifference = abs(onDeviceResult.confidence - serverResult.confidence)
        if confidenceDifference > 0.3 {
            return .useHighestConfidence
        }
        
        // Check for complementary responses
        if areResponsesComplementary(onDeviceResult.response, serverResult.response) {
            return .combineResponses
        }
        
        // Similar confidence and content: use context-aware merging
        if confidenceDifference < 0.15 {
            return .contextAware
        }
        
        // Default to highest confidence
        return .useHighestConfidence
    }
    
    private func areResponsesComplementary(_ response1: String, _ response2: String) -> Bool {
        // Check if responses provide different but related information
        let words1 = Set(response1.lowercased().split(separator: " ").map(String.init))
        let words2 = Set(response2.lowercased().split(separator: " ").map(String.init))
        
        let overlap = words1.intersection(words2)
        let union = words1.union(words2)
        
        // Responses are complementary if they have some overlap but significant unique content
        let overlapRatio = Double(overlap.count) / Double(union.count)
        return overlapRatio > 0.2 && overlapRatio < 0.8
    }
    
    // MARK: - Strategy Execution
    
    private func executeStrategy(
        strategy: MergeStrategy,
        onDeviceResult: HybridProcessingResult,
        serverResult: HybridProcessingResult,
        decision: ProcessingDecision
    ) async -> (response: String, audioBase64: String?, confidence: Double, cost: Double, privacyScore: Double, primarySource: ProcessingLocation, metadata: [String: Any]) {
        
        switch strategy {
        case .useOnDevice:
            return await useOnDeviceResult(onDeviceResult, fallback: serverResult)
            
        case .useServer:
            return await useServerResult(serverResult, fallback: onDeviceResult)
            
        case .useHighestConfidence:
            return await useHighestConfidenceResult(onDeviceResult, serverResult)
            
        case .combineResponses:
            return await combineResponses(onDeviceResult, serverResult, decision)
            
        case .contextAware:
            return await contextAwareMerge(onDeviceResult, serverResult, decision)
        }
    }
    
    // MARK: - Strategy Implementations
    
    private func useOnDeviceResult(
        _ onDeviceResult: HybridProcessingResult,
        fallback serverResult: HybridProcessingResult
    ) async -> (response: String, audioBase64: String?, confidence: Double, cost: Double, privacyScore: Double, primarySource: ProcessingLocation, metadata: [String: Any]) {
        
        // Use on-device result, but enhance with server audio if needed
        let audioBase64 = onDeviceResult.audioBase64 ?? serverResult.audioBase64
        
        return (
            response: onDeviceResult.response,
            audioBase64: audioBase64,
            confidence: onDeviceResult.confidence,
            cost: onDeviceResult.cost,
            privacyScore: onDeviceResult.privacyScore,
            primarySource: .onDevice,
            metadata: [
                "strategy": "use_on_device",
                "audio_source": onDeviceResult.audioBase64 != nil ? "on_device" : "server",
                "fallback_available": true
            ]
        )
    }
    
    private func useServerResult(
        _ serverResult: HybridProcessingResult,
        fallback onDeviceResult: HybridProcessingResult
    ) async -> (response: String, audioBase64: String?, confidence: Double, cost: Double, privacyScore: Double, primarySource: ProcessingLocation, metadata: [String: Any]) {
        
        return (
            response: serverResult.response,
            audioBase64: serverResult.audioBase64,
            confidence: serverResult.confidence,
            cost: serverResult.cost,
            privacyScore: serverResult.privacyScore,
            primarySource: .server,
            metadata: [
                "strategy": "use_server",
                "fallback_available": onDeviceResult.confidence > 0.1
            ]
        )
    }
    
    private func useHighestConfidenceResult(
        _ onDeviceResult: HybridProcessingResult,
        _ serverResult: HybridProcessingResult
    ) async -> (response: String, audioBase64: String?, confidence: Double, cost: Double, privacyScore: Double, primarySource: ProcessingLocation, metadata: [String: Any]) {
        
        let useOnDevice = onDeviceResult.confidence >= serverResult.confidence
        let primaryResult = useOnDevice ? onDeviceResult : serverResult
        let secondaryResult = useOnDevice ? serverResult : onDeviceResult
        
        // Combine costs and privacy scores weighted by confidence
        let totalConfidence = onDeviceResult.confidence + serverResult.confidence
        let weightedCost = (onDeviceResult.cost * onDeviceResult.confidence + 
                           serverResult.cost * serverResult.confidence) / totalConfidence
        let weightedPrivacyScore = (onDeviceResult.privacyScore * onDeviceResult.confidence + 
                                   serverResult.privacyScore * serverResult.confidence) / totalConfidence
        
        return (
            response: primaryResult.response,
            audioBase64: primaryResult.audioBase64 ?? secondaryResult.audioBase64,
            confidence: primaryResult.confidence,
            cost: weightedCost,
            privacyScore: weightedPrivacyScore,
            primarySource: primaryResult.processingLocation,
            metadata: [
                "strategy": "highest_confidence",
                "on_device_confidence": onDeviceResult.confidence,
                "server_confidence": serverResult.confidence,
                "confidence_difference": abs(onDeviceResult.confidence - serverResult.confidence)
            ]
        )
    }
    
    private func combineResponses(
        _ onDeviceResult: HybridProcessingResult,
        _ serverResult: HybridProcessingResult,
        _ decision: ProcessingDecision
    ) async -> (response: String, audioBase64: String?, confidence: Double, cost: Double, privacyScore: Double, primarySource: ProcessingLocation, metadata: [String: Any]) {
        
        // Intelligently combine both responses
        let combinedResponse = await intelligentlyCombineText(
            onDeviceResponse: onDeviceResult.response,
            serverResponse: serverResult.response,
            decision: decision
        )
        
        // Use the better audio response
        let audioBase64 = chooseBetterAudio(onDeviceResult.audioBase64, serverResult.audioBase64)
        
        // Calculate combined metrics
        let combinedConfidence = (onDeviceResult.confidence + serverResult.confidence) / 2.0 + 0.1 // Bonus for combination
        let combinedCost = onDeviceResult.cost + serverResult.cost
        let combinedPrivacyScore = min(onDeviceResult.privacyScore, serverResult.privacyScore) // Use more restrictive privacy score
        
        return (
            response: combinedResponse,
            audioBase64: audioBase64,
            confidence: min(combinedConfidence, 1.0),
            cost: combinedCost,
            privacyScore: combinedPrivacyScore,
            primarySource: .hybrid,
            metadata: [
                "strategy": "combine_responses",
                "combination_method": "intelligent_merge",
                "on_device_length": onDeviceResult.response.count,
                "server_length": serverResult.response.count,
                "combined_length": combinedResponse.count
            ]
        )
    }
    
    private func contextAwareMerge(
        _ onDeviceResult: HybridProcessingResult,
        _ serverResult: HybridProcessingResult,
        _ decision: ProcessingDecision
    ) async -> (response: String, audioBase64: String?, confidence: Double, cost: Double, privacyScore: Double, primarySource: ProcessingLocation, metadata: [String: Any]) {
        
        // Analyze context to determine best merge approach
        let responseType = analyzeResponseType(onDeviceResult.response, serverResult.response)
        
        switch responseType {
        case .factual:
            // For factual responses, prefer server for accuracy but validate with on-device
            return await validateServerWithOnDevice(serverResult, onDeviceResult)
            
        case .creative:
            // For creative responses, prefer server but enhance with on-device personalization
            return await enhanceServerWithOnDevice(serverResult, onDeviceResult)
            
        case .personal:
            // For personal queries, prefer on-device for privacy
            return await useOnDeviceResult(onDeviceResult, fallback: serverResult)
            
        case .computational:
            // For calculations, validate both results
            return await validateComputationalResults(onDeviceResult, serverResult)
            
        case .conversational:
            // For conversation, blend responses naturally
            return await blendConversationalResponses(onDeviceResult, serverResult)
        }
    }
    
    // MARK: - Response Type Analysis
    
    private enum ResponseType {
        case factual        // Facts, definitions, information
        case creative       // Stories, explanations, creative content
        case personal       // Personal information, preferences
        case computational  // Math, calculations, data processing
        case conversational // Chat, questions, casual conversation
    }
    
    private func analyzeResponseType(_ response1: String, _ response2: String) -> ResponseType {
        let combinedText = (response1 + " " + response2).lowercased()
        
        // Check for computational indicators
        if combinedText.contains("calculate") || combinedText.contains("result") || 
           combinedText.rangeOfCharacter(from: .decimalDigits) != nil {
            return .computational
        }
        
        // Check for personal indicators
        if combinedText.contains("your") || combinedText.contains("you") || 
           combinedText.contains("personal") {
            return .personal
        }
        
        // Check for creative indicators
        if combinedText.contains("story") || combinedText.contains("imagine") || 
           combinedText.contains("creative") {
            return .creative
        }
        
        // Check for factual indicators
        if combinedText.contains("definition") || combinedText.contains("fact") || 
           combinedText.contains("information") {
            return .factual
        }
        
        // Default to conversational
        return .conversational
    }
    
    // MARK: - Context-Aware Merge Implementations
    
    private func validateServerWithOnDevice(
        _ serverResult: HybridProcessingResult,
        _ onDeviceResult: HybridProcessingResult
    ) async -> (response: String, audioBase64: String?, confidence: Double, cost: Double, privacyScore: Double, primarySource: ProcessingLocation, metadata: [String: Any]) {
        
        // Use server response but boost confidence if on-device agrees
        let agreement = calculateResponseAgreement(serverResult.response, onDeviceResult.response)
        let adjustedConfidence = serverResult.confidence + (agreement * 0.2)
        
        return (
            response: serverResult.response,
            audioBase64: serverResult.audioBase64,
            confidence: min(adjustedConfidence, 1.0),
            cost: serverResult.cost,
            privacyScore: serverResult.privacyScore,
            primarySource: .server,
            metadata: [
                "strategy": "validate_server_with_on_device",
                "agreement_score": agreement,
                "confidence_boost": agreement * 0.2
            ]
        )
    }
    
    private func enhanceServerWithOnDevice(
        _ serverResult: HybridProcessingResult,
        _ onDeviceResult: HybridProcessingResult
    ) async -> (response: String, audioBase64: String?, confidence: Double, cost: Double, privacyScore: Double, primarySource: ProcessingLocation, metadata: [String: Any]) {
        
        // Use server as base, add on-device personalization touches
        let enhancedResponse = await addPersonalizationTouches(
            baseResponse: serverResult.response,
            personalizedElements: extractPersonalizedElements(from: onDeviceResult.response)
        )
        
        return (
            response: enhancedResponse,
            audioBase64: serverResult.audioBase64,
            confidence: (serverResult.confidence + onDeviceResult.confidence * 0.3) / 1.3,
            cost: serverResult.cost,
            privacyScore: (serverResult.privacyScore + onDeviceResult.privacyScore) / 2.0,
            primarySource: .server,
            metadata: [
                "strategy": "enhance_server_with_on_device",
                "personalization_applied": true
            ]
        )
    }
    
    private func validateComputationalResults(
        _ onDeviceResult: HybridProcessingResult,
        _ serverResult: HybridProcessingResult
    ) async -> (response: String, audioBase64: String?, confidence: Double, cost: Double, privacyScore: Double, primarySource: ProcessingLocation, metadata: [String: Any]) {
        
        // For computational results, check if they agree
        let resultsMatch = computationalResultsMatch(onDeviceResult.response, serverResult.response)
        
        if resultsMatch {
            // Results agree, use higher confidence one with boosted confidence
            let primaryResult = onDeviceResult.confidence >= serverResult.confidence ? onDeviceResult : serverResult
            return (
                response: primaryResult.response,
                audioBase64: primaryResult.audioBase64,
                confidence: min(primaryResult.confidence + 0.3, 1.0), // Boost for agreement
                cost: primaryResult.cost,
                privacyScore: primaryResult.privacyScore,
                primarySource: primaryResult.processingLocation,
                metadata: [
                    "strategy": "validate_computational",
                    "results_match": true,
                    "confidence_boost": 0.3
                ]
            )
        } else {
            // Results disagree, indicate uncertainty and prefer server
            let uncertainResponse = "I got different results from my calculations. The most likely answer is: \(serverResult.response)"
            return (
                response: uncertainResponse,
                audioBase64: serverResult.audioBase64,
                confidence: 0.6, // Lower confidence due to disagreement
                cost: serverResult.cost + onDeviceResult.cost,
                privacyScore: min(serverResult.privacyScore, onDeviceResult.privacyScore),
                primarySource: .server,
                metadata: [
                    "strategy": "validate_computational",
                    "results_match": false,
                    "uncertainty_indicated": true
                ]
            )
        }
    }
    
    private func blendConversationalResponses(
        _ onDeviceResult: HybridProcessingResult,
        _ serverResult: HybridProcessingResult
    ) async -> (response: String, audioBase64: String?, confidence: Double, cost: Double, privacyScore: Double, primarySource: ProcessingLocation, metadata: [String: Any]) {
        
        // Blend conversational responses naturally
        let blendedResponse = await naturallyBlendResponses(
            response1: onDeviceResult.response,
            response2: serverResult.response,
            confidence1: onDeviceResult.confidence,
            confidence2: serverResult.confidence
        )
        
        return (
            response: blendedResponse,
            audioBase64: chooseBetterAudio(onDeviceResult.audioBase64, serverResult.audioBase64),
            confidence: (onDeviceResult.confidence + serverResult.confidence) / 2.0,
            cost: onDeviceResult.cost + serverResult.cost,
            privacyScore: (onDeviceResult.privacyScore + serverResult.privacyScore) / 2.0,
            primarySource: .hybrid,
            metadata: [
                "strategy": "blend_conversational",
                "blending_method": "natural_merge"
            ]
        )
    }
    
    // MARK: - Helper Methods
    
    private func intelligentlyCombineText(
        onDeviceResponse: String,
        serverResponse: String,
        decision: ProcessingDecision
    ) async -> String {
        
        // Simple intelligent combination - in practice, this could use NLP
        let onDeviceWords = onDeviceResponse.split(separator: " ")
        let serverWords = serverResponse.split(separator: " ")
        
        // If one response is much longer and more detailed, prefer it
        if serverWords.count > onDeviceWords.count * 2 {
            return serverResponse
        } else if onDeviceWords.count > serverWords.count * 2 {
            return onDeviceResponse
        }
        
        // Otherwise, create a combined response
        return "\(onDeviceResponse) Additionally, \(serverResponse.lowercased())"
    }
    
    private func chooseBetterAudio(_ audio1: String?, _ audio2: String?) -> String? {
        // Prefer any available audio, could add quality assessment later
        return audio1 ?? audio2
    }
    
    private func calculateResponseAgreement(_ response1: String, _ response2: String) -> Double {
        let words1 = Set(response1.lowercased().split(separator: " ").map(String.init))
        let words2 = Set(response2.lowercased().split(separator: " ").map(String.init))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func extractPersonalizedElements(from response: String) -> [String] {
        // Extract personalized elements (preferences, names, etc.)
        // This is a simplified implementation
        let personalKeywords = ["you", "your", "preference", "usually", "typically"]
        
        return response.split(separator: " ")
            .compactMap { word in
                let lowercaseWord = word.lowercased()
                return personalKeywords.contains { lowercaseWord.contains($0) } ? String(word) : nil
            }
    }
    
    private func addPersonalizationTouches(
        baseResponse: String,
        personalizedElements: [String]
    ) async -> String {
        
        if personalizedElements.isEmpty {
            return baseResponse
        }
        
        // Add personalized touches to the base response
        let personalizedAddition = personalizedElements.joined(separator: " ")
        return "\(baseResponse) Based on your preferences: \(personalizedAddition)"
    }
    
    private func computationalResultsMatch(_ response1: String, _ response2: String) -> Bool {
        // Extract numbers from both responses and compare
        let numbers1 = extractNumbers(from: response1)
        let numbers2 = extractNumbers(from: response2)
        
        // Simple comparison - could be more sophisticated
        return numbers1.elementsEqual(numbers2) { abs($0 - $1) < 0.01 }
    }
    
    private func extractNumbers(from text: String) -> [Double] {
        let regex = try! NSRegularExpression(pattern: #"\d+\.?\d*"#)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        return matches.compactMap { match in
            let range = Range(match.range, in: text)!
            return Double(String(text[range]))
        }
    }
    
    private func naturallyBlendResponses(
        response1: String,
        response2: String,
        confidence1: Double,
        confidence2: Double
    ) async -> String {
        
        // Weight responses by confidence and blend naturally
        if confidence1 > confidence2 * 1.3 {
            return response1
        } else if confidence2 > confidence1 * 1.3 {
            return response2
        } else {
            // Create a natural blend
            let connector = ["Also,", "Additionally,", "Furthermore,"].randomElement() ?? "Also,"
            return "\(response1) \(connector) \(response2.lowercased())"
        }
    }
    
    // MARK: - Configuration Management
    
    public func updateConfiguration(_ newConfiguration: ResponseMergerConfiguration) {
        self.configuration = newConfiguration
    }
}

// MARK: - Configuration

public struct ResponseMergerConfiguration {
    public let preferPrivacyPreservingMerge: Bool
    public let maxCombinedResponseLength: Int
    public let confidenceThreshold: Double
    public let enableIntelligentCombination: Bool
    
    public static let `default` = ResponseMergerConfiguration(
        preferPrivacyPreservingMerge: true,
        maxCombinedResponseLength: 1000,
        confidenceThreshold: 0.5,
        enableIntelligentCombination: true
    )
}