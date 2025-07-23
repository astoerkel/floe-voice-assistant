import Foundation
import CryptoKit

/// Secure storage manager for analytics data with AES-256-GCM encryption
/// All data is encrypted at rest and stored locally on device
public class AnalyticsStorageManager {
    
    // MARK: - Types
    
    public struct StorageMetrics {
        let totalSize: Int64
        let fileCount: Int
        let lastBackup: Date?
        let encryptionStatus: Bool
        
        public init(totalSize: Int64, fileCount: Int, lastBackup: Date?, encryptionStatus: Bool) {
            self.totalSize = totalSize
            self.fileCount = fileCount
            self.lastBackup = lastBackup
            self.encryptionStatus = encryptionStatus
        }
    }
    
    public enum StorageError: Error {
        case encryptionFailed
        case decryptionFailed
        case fileNotFound
        case insufficientSpace
        case corruptedData
        case keyDerivationFailed
        case directoryCreationFailed
        
        public var localizedDescription: String {
            switch self {
            case .encryptionFailed:
                return "Failed to encrypt data"
            case .decryptionFailed:
                return "Failed to decrypt data"
            case .fileNotFound:
                return "Analytics file not found"
            case .insufficientSpace:
                return "Insufficient storage space"
            case .corruptedData:
                return "Analytics data is corrupted"
            case .keyDerivationFailed:
                return "Failed to derive encryption key"
            case .directoryCreationFailed:
                return "Failed to create analytics directory"
            }
        }
    }
    
    // MARK: - Properties
    
    private let encryptionKey: SymmetricKey
    private let fileManager = FileManager.default
    private let storageDirectory: URL
    private let backupDirectory: URL
    
    // File names
    private let patternsFileName = "usage_patterns.encrypted"
    private let accuracyFileName = "model_accuracy.encrypted"
    private let performanceFileName = "performance_metrics.encrypted"
    private let behaviorFileName = "user_behavior.encrypted"
    private let metadataFileName = "analytics_metadata.encrypted"
    
    // Encryption settings
    private let keyDerivationIterations = 100_000
    private let saltSize = 32
    private let tagSize = 16
    
    // MARK: - Initialization
    
    public init(encryptionKey: SymmetricKey) throws {
        self.encryptionKey = encryptionKey
        
        // Set up storage directories
        let documentsURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        self.storageDirectory = documentsURL.appendingPathComponent("PrivateAnalytics", isDirectory: true)
        self.backupDirectory = storageDirectory.appendingPathComponent("Backups", isDirectory: true)
        
        try createDirectoriesIfNeeded()
    }
    
    // MARK: - Public Interface
    
    /// Save analytics data to encrypted storage
    public func saveAnalyticsData(_ data: AnalyticsData) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Save each data type in parallel
            group.addTask {
                try await self.savePatterns(data.patterns)
            }
            
            group.addTask {
                try await self.saveAccuracyMetrics(data.accuracy)
            }
            
            group.addTask {
                try await self.savePerformanceMetrics(data.performance)
            }
            
            group.addTask {
                try await self.saveBehaviorInsights(data.behavior)
            }
            
            // Wait for all saves to complete
            try await group.waitForAll()
        }
        
        // Update metadata
        try await updateMetadata()
    }
    
    /// Load analytics data from encrypted storage
    public func loadAnalyticsData() async throws -> AnalyticsData {
        async let patterns = loadPatterns()
        async let accuracy = loadAccuracyMetrics()
        async let performance = loadPerformanceMetrics()
        async let behavior = loadBehaviorInsights()
        
        return try await AnalyticsData(
            patterns: patterns,
            accuracy: accuracy,
            performance: performance,
            behavior: behavior
        )
    }
    
    /// Delete all analytics data
    public func deleteAllData() async throws {
        let filesToDelete = [
            patternsFileName,
            accuracyFileName,
            performanceFileName,
            behaviorFileName,
            metadataFileName
        ]
        
        for fileName in filesToDelete {
            let fileURL = storageDirectory.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        }
        
        // Clean up backup directory
        try await cleanupBackups()
    }
    
    /// Calculate total data size
    public func calculateDataSize() async throws -> Int64 {
        let fileURLs = [
            storageDirectory.appendingPathComponent(patternsFileName),
            storageDirectory.appendingPathComponent(accuracyFileName),
            storageDirectory.appendingPathComponent(performanceFileName),
            storageDirectory.appendingPathComponent(behaviorFileName),
            storageDirectory.appendingPathComponent(metadataFileName)
        ]
        
        var totalSize: Int64 = 0
        
        for fileURL in fileURLs {
            if fileManager.fileExists(atPath: fileURL.path) {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let size = attributes[.size] as? Int64 {
                    totalSize += size
                }
            }
        }
        
        return totalSize
    }
    
    /// Get storage metrics
    public func getStorageMetrics() async throws -> StorageMetrics {
        let totalSize = try await calculateDataSize()
        let fileCount = try getFileCount()
        let lastBackup = try getLastBackupDate()
        
        return StorageMetrics(
            totalSize: totalSize,
            fileCount: fileCount,
            lastBackup: lastBackup,
            encryptionStatus: true
        )
    }
    
    /// Create backup of analytics data
    public func createBackup() async throws -> URL {
        let backupTimestamp = DateFormatter.backupFormatter.string(from: Date())
        let backupName = "analytics_backup_\(backupTimestamp)"
        let backupURL = backupDirectory.appendingPathComponent(backupName, isDirectory: true)
        
        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)
        
        // Copy all analytics files to backup directory
        let filesToBackup = [
            patternsFileName,
            accuracyFileName,
            performanceFileName,
            behaviorFileName,
            metadataFileName
        ]
        
        for fileName in filesToBackup {
            let sourceURL = storageDirectory.appendingPathComponent(fileName)
            let destinationURL = backupURL.appendingPathComponent(fileName)
            
            if fileManager.fileExists(atPath: sourceURL.path) {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
        }
        
        return backupURL
    }
    
    /// Restore from backup
    public func restoreFromBackup(_ backupURL: URL) async throws {
        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw StorageError.fileNotFound
        }
        
        // First create a backup of current data
        let emergencyBackup = try await createBackup()
        
        do {
            // Delete current data
            try await deleteAllData()
            
            // Copy backup files to storage directory
            let backupContents = try fileManager.contentsOfDirectory(at: backupURL, includingPropertiesForKeys: nil)
            
            for backupFile in backupContents {
                let destinationURL = storageDirectory.appendingPathComponent(backupFile.lastPathComponent)
                try fileManager.copyItem(at: backupFile, to: destinationURL)
            }
            
        } catch {
            // If restore fails, restore from emergency backup
            try await restoreFromBackup(emergencyBackup)
            throw error
        }
    }
    
    /// Export analytics data for user review (unencrypted)
    public func exportForReview() async throws -> Data {
        let data = try await loadAnalyticsData()
        let exportData = StorageAnalyticsExportData(
            patterns: data.patterns,
            accuracy: data.accuracy,
            performance: data.performance,
            behavior: data.behavior,
            exportDate: Date(),
            storageMetrics: try await getStorageMetrics()
        )
        
        return try JSONEncoder().encode(exportData)
    }
    
    // MARK: - Private Methods
    
    private func createDirectoriesIfNeeded() throws {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
        
        if !fileManager.fileExists(atPath: backupDirectory.path) {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func savePatterns(_ patterns: [PrivateAnalytics.UsagePattern]) async throws {
        let data = try JSONEncoder().encode(patterns)
        let encryptedData = try encrypt(data)
        let fileURL = storageDirectory.appendingPathComponent(patternsFileName)
        try encryptedData.write(to: fileURL)
    }
    
    private func loadPatterns() async throws -> [PrivateAnalytics.UsagePattern] {
        let fileURL = storageDirectory.appendingPathComponent(patternsFileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        let encryptedData = try Data(contentsOf: fileURL)
        let decryptedData = try decrypt(encryptedData)
        return try JSONDecoder().decode([PrivateAnalytics.UsagePattern].self, from: decryptedData)
    }
    
    private func saveAccuracyMetrics(_ metrics: [PrivateAnalytics.ModelAccuracyMetrics]) async throws {
        let data = try JSONEncoder().encode(metrics)
        let encryptedData = try encrypt(data)
        let fileURL = storageDirectory.appendingPathComponent(accuracyFileName)
        try encryptedData.write(to: fileURL)
    }
    
    private func loadAccuracyMetrics() async throws -> [PrivateAnalytics.ModelAccuracyMetrics] {
        let fileURL = storageDirectory.appendingPathComponent(accuracyFileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        let encryptedData = try Data(contentsOf: fileURL)
        let decryptedData = try decrypt(encryptedData)
        return try JSONDecoder().decode([PrivateAnalytics.ModelAccuracyMetrics].self, from: decryptedData)
    }
    
    private func savePerformanceMetrics(_ metrics: [PrivateAnalytics.PrivatePerformanceMetrics]) async throws {
        let data = try JSONEncoder().encode(metrics)
        let encryptedData = try encrypt(data)
        let fileURL = storageDirectory.appendingPathComponent(performanceFileName)
        try encryptedData.write(to: fileURL)
    }
    
    private func loadPerformanceMetrics() async throws -> [PrivateAnalytics.PrivatePerformanceMetrics] {
        let fileURL = storageDirectory.appendingPathComponent(performanceFileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        let encryptedData = try Data(contentsOf: fileURL)
        let decryptedData = try decrypt(encryptedData)
        return try JSONDecoder().decode([PrivateAnalytics.PrivatePerformanceMetrics].self, from: decryptedData)
    }
    
    private func saveBehaviorInsights(_ insights: [PrivateAnalytics.UserBehaviorInsights]) async throws {
        let data = try JSONEncoder().encode(insights)
        let encryptedData = try encrypt(data)
        let fileURL = storageDirectory.appendingPathComponent(behaviorFileName)
        try encryptedData.write(to: fileURL)
    }
    
    private func loadBehaviorInsights() async throws -> [PrivateAnalytics.UserBehaviorInsights] {
        let fileURL = storageDirectory.appendingPathComponent(behaviorFileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        let encryptedData = try Data(contentsOf: fileURL)
        let decryptedData = try decrypt(encryptedData)
        return try JSONDecoder().decode([PrivateAnalytics.UserBehaviorInsights].self, from: decryptedData)
    }
    
    private func updateMetadata() async throws {
        let metadata = AnalyticsMetadata(
            lastUpdate: Date(),
            version: "1.0",
            fileCount: try getFileCount(),
            totalSize: try await calculateDataSize(),
            encryptionVersion: "AES-256-GCM"
        )
        
        let data = try JSONEncoder().encode(metadata)
        let encryptedData = try encrypt(data)
        let fileURL = storageDirectory.appendingPathComponent(metadataFileName)
        try encryptedData.write(to: fileURL)
    }
    
    private func encrypt(_ data: Data) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
            return sealedBox.combined!
        } catch {
            throw StorageError.encryptionFailed
        }
    }
    
    private func decrypt(_ encryptedData: Data) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: encryptionKey)
        } catch {
            throw StorageError.decryptionFailed
        }
    }
    
    private func getFileCount() throws -> Int {
        let contents = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
        return contents.filter { !$0.hasDirectoryPath }.count
    }
    
    private func getLastBackupDate() throws -> Date? {
        guard fileManager.fileExists(atPath: backupDirectory.path) else {
            return nil
        }
        
        let backups = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey])
        
        var latestDate: Date?
        for backup in backups {
            if let creationDate = try backup.resourceValues(forKeys: [.creationDateKey]).creationDate {
                if latestDate == nil || creationDate > latestDate! {
                    latestDate = creationDate
                }
            }
        }
        
        return latestDate
    }
    
    private func cleanupBackups() async throws {
        let backups = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey])
        
        // Keep only the most recent 5 backups
        let sortedBackups = backups.sorted { backup1, backup2 in
            let date1 = try? backup1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            let date2 = try? backup2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            return date1! > date2!
        }
        
        if sortedBackups.count > 5 {
            let backupsToDelete = Array(sortedBackups.dropFirst(5))
            for backup in backupsToDelete {
                try fileManager.removeItem(at: backup)
            }
        }
    }
}

// MARK: - Supporting Types

private struct AnalyticsMetadata: Codable {
    let lastUpdate: Date
    let version: String
    let fileCount: Int
    let totalSize: Int64
    let encryptionVersion: String
}

private struct StorageAnalyticsExportData: Codable {
    let patterns: [PrivateAnalytics.UsagePattern]
    let accuracy: [PrivateAnalytics.ModelAccuracyMetrics]
    let performance: [PrivateAnalytics.PrivatePerformanceMetrics]
    let behavior: [PrivateAnalytics.UserBehaviorInsights]
    let exportDate: Date
    let storageMetrics: AnalyticsStorageManager.StorageMetrics
}

// MARK: - Extensions

extension DateFormatter {
    static let backupFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}

extension AnalyticsStorageManager.StorageMetrics: Codable {}

// Make AnalyticsData visible to storage manager
public struct AnalyticsData: Codable {
    let patterns: [PrivateAnalytics.UsagePattern]
    let accuracy: [PrivateAnalytics.ModelAccuracyMetrics]
    let performance: [PrivateAnalytics.PrivatePerformanceMetrics]
    let behavior: [PrivateAnalytics.UserBehaviorInsights]
    
    public init(patterns: [PrivateAnalytics.UsagePattern], accuracy: [PrivateAnalytics.ModelAccuracyMetrics], performance: [PrivateAnalytics.PrivatePerformanceMetrics], behavior: [PrivateAnalytics.UserBehaviorInsights]) {
        self.patterns = patterns
        self.accuracy = accuracy
        self.performance = performance
        self.behavior = behavior
    }
}