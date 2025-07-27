//
//  MLModelProtocol.swift
//  VoiceAssistant
//
//  Created by Claude Code on 2025-07-22.
//  Core ML model protocol defining common interface for all on-device AI models
//

import Foundation
import CoreML

// MARK: - Model Performance Metrics
struct ModelPerformanceMetrics {
    let modelName: String
    let loadTime: TimeInterval
    let predictionTime: TimeInterval
    let memoryUsage: Int64 // in bytes
    let confidence: Float
    let inputSize: Int
    let outputSize: Int
    let timestamp: Date
}

// MARK: - Model Input/Output Types
protocol MLModelInput {
    var inputIdentifier: String { get }
}

protocol MLModelOutput {
    var confidence: Float { get }
    var outputIdentifier: String { get }
}

// MARK: - Model Configuration
struct MLModelConfig {
    let modelName: String
    let version: String
    let computeUnits: MLComputeUnits
    let confidenceThreshold: Float
    let maxPredictionTime: TimeInterval
    let enableBackgroundUpdates: Bool
}

// MARK: - Core ML Model Protocol
protocol MLModelProtocol: AnyObject {
    // MARK: - Model Properties
    var modelName: String { get }
    var version: String { get }
    var isLoaded: Bool { get }
    var config: MLModelConfig { get }
    var lastPerformanceMetrics: ModelPerformanceMetrics? { get }
    
    // MARK: - Lifecycle Management
    func loadModel() async throws
    func unloadModel() async throws
    func reloadModel() async throws
    
    // MARK: - Prediction Interface
    func predict<Input: MLModelInput, Output: MLModelOutput>(
        input: Input,
        completion: @escaping (Result<Output, MLModelError>) -> Void
    )
    
    func predict<Input: MLModelInput, Output: MLModelOutput>(
        input: Input
    ) async throws -> Output
    
    // MARK: - Performance Monitoring
    func getPerformanceMetrics() -> ModelPerformanceMetrics?
    func resetPerformanceMetrics()
    
    // MARK: - Model Updates
    func checkForUpdates() async throws -> Bool
    func updateModel() async throws
    
    // MARK: - Memory Management
    func getMemoryUsage() -> Int64
    func optimizeMemory() async throws
}

// MARK: - Model Error Types
enum MLModelError: Error, LocalizedError, Equatable {
    case modelNotFound(String)
    case loadingFailed(String)
    case predictionFailed(String)
    case updateFailed(String)
    case memoryExceeded(Int64)
    case confidenceTooLow(Float)
    case timeout(TimeInterval)
    case invalidInput(String)
    case invalidOutput(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .loadingFailed(let reason):
            return "Model loading failed: \(reason)"
        case .predictionFailed(let reason):
            return "Prediction failed: \(reason)"
        case .updateFailed(let reason):
            return "Model update failed: \(reason)"
        case .memoryExceeded(let usage):
            return "Memory exceeded: \(usage) bytes"
        case .confidenceTooLow(let confidence):
            return "Confidence too low: \(confidence)"
        case .timeout(let duration):
            return "Operation timed out after \(duration) seconds"
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        case .invalidOutput(let reason):
            return "Invalid output: \(reason)"
        }
    }
}

// MARK: - Model State
enum MLModelState {
    case unloaded
    case loading
    case loaded
    case predicting
    case updating
    case error(MLModelError)
}

// MARK: - Model Update Info
struct MLModelUpdateInfo {
    let currentVersion: String
    let latestVersion: String
    let updateSize: Int64
    let isRequired: Bool
    let releaseNotes: String?
    let downloadURL: URL?
}

// MARK: - Model Statistics
struct MLModelStatistics {
    let totalPredictions: Int
    let averagePredictionTime: TimeInterval
    let averageConfidence: Float
    let successRate: Float
    let memoryPeakUsage: Int64
    let lastUsed: Date?
}

// MARK: - Default Protocol Extension
extension MLModelProtocol {
    
    // Default async prediction wrapper
    func predict<Input: MLModelInput, Output: MLModelOutput>(
        input: Input
    ) async throws -> Output {
        return try await withCheckedThrowingContinuation { continuation in
            predict(input: input) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // Default reload implementation
    func reloadModel() async throws {
        try await unloadModel()
        try await loadModel()
    }
    
    // Default memory optimization
    func optimizeMemory() async throws {
        if !isLoaded {
            return
        }
        try await unloadModel()
        try await loadModel()
    }
}