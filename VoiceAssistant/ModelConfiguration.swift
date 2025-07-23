//
//  ModelConfiguration.swift
//  VoiceAssistant
//
//  Created by Claude Code on 2025-07-22.
//  Model configuration manager for version management and settings
//

import Foundation
import CoreML

// MARK: - Model Version Info
struct ModelVersionInfo: Codable, Equatable {
    let modelName: String
    let version: String
    let buildNumber: Int
    let releaseDate: Date
    let minIOSVersion: String
    let fileSize: Int64
    let checksum: String
    let isRequired: Bool
    let deprecationDate: Date?
    let releaseNotes: String?
    
    // Computed property for version comparison
    var versionComponents: [Int] {
        return version.split(separator: ".").compactMap { Int($0) }
    }
}

extension ModelVersionInfo: Comparable {
    static func < (lhs: ModelVersionInfo, rhs: ModelVersionInfo) -> Bool {
        let lhsComponents = lhs.versionComponents
        let rhsComponents = rhs.versionComponents
        
        for i in 0..<max(lhsComponents.count, rhsComponents.count) {
            let lhsValue = i < lhsComponents.count ? lhsComponents[i] : 0
            let rhsValue = i < rhsComponents.count ? rhsComponents[i] : 0
            
            if lhsValue != rhsValue {
                return lhsValue < rhsValue
            }
        }
        
        return lhs.buildNumber < rhs.buildNumber
    }
}

// MARK: - Model Registry
struct ModelRegistry: Codable {
    let version: String
    let lastUpdated: Date
    let models: [String: ModelVersionInfo]
    let registryURL: String
    let nextCheckInterval: TimeInterval
}

// MARK: - Model Configuration Settings
struct ModelConfigurationSettings: Codable {
    var enableAutoUpdates: Bool
    var updateCheckInterval: TimeInterval // in seconds
    var enablePreloading: Bool
    var maxConcurrentModels: Int
    var memoryLimitMB: Int
    var enablePerformanceMonitoring: Bool
    var enableFallbackToServer: Bool
    var confidenceThreshold: Float
    var maxPredictionTimeSeconds: TimeInterval
    var enableBatchProcessing: Bool
    
    static let `default` = ModelConfigurationSettings(
        enableAutoUpdates: true,
        updateCheckInterval: 3600, // 1 hour
        enablePreloading: true,
        maxConcurrentModels: 3,
        memoryLimitMB: 200,
        enablePerformanceMonitoring: true,
        enableFallbackToServer: true,
        confidenceThreshold: 0.7,
        maxPredictionTimeSeconds: 2.0,
        enableBatchProcessing: false
    )
}

// MARK: - Model Update Policy
enum ModelUpdatePolicy: String, CaseIterable, Codable {
    case automatic = "automatic"
    case manual = "manual"
    case wifiOnly = "wifi_only"
    case criticalOnly = "critical_only"
    
    var displayName: String {
        switch self {
        case .automatic: return "Automatic Updates"
        case .manual: return "Manual Updates Only"
        case .wifiOnly: return "WiFi Only"
        case .criticalOnly: return "Critical Updates Only"
        }
    }
}

// MARK: - Model Configuration Manager
@MainActor
class ModelConfigurationManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ModelConfigurationManager()
    
    // MARK: - Published Properties
    @Published private(set) var settings: ModelConfigurationSettings
    @Published private(set) var modelRegistry: ModelRegistry?
    @Published private(set) var localVersions: [String: ModelVersionInfo] = [:]
    @Published private(set) var updatePolicy: ModelUpdatePolicy = .automatic
    @Published private(set) var isCheckingUpdates = false
    @Published private(set) var lastUpdateCheck: Date?
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "ModelConfigurationSettings"
    private let updatePolicyKey = "ModelUpdatePolicy"
    private let localVersionsKey = "LocalModelVersions"
    private let lastUpdateCheckKey = "LastModelUpdateCheck"
    
    // Remote configuration
    private let remoteRegistryURL = "https://floe.cognetica.de/api/models/registry"
    private let urlSession = URLSession.shared
    
    // MARK: - File Paths
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var modelsDirectory: URL {
        documentsDirectory.appendingPathComponent("Models")
    }
    
    // MARK: - Initialization
    private init() {
        self.settings = Self.loadSettings()
        self.updatePolicy = Self.loadUpdatePolicy()
        self.localVersions = Self.loadLocalVersions()
        self.lastUpdateCheck = userDefaults.object(forKey: lastUpdateCheckKey) as? Date
        
        // Create models directory if it doesn't exist
        createModelsDirectoryIfNeeded()
        
        // Load local model registry
        loadLocalModelRegistry()
    }
    
    private func createModelsDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create models directory: \(error)")
        }
    }
    
    // MARK: - Settings Management
    private static func loadSettings() -> ModelConfigurationSettings {
        if let data = UserDefaults.standard.data(forKey: "ModelConfigurationSettings"),
           let settings = try? JSONDecoder().decode(ModelConfigurationSettings.self, from: data) {
            return settings
        }
        return .default
    }
    
    private static func loadUpdatePolicy() -> ModelUpdatePolicy {
        if let policyString = UserDefaults.standard.string(forKey: "ModelUpdatePolicy"),
           let policy = ModelUpdatePolicy(rawValue: policyString) {
            return policy
        }
        return .automatic
    }
    
    private static func loadLocalVersions() -> [String: ModelVersionInfo] {
        if let data = UserDefaults.standard.data(forKey: "LocalModelVersions"),
           let versions = try? JSONDecoder().decode([String: ModelVersionInfo].self, from: data) {
            return versions
        }
        return [:]
    }
    
    func updateSettings(_ newSettings: ModelConfigurationSettings) {
        settings = newSettings
        saveSettings()
    }
    
    func updatePolicy(_ newPolicy: ModelUpdatePolicy) {
        updatePolicy = newPolicy
        userDefaults.set(newPolicy.rawValue, forKey: updatePolicyKey)
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
    
    private func saveLocalVersions() {
        if let data = try? JSONEncoder().encode(localVersions) {
            userDefaults.set(data, forKey: localVersionsKey)
        }
    }
    
    // MARK: - Model Registry Management
    func checkForUpdates() async throws {
        guard !isCheckingUpdates else { return }
        
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }
        
        do {
            let registry = try await fetchRemoteRegistry()
            modelRegistry = registry
            lastUpdateCheck = Date()
            userDefaults.set(lastUpdateCheck, forKey: lastUpdateCheckKey)
            
            // Save registry locally for offline access
            saveLocalRegistry(registry)
            
        } catch {
            print("Failed to fetch model registry: \(error)")
            throw error
        }
    }
    
    private func fetchRemoteRegistry() async throws -> ModelRegistry {
        let url = URL(string: remoteRegistryURL)!
        let (data, _) = try await urlSession.data(from: url)
        return try JSONDecoder().decode(ModelRegistry.self, from: data)
    }
    
    private func saveLocalRegistry(_ registry: ModelRegistry) {
        let registryPath = documentsDirectory.appendingPathComponent("model_registry.json")
        if let data = try? JSONEncoder().encode(registry) {
            try? data.write(to: registryPath)
        }
    }
    
    private func loadLocalModelRegistry() {
        let registryPath = documentsDirectory.appendingPathComponent("model_registry.json")
        if let data = try? Data(contentsOf: registryPath),
           let registry = try? JSONDecoder().decode(ModelRegistry.self, from: data) {
            modelRegistry = registry
        }
    }
    
    // MARK: - Version Management
    func getAvailableUpdates() -> [String: ModelVersionInfo] {
        guard let registry = modelRegistry else { return [:] }
        
        var availableUpdates: [String: ModelVersionInfo] = [:]
        
        for (modelName, remoteVersion) in registry.models {
            if let localVersion = localVersions[modelName] {
                if remoteVersion > localVersion {
                    availableUpdates[modelName] = remoteVersion
                }
            } else {
                // Model not installed locally
                availableUpdates[modelName] = remoteVersion
            }
        }
        
        return availableUpdates
    }
    
    func getCriticalUpdates() -> [String: ModelVersionInfo] {
        return getAvailableUpdates().filter { _, version in
            version.isRequired
        }
    }
    
    func isUpdateAvailable(for modelName: String) -> Bool {
        guard let registry = modelRegistry,
              let remoteVersion = registry.models[modelName] else {
            return false
        }
        
        guard let localVersion = localVersions[modelName] else {
            return true // Not installed = update available
        }
        
        return remoteVersion > localVersion
    }
    
    func shouldAutoUpdate(model: ModelVersionInfo) -> Bool {
        switch updatePolicy {
        case .automatic:
            return true
        case .manual:
            return false
        case .wifiOnly:
            // Check if connected to WiFi (simplified check)
            return isConnectedToWiFi()
        case .criticalOnly:
            return model.isRequired
        }
    }
    
    private func isConnectedToWiFi() -> Bool {
        // Simplified WiFi check - in production, use proper network monitoring
        return true
    }
    
    // MARK: - Model Installation & Updates
    func downloadAndInstallModel(_ modelName: String) async throws {
        guard let registry = modelRegistry,
              let modelInfo = registry.models[modelName] else {
            throw ModelConfigurationError.modelNotFound(modelName)
        }
        
        // Create download URL (mock implementation)
        let downloadURL = URL(string: "https://floe.cognetica.de/api/models/\(modelName)/\(modelInfo.version)")!
        
        do {
            // Download model file
            let (data, _) = try await urlSession.data(from: downloadURL)
            
            // Verify checksum
            let downloadedChecksum = data.sha256
            guard downloadedChecksum == modelInfo.checksum else {
                throw ModelConfigurationError.checksumMismatch
            }
            
            // Save model file
            let modelPath = modelsDirectory.appendingPathComponent("\(modelName).mlmodelc")
            try data.write(to: modelPath)
            
            // Update local version info
            localVersions[modelName] = modelInfo
            saveLocalVersions()
            
        } catch {
            throw ModelConfigurationError.downloadFailed(error.localizedDescription)
        }
    }
    
    func removeModel(_ modelName: String) throws {
        let modelPath = modelsDirectory.appendingPathComponent("\(modelName).mlmodelc")
        
        if FileManager.default.fileExists(atPath: modelPath.path) {
            try FileManager.default.removeItem(at: modelPath)
        }
        
        localVersions.removeValue(forKey: modelName)
        saveLocalVersions()
    }
    
    // MARK: - Model File Management
    func getModelPath(for modelName: String) -> URL? {
        let modelPath = modelsDirectory.appendingPathComponent("\(modelName).mlmodelc")
        return FileManager.default.fileExists(atPath: modelPath.path) ? modelPath : nil
    }
    
    func getModelSize(for modelName: String) -> Int64 {
        guard let modelPath = getModelPath(for: modelName) else { return 0 }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: modelPath.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    func getTotalModelsSize() -> Int64 {
        return localVersions.keys.reduce(0) { total, modelName in
            total + getModelSize(for: modelName)
        }
    }
    
    // MARK: - Cache Management
    func clearModelCache() throws {
        let modelFiles = try FileManager.default.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: nil
        )
        
        for fileURL in modelFiles {
            try FileManager.default.removeItem(at: fileURL)
        }
        
        localVersions.removeAll()
        saveLocalVersions()
    }
    
    // MARK: - Model Validation
    func validateModel(_ modelName: String) async -> Bool {
        guard let modelPath = getModelPath(for: modelName),
              let localVersion = localVersions[modelName] else {
            return false
        }
        
        do {
            // Verify file exists and checksum matches
            let data = try Data(contentsOf: modelPath)
            let checksum = data.sha256
            return checksum == localVersion.checksum
        } catch {
            return false
        }
    }
    
    func validateAllModels() async -> [String: Bool] {
        var results: [String: Bool] = [:]
        
        for modelName in localVersions.keys {
            results[modelName] = await validateModel(modelName)
        }
        
        return results
    }
}

// MARK: - Configuration Errors
enum ModelConfigurationError: Error, LocalizedError {
    case modelNotFound(String)
    case downloadFailed(String)
    case checksumMismatch
    case invalidConfiguration
    case insufficientStorage
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .checksumMismatch:
            return "Downloaded file checksum does not match expected value"
        case .invalidConfiguration:
            return "Invalid model configuration"
        case .insufficientStorage:
            return "Insufficient storage space for model"
        }
    }
}

// MARK: - Extensions
extension Data {
    var sha256: String {
        // Mock checksum implementation
        return "mock_checksum_\(self.count)"
    }
}