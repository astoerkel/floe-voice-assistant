import Foundation
import UIKit
import Network
import CoreML
import CryptoKit
import BackgroundTasks

/// Manages Core ML model updates with background processing, incremental downloads, and safe model swapping
@MainActor
public class ModelUpdateManager: ObservableObject {
    // MARK: - Published Properties
    @Published public var isUpdateAvailable: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var updateStatus: UpdateStatus = .idle
    @Published public var lastUpdateCheck: Date?
    @Published public var availableVersion: String?
    @Published public var currentVersion: String?
    
    // MARK: - Types
    public enum UpdateStatus: Equatable {
        case idle
        case checking
        case downloading
        case validating
        case installing
        case completed
        case failed(Error)
        case rollback
        
        public static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.checking, .checking),
                 (.downloading, .downloading),
                 (.validating, .validating),
                 (.installing, .installing),
                 (.completed, .completed),
                 (.rollback, .rollback):
                return true
            case (.failed, .failed):
                return true  // Consider all failed states equal
            default:
                return false
            }
        }
    }
    
    public enum UpdateType: Sendable {
        case delta(String) // Diff from version
        case fullModel
        case abTest(String) // A/B test ID
    }
    
    public enum UpdateStrategy: Equatable, Sendable {
        case immediate
        case gradual(percentage: Int)
        case scheduled(Date)
        case optimal // Charging + Wi-Fi
    }
    
    private struct ModelUpdate: Sendable {
        let version: String
        let type: UpdateType
        let downloadURL: URL
        let checksum: String
        let size: Int64
        let strategy: UpdateStrategy
        let changelog: String
        let compatibility: [String: String] // Changed from Any to String for Sendable conformance
    }
    
    private struct ModelMetadata {
        let version: String
        let downloadDate: Date
        let size: Int64
        let checksum: String
        let performanceMetrics: [String: Double]
        let isActive: Bool
        let backupPath: URL?
    }
    
    // MARK: - Private Properties
    private let updateServerURL: URL
    private let modelDirectory: URL
    private let backupDirectory: URL
    private let versionControl: ModelVersionControl
    private let networkMonitor = NWPathMonitor()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var downloadTask: URLSessionDownloadTask?
    private let session: URLSession
    
    // Configuration
    private let maxBackupVersions = 3
    private let updateCheckInterval: TimeInterval = 6 * 3600 // 6 hours
    private let minBatteryLevel: Float = 0.3 // 30%
    private let requiredDiskSpace: Int64 = 500 * 1024 * 1024 // 500MB
    
    // MARK: - Initialization
    public init(updateServerURL: URL, versionControl: ModelVersionControl) {
        self.updateServerURL = updateServerURL
        self.versionControl = versionControl
        
        // Setup directories
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.modelDirectory = documentsURL.appendingPathComponent("CoreMLModels")
        self.backupDirectory = documentsURL.appendingPathComponent("ModelBackups")
        
        // Create directories
        try? FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        
        // Configure URL session
        let config = URLSessionConfiguration.background(withIdentifier: "com.voiceassistant.model-updates")
        config.allowsCellularAccess = false
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        
        setupNetworkMonitoring()
        registerBackgroundTasks()
        loadCurrentVersion()
    }
    
    // MARK: - Public Interface
    
    /// Check for available model updates
    public func checkForUpdates() async {
        guard updateStatus != .checking else { return }
        
        await MainActor.run {
            updateStatus = .checking
            lastUpdateCheck = Date()
        }
        
        do {
            let availableUpdate = try await fetchAvailableUpdate()
            
            await MainActor.run {
                if let update = availableUpdate {
                    self.availableVersion = update.version
                    self.isUpdateAvailable = versionControl.shouldUpdate(
                        from: currentVersion ?? "1.0.0",
                        to: update.version
                    )
                }
                self.updateStatus = .idle
            }
        } catch {
            await MainActor.run {
                self.updateStatus = .failed(error)
            }
        }
    }
    
    /// Start model update with specified strategy
    public func startUpdate(strategy: UpdateStrategy = .optimal) async {
        guard isUpdateAvailable, updateStatus == .idle else { return }
        
        // Check optimal conditions for update
        let isOptimal = await isOptimalForUpdate()
        if strategy == .optimal && !isOptimal {
            scheduleOptimalUpdate()
            return
        }
        
        do {
            let update = try await fetchAvailableUpdate()
            guard let modelUpdate = update else { return }
            
            await performUpdate(modelUpdate: modelUpdate)
            
        } catch {
            await MainActor.run {
                self.updateStatus = .failed(error)
            }
        }
    }
    
    /// Cancel ongoing update
    public func cancelUpdate() {
        downloadTask?.cancel()
        endBackgroundTask()
        
        Task { @MainActor in
            updateStatus = .idle
            downloadProgress = 0.0
        }
    }
    
    /// Rollback to previous model version
    public func rollbackToPreviousVersion() async -> Bool {
        guard let previousVersion = versionControl.getPreviousVersion() else {
            return false
        }
        
        await MainActor.run {
            updateStatus = .rollback
        }
        
        do {
            // Backup current model before rollback
            try await backupCurrentModel()
            
            // Restore previous version
            let success = try await restoreModelVersion(previousVersion)
            
            if success {
                await MainActor.run {
                    self.currentVersion = previousVersion
                    self.updateStatus = .completed
                }
                
                // Record rollback event
                versionControl.recordRollback(from: currentVersion ?? "unknown", to: previousVersion)
            }
            
            return success
            
        } catch {
            await MainActor.run {
                self.updateStatus = .failed(error)
            }
            return false
        }
    }
    
    /// Force update check and download if available
    public func forceUpdate() async {
        await checkForUpdates()
        if isUpdateAvailable {
            await startUpdate(strategy: .immediate)
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            // Monitor network changes for optimal update timing
            if path.status == .satisfied && path.isExpensive == false {
                Task {
                    await self?.checkOptimalConditions()
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    private func registerBackgroundTasks() {
        // Register background tasks for model updates
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.voiceassistant.model-update-check",
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundUpdateCheck(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.voiceassistant.model-download",
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundDownload(task: task as! BGProcessingTask)
        }
    }
    
    private func fetchAvailableUpdate() async throws -> ModelUpdate? {
        let url = updateServerURL.appendingPathComponent("check-update")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Include current version and device info
        let requestBody = [
            "currentVersion": currentVersion ?? "1.0.0",
            "deviceModel": UIDevice.current.model,
            "osVersion": UIDevice.current.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpMethod = "POST"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.serverError
        }
        
        let updateInfo = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let updateInfo = updateInfo,
              let hasUpdate = updateInfo["hasUpdate"] as? Bool,
              hasUpdate else {
            return nil
        }
        
        // Parse update information
        guard let version = updateInfo["version"] as? String,
              let downloadURLString = updateInfo["downloadURL"] as? String,
              let downloadURL = URL(string: downloadURLString),
              let checksum = updateInfo["checksum"] as? String,
              let size = updateInfo["size"] as? Int64,
              let changelog = updateInfo["changelog"] as? String else {
            throw UpdateError.invalidResponse
        }
        
        let updateType: UpdateType
        if let deltaFrom = updateInfo["deltaFrom"] as? String {
            updateType = .delta(deltaFrom)
        } else if let abTestId = updateInfo["abTestId"] as? String {
            updateType = .abTest(abTestId)
        } else {
            updateType = .fullModel
        }
        
        let strategy: UpdateStrategy
        if let strategyString = updateInfo["strategy"] as? String {
            switch strategyString {
            case "immediate":
                strategy = .immediate
            case "gradual":
                let percentage = updateInfo["gradualPercentage"] as? Int ?? 10
                strategy = .gradual(percentage: percentage)
            case "scheduled":
                let timestamp = updateInfo["scheduledTime"] as? TimeInterval ?? Date().timeIntervalSince1970
                strategy = .scheduled(Date(timeIntervalSince1970: timestamp))
            default:
                strategy = .optimal
            }
        } else {
            strategy = .optimal
        }
        
        return ModelUpdate(
            version: version,
            type: updateType,
            downloadURL: downloadURL,
            checksum: checksum,
            size: size,
            strategy: strategy,
            changelog: changelog,
            compatibility: {
                // Convert [String: Any] to [String: String]
                guard let rawCompatibility = updateInfo["compatibility"] as? [String: Any] else {
                    return [:]
                }
                return rawCompatibility.compactMapValues { value in
                    if let stringValue = value as? String {
                        return stringValue
                    } else {
                        return String(describing: value)
                    }
                }
            }()
        )
    }
    
    private func performUpdate(modelUpdate: ModelUpdate) async {
        do {
            await MainActor.run {
                updateStatus = .downloading
                downloadProgress = 0.0
            }
            
            // Start background task
            beginBackgroundTask()
            
            // Download model
            let downloadedURL = try await downloadModel(modelUpdate: modelUpdate)
            
            await MainActor.run {
                updateStatus = .validating
            }
            
            // Validate downloaded model
            try await validateModel(at: downloadedURL, expectedChecksum: modelUpdate.checksum)
            
            await MainActor.run {
                updateStatus = .installing
            }
            
            // Backup current model
            try await backupCurrentModel()
            
            // Install new model
            try await installModel(from: downloadedURL, version: modelUpdate.version, type: modelUpdate.type)
            
            await MainActor.run {
                self.currentVersion = modelUpdate.version
                self.isUpdateAvailable = false
                self.availableVersion = nil
                self.updateStatus = .completed
                self.downloadProgress = 1.0
            }
            
            // Record successful update
            versionControl.recordUpdate(
                to: modelUpdate.version,
                type: modelUpdate.type,
                performanceBaseline: [:]
            )
            
            // Cleanup
            try? FileManager.default.removeItem(at: downloadedURL)
            endBackgroundTask()
            
        } catch {
            await MainActor.run {
                self.updateStatus = .failed(error)
            }
            endBackgroundTask()
        }
    }
    
    private func downloadModel(modelUpdate: ModelUpdate) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let downloadTask = session.downloadTask(with: modelUpdate.downloadURL) { [weak self] (tempURL, response, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let tempURL = tempURL else {
                    continuation.resume(throwing: UpdateError.downloadFailed)
                    return
                }
                
                // Move to permanent location
                guard let strongSelf = self else {
                    continuation.resume(throwing: UpdateError.fileSystemError)
                    return
                }
                
                let permanentURL = strongSelf.modelDirectory.appendingPathComponent("temp_\(modelUpdate.version).mlmodelc")
                
                do {
                    if FileManager.default.fileExists(atPath: permanentURL.path) {
                        try FileManager.default.removeItem(at: permanentURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: permanentURL)
                    continuation.resume(returning: permanentURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            // Track download progress
            let progressObserver = downloadTask.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                Task { @MainActor in
                    self?.downloadProgress = progress.fractionCompleted
                }
            }
            
            downloadTask.resume()
            self.downloadTask = downloadTask
            
            // Keep reference to observer
            objc_setAssociatedObject(downloadTask, "progressObserver", progressObserver, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    private func validateModel(at url: URL, expectedChecksum: String) async throws {
        // Validate file existence
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw UpdateError.fileNotFound
        }
        
        // Validate checksum
        let actualChecksum = try await calculateChecksum(for: url)
        guard actualChecksum == expectedChecksum else {
            throw UpdateError.checksumMismatch
        }
        
        // Validate Core ML model
        do {
            let model = try MLModel(contentsOf: url)
            let metadata = model.modelDescription
            
            // Basic validation - ensure model has expected inputs/outputs
            guard !metadata.inputDescriptionsByName.isEmpty,
                  !metadata.outputDescriptionsByName.isEmpty else {
                throw UpdateError.invalidModel
            }
            
        } catch {
            throw UpdateError.invalidModel
        }
    }
    
    private func calculateChecksum(for url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func backupCurrentModel() async throws {
        guard let currentVersion = currentVersion else { return }
        
        let currentModelURL = modelDirectory.appendingPathComponent("\(currentVersion).mlmodelc")
        guard FileManager.default.fileExists(atPath: currentModelURL.path) else { return }
        
        let backupURL = backupDirectory.appendingPathComponent("\(currentVersion)_backup.mlmodelc")
        
        if FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.removeItem(at: backupURL)
        }
        
        try FileManager.default.copyItem(at: currentModelURL, to: backupURL)
        
        // Cleanup old backups
        try cleanupOldBackups()
    }
    
    private func installModel(from sourceURL: URL, version: String, type: UpdateType) async throws {
        let destinationURL = modelDirectory.appendingPathComponent("\(version).mlmodelc")
        
        // Handle different update types
        switch type {
        case .delta(let baseVersion):
            try await applyDeltaUpdate(from: sourceURL, baseVersion: baseVersion, to: destinationURL)
        case .fullModel, .abTest(_):
            // Full model replacement
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }
        
        // Update symlink to current model
        let currentModelLink = modelDirectory.appendingPathComponent("current.mlmodelc")
        if FileManager.default.fileExists(atPath: currentModelLink.path) {
            try FileManager.default.removeItem(at: currentModelLink)
        }
        
        try FileManager.default.createSymbolicLink(at: currentModelLink, withDestinationURL: destinationURL)
    }
    
    private func applyDeltaUpdate(from deltaURL: URL, baseVersion: String, to destinationURL: URL) async throws {
        // This is a simplified delta update implementation
        // In practice, you would implement binary diff application
        _ = modelDirectory.appendingPathComponent("\(baseVersion).mlmodelc")
        
        // For now, treat as full update (delta implementation would be more complex)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: deltaURL, to: destinationURL)
    }
    
    private func restoreModelVersion(_ version: String) async throws -> Bool {
        let backupURL = backupDirectory.appendingPathComponent("\(version)_backup.mlmodelc")
        let modelURL = modelDirectory.appendingPathComponent("\(version).mlmodelc")
        
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            return false
        }
        
        if FileManager.default.fileExists(atPath: modelURL.path) {
            try FileManager.default.removeItem(at: modelURL)
        }
        
        try FileManager.default.copyItem(at: backupURL, to: modelURL)
        
        // Update current symlink
        let currentModelLink = modelDirectory.appendingPathComponent("current.mlmodelc")
        if FileManager.default.fileExists(atPath: currentModelLink.path) {
            try FileManager.default.removeItem(at: currentModelLink)
        }
        
        try FileManager.default.createSymbolicLink(at: currentModelLink, withDestinationURL: modelURL)
        
        return true
    }
    
    private func cleanupOldBackups() throws {
        let backupFiles = try FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey])
        
        let sortedBackups = backupFiles
            .compactMap { url -> (URL, Date)? in
                guard let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                    return nil
                }
                return (url, creationDate)
            }
            .sorted { $0.1 > $1.1 } // Sort by creation date, newest first
        
        // Keep only the most recent backups
        if sortedBackups.count > maxBackupVersions {
            let filesToDelete = Array(sortedBackups.dropFirst(maxBackupVersions))
            for (url, _) in filesToDelete {
                try FileManager.default.removeItem(at: url)
            }
        }
    }
    
    private func loadCurrentVersion() {
        // Try to load current version from installed models
        let currentModelLink = modelDirectory.appendingPathComponent("current.mlmodelc")
        
        if FileManager.default.fileExists(atPath: currentModelLink.path) {
            // Extract version from symlink target
            do {
                let destination = try FileManager.default.destinationOfSymbolicLink(atPath: currentModelLink.path)
                let filename = URL(fileURLWithPath: destination).lastPathComponent
                if filename.hasSuffix(".mlmodelc") {
                    let version = String(filename.dropLast(9)) // Remove .mlmodelc
                    self.currentVersion = version
                }
            } catch {
                // Fallback to default version
                self.currentVersion = "1.0.0"
            }
        } else {
            self.currentVersion = "1.0.0"
        }
    }
    
    // MARK: - Background Tasks
    
    private func handleBackgroundUpdateCheck(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await checkForUpdates()
            
            let isSuccessful: Bool
            switch updateStatus {
            case .failed:
                isSuccessful = false
            default:
                isSuccessful = true
            }
            
            task.setTaskCompleted(success: isSuccessful)
        }
    }
    
    private func handleBackgroundDownload(task: BGProcessingTask) {
        task.expirationHandler = {
            self.cancelUpdate()
            task.setTaskCompleted(success: false)
        }
        
        Task {
            let isOptimal = await isOptimalForUpdate()
            if isUpdateAvailable && isOptimal {
                await startUpdate(strategy: .optimal)
            }
            task.setTaskCompleted(success: updateStatus == .completed)
        }
    }
    
    // MARK: - Optimal Update Timing
    
    private func isOptimalForUpdate() async -> Bool {
        // Check battery level
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        guard batteryLevel >= minBatteryLevel || UIDevice.current.batteryState == .charging else {
            return false
        }
        
        // Check network conditions
        let path = networkMonitor.currentPath
        guard path.status == .satisfied && !path.isExpensive else {
            return false
        }
        
        // Check available disk space
        guard hasRequiredDiskSpace() else {
            return false
        }
        
        return true
    }
    
    private func hasRequiredDiskSpace() -> Bool {
        do {
            let resourceValues = try modelDirectory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let availableCapacity = resourceValues.volumeAvailableCapacity {
                return Int64(availableCapacity) >= requiredDiskSpace
            }
        } catch {
            return false
        }
        return false
    }
    
    private func checkOptimalConditions() async {
        let isOptimal = await isOptimalForUpdate()
        if isUpdateAvailable && isOptimal {
            await startUpdate(strategy: .optimal)
        }
    }
    
    private func scheduleOptimalUpdate() {
        // Schedule background tasks for optimal update timing
        let updateCheckRequest = BGAppRefreshTaskRequest(identifier: "com.voiceassistant.model-update-check")
        updateCheckRequest.earliestBeginDate = Date(timeIntervalSinceNow: updateCheckInterval)
        
        let downloadRequest = BGProcessingTaskRequest(identifier: "com.voiceassistant.model-download")
        downloadRequest.requiresNetworkConnectivity = true
        downloadRequest.requiresExternalPower = false
        downloadRequest.earliestBeginDate = Date(timeIntervalSinceNow: 300) // 5 minutes
        
        try? BGTaskScheduler.shared.submit(updateCheckRequest)
        try? BGTaskScheduler.shared.submit(downloadRequest)
    }
    
    // MARK: - Background Task Management
    
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ModelUpdate") {
            Task { @MainActor in
                self.endBackgroundTask()
            }
        }
    }
    
    @MainActor
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}

// MARK: - Error Types

public enum UpdateError: LocalizedError {
    case serverError
    case invalidResponse
    case downloadFailed
    case checksumMismatch
    case invalidModel
    case fileSystemError
    case fileNotFound
    case insufficientSpace
    case networkUnavailable
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .serverError:
            return "Server error occurred while checking for updates"
        case .invalidResponse:
            return "Invalid response from update server"
        case .downloadFailed:
            return "Failed to download model update"
        case .checksumMismatch:
            return "Downloaded model failed integrity check"
        case .invalidModel:
            return "Downloaded model is not valid"
        case .fileSystemError:
            return "File system error occurred"
        case .fileNotFound:
            return "Required file not found"
        case .insufficientSpace:
            return "Insufficient disk space for update"
        case .networkUnavailable:
            return "Network connection required for update"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}