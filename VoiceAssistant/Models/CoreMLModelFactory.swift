//
//  CoreMLModelFactory.swift
//  VoiceAssistant
//
//  Created by Claude Code on 2025-07-25.
//  Factory for creating and managing Core ML models with proper fallbacks
//

import Foundation
import CoreML
import NaturalLanguage
import OSLog

// MARK: - Core ML Model Factory
@MainActor
class CoreMLModelFactory {
    
    static let shared = CoreMLModelFactory()
    private let logger = Logger(subsystem: "com.voiceassistant", category: "CoreMLModelFactory")
    
    private init() {}
    
    // MARK: - Model Creation Methods
    
    /// Creates an intent classification model with proper fallbacks
    func createIntentClassificationModel() async -> IntentClassificationModel {
        let model = IntentClassificationModel()
        
        do {
            try await model.loadModel()
            logger.info("✅ Intent classification model loaded successfully")
        } catch {
            logger.warning("⚠️ Intent classification model failed to load: \(error.localizedDescription)")
            logger.info("📱 Using development fallback mode")
        }
        
        return model
    }
    
    /// Creates a speech enhancement model with proper fallbacks
    func createSpeechEnhancementModel() async -> SpeechEnhancementModel {
        let model = SpeechEnhancementModel()
        
        do {
            try await model.loadModel()
            logger.info("✅ Speech enhancement model loaded successfully")
        } catch {
            logger.warning("⚠️ Speech enhancement model failed to load: \(error.localizedDescription)")
            logger.info("📱 Using development fallback mode")
        }
        
        return model
    }
    
    /// Creates a response generation model with proper fallbacks
    func createResponseGenerationModel() async -> ResponseGenerationModel {
        let model = ResponseGenerationModel()
        
        do {
            try await model.loadModel()
            logger.info("✅ Response generation model loaded successfully")
        } catch {
            logger.warning("⚠️ Response generation model failed to load: \(error.localizedDescription)")
            logger.info("📱 Using development fallback mode")
        }
        
        return model
    }
    
    // MARK: - Model Validation
    
    /// Validates all Core ML models and returns a status report
    func validateAllModels() async -> ModelValidationReport {
        var report = ModelValidationReport()
        
        // Test Intent Classification
        let intentModel = await createIntentClassificationModel()
        if intentModel.isLoaded {
            report.intentClassification = .loaded
            
            // Test with sample input
            let testInput = IntentClassificationInput(
                text: "what's the weather like today",
                context: nil,
                previousIntent: nil
            )
            
            do {
                let _: IntentClassificationOutput = try await intentModel.predict(input: testInput)
                report.intentClassification = .working
            } catch {
                report.intentClassification = .error(error.localizedDescription)
            }
        } else {
            report.intentClassification = .fallback
        }
        
        // Test Speech Enhancement
        let speechModel = await createSpeechEnhancementModel()
        if speechModel.isLoaded {
            report.speechEnhancement = .loaded
            
            // Test with sample audio data
            let testAudioData = Data(repeating: 0, count: 1024) // Mock audio data
            let testInput = SpeechEnhancementInput(
                audioData: testAudioData,
                sampleRate: 16000.0,
                channels: 1,
                duration: 0.064, // 64ms
                enhancementTypes: [.noiseReduction],
                qualityMetrics: nil
            )
            
            do {
                let _: SpeechEnhancementOutput = try await speechModel.predict(input: testInput)
                report.speechEnhancement = .working
            } catch {
                report.speechEnhancement = .error(error.localizedDescription)
            }
        } else {
            report.speechEnhancement = .fallback
        }
        
        // Test Response Generation
        let responseModel = await createResponseGenerationModel()
        if responseModel.isLoaded {
            report.responseGeneration = .loaded
            
            // Test with sample input using existing ResponseGenerationInput structure
            let testContext = ConversationContext(
                conversationTurn: 1,
                lastResponseType: nil,
                sessionDuration: 0,
                recentMessages: [],
                lastResponseConfidence: 0.0,
                userPreferences: nil,
                timeContext: TimeContext.current()
            )
            
            let testPreferences = UserPreferences(
                formalityLevel: 0.5,
                responseLength: .medium,
                personalityTraits: PersonalityTraits(
                    enthusiasm: 0.7,
                    helpfulness: 0.8,
                    friendliness: 0.6,
                    professionalism: 0.5
                )
            )
            
            let testInput = ResponseGenerationInput(
                query: "Hello",
                context: testContext,
                responseType: .general,
                userPreferences: testPreferences
            )
            
            do {
                let _: ResponseGenerationOutput = try await responseModel.predict(input: testInput)
                report.responseGeneration = .working
            } catch {
                report.responseGeneration = .error(error.localizedDescription)
            }
        } else {
            report.responseGeneration = .fallback
        }
        
        return report
    }
    
    // MARK: - Production Model Creation
    
    /// Creates Core ML models from training data (for production use)
    func createProductionModels() async throws {
        logger.info("🏭 Starting production model creation process")
        
        // This would be implemented when we have training data
        // For now, log that we're in development mode
        logger.info("📝 Production model creation requires:")
        logger.info("  1. Training data collection")
        logger.info("  2. Model training pipeline")
        logger.info("  3. Model validation and testing")
        logger.info("  4. Conversion to Core ML format")
        logger.info("  5. Bundle integration")
        
        throw CoreMLFactoryError.productionModeNotImplemented
    }
}

// MARK: - Model Validation Report

struct ModelValidationReport {
    var intentClassification: ModelStatus = .notTested
    var speechEnhancement: ModelStatus = .notTested
    var responseGeneration: ModelStatus = .notTested
    
    enum ModelStatus {
        case notTested
        case loaded
        case working
        case fallback
        case error(String)
        
        var displayString: String {
            switch self {
            case .notTested: return "Not Tested"
            case .loaded: return "Loaded"
            case .working: return "Working"
            case .fallback: return "Fallback Mode"
            case .error(let message): return "Error: \(message)"
            }
        }
        
        var isHealthy: Bool {
            switch self {
            case .working, .fallback: return true
            case .loaded, .notTested, .error: return false
            }
        }
    }
    
    var overallHealth: Bool {
        return intentClassification.isHealthy && 
               speechEnhancement.isHealthy && 
               responseGeneration.isHealthy
    }
}

// MARK: - Core ML Factory Errors

enum CoreMLFactoryError: LocalizedError {
    case productionModeNotImplemented
    case modelCreationFailed(String)
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .productionModeNotImplemented:
            return "Production model creation is not yet implemented. Currently using development fallbacks."
        case .modelCreationFailed(let message):
            return "Failed to create Core ML model: \(message)"
        case .validationFailed(let message):
            return "Model validation failed: \(message)"
        }
    }
}

// MARK: - Development Utilities

extension CoreMLModelFactory {
    
    /// Provides detailed information about the Core ML environment
    func getEnvironmentInfo() -> CoreMLEnvironmentInfo {
        var info = CoreMLEnvironmentInfo()
        
        // Check device capabilities
        info.deviceSupportsNeuralEngine = MLModel.availableComputeDevices.contains { device in
            device.description.contains("Neural Engine") || device.description.contains("ANE")
        }
        
        info.availableComputeDevices = MLModel.availableComputeDevices.map { $0.description }
        
        // Check for model files in bundle
        let modelFiles = [
            "IntentClassifier.mlmodelc",
            "SpeechEnhancer.mlmodelc",
            "ResponseGenerator.mlmodelc",
            "OfflineIntentClassifier.mlmodelc",
            "OfflineResponseGenerator.mlmodelc",
            "OfflineSpeechEnhancer.mlmodelc"
        ]
        
        for modelFile in modelFiles {
            if Bundle.main.url(forResource: String(modelFile.dropLast(9)), withExtension: "mlmodelc") != nil {
                info.availableModelFiles.append(modelFile)
            }
        }
        
        info.operatingMode = info.availableModelFiles.isEmpty ? .developmentFallback : .production
        
        return info
    }
}

// MARK: - Core ML Environment Info

struct CoreMLEnvironmentInfo {
    var deviceSupportsNeuralEngine: Bool = false
    var availableComputeDevices: [String] = []
    var availableModelFiles: [String] = []
    var operatingMode: OperatingMode = .developmentFallback
    
    enum OperatingMode {
        case production
        case developmentFallback
        
        var description: String {
            switch self {
            case .production: return "Production (with actual Core ML models)"
            case .developmentFallback: return "Development (using rule-based fallbacks)"
            }
        }
    }
}