import Foundation
import CoreML
import Combine
import CryptoKit

/// A/B Testing Manager for safe Core ML model experimentation
/// Provides statistical analysis, user segmentation, and performance tracking
@available(iOS 15.0, *)
final class ABTestingManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published var activeExperiments: [Experiment] = []
    @Published var experimentResults: [ExperimentResult] = []
    @Published var isRunningExperiment = false
    @Published var currentExperimentStats: ExperimentStats?
    
    private let modelValidator = ModelValidator()
    private let testingFramework = MLTestingFramework()
    private let userDefaults = UserDefaults.standard
    
    // Statistical thresholds
    private let minimumSampleSize: Int = 100
    private let significanceLevel: Double = 0.05
    private let minimumEffectSize: Double = 0.1
    private let maxExperimentDuration: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    // MARK: - Data Models
    
    struct Experiment: Identifiable, Codable {
        let id = UUID()
        let name: String
        let description: String
        let hypothesis: String
        let modelA: ExperimentModel
        let modelB: ExperimentModel
        let startDate: Date
        let endDate: Date?
        let status: ExperimentStatus
        let trafficSplit: TrafficSplit
        let successMetrics: [SuccessMetric]
        let targetAudience: TargetAudience
        let configuration: ExperimentConfiguration
        
        enum ExperimentStatus: String, CaseIterable, Codable {
            case draft = "Draft"
            case running = "Running"
            case paused = "Paused"
            case completed = "Completed"
            case stopped = "Stopped"
        }
    }
    
    struct ExperimentModel: Codable {
        let name: String
        let version: String
        let modelPath: String
        let description: String
        let expectedImprovement: String
        let riskLevel: RiskLevel
        
        enum RiskLevel: String, CaseIterable, Codable {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
        }
    }
    
    struct TrafficSplit: Codable {
        let controlPercentage: Double
        let treatmentPercentage: Double
        let method: SplitMethod
        
        enum SplitMethod: String, CaseIterable, Codable {
            case random = "Random"
            case userId = "User ID Hash"
            case deviceId = "Device ID Hash"
            case geographic = "Geographic"
        }
        
        var isValid: Bool {
            return abs(controlPercentage + treatmentPercentage - 100.0) < 0.01
        }
    }
    
    struct SuccessMetric: Identifiable, Codable {
        let id = UUID()
        let name: String
        let type: MetricType
        let target: Double
        let direction: ImprovementDirection
        let weight: Double
        
        enum MetricType: String, CaseIterable, Codable {
            case accuracy = "Accuracy"
            case latency = "Latency"
            case memoryUsage = "Memory Usage"
            case userSatisfaction = "User Satisfaction"
            case errorRate = "Error Rate"
            case confidenceScore = "Confidence Score"
            case taskCompletion = "Task Completion"
            case engagementRate = "Engagement Rate"
        }
        
        enum ImprovementDirection: String, CaseIterable, Codable {
            case increase = "Increase"
            case decrease = "Decrease"
        }
    }
    
    struct TargetAudience: Codable {
        let deviceTypes: [String]
        let iOSVersions: [String]
        let userSegments: [String]
        let geographicRegions: [String]
        let includeNewUsers: Bool
        let includeExistingUsers: Bool
    }
    
    struct ExperimentConfiguration: Codable {
        let maxDuration: TimeInterval
        let minSampleSize: Int
        let significanceThreshold: Double
        let earlyStoppingEnabled: Bool
        let rollbackThreshold: Double
        let monitoringInterval: TimeInterval
        let dataRetentionDays: Int
    }
    
    struct ExperimentResult: Identifiable, Codable {
        let id = UUID()
        let experimentId: UUID
        let experimentName: String
        let completionDate: Date
        let duration: TimeInterval
        let statistics: ExperimentStatistics
        let conclusion: ExperimentConclusion
        let recommendations: [String]
        let rawData: ExperimentData
    }
    
    struct ExperimentStatistics: Codable {
        let controlMetrics: ModelMetrics
        let treatmentMetrics: ModelMetrics
        let statisticalTests: [StatisticalTest]
        let effectSizes: [EffectSize]
        let confidenceIntervals: [ConfidenceInterval]
        let sampleSizes: SampleSizes
    }
    
    struct ModelMetrics: Codable {
        let accuracy: Double
        let averageLatency: TimeInterval
        let memoryUsage: Double
        let errorRate: Double
        let userSatisfaction: Double
        let taskCompletionRate: Double
        let confidenceScore: Double
    }
    
    struct StatisticalTest: Codable {
        let metric: String
        let testType: String
        let pValue: Double
        let isSignificant: Bool
        let effectSize: Double
        let powerAnalysis: Double
    }
    
    struct EffectSize: Codable {
        let metric: String
        let cohensD: Double
        let interpretation: String
        let practicalSignificance: Bool
    }
    
    struct ConfidenceInterval: Codable {
        let metric: String
        let lowerBound: Double
        let upperBound: Double
        let confidenceLevel: Double
        let includesZero: Bool
    }
    
    struct SampleSizes: Codable {
        let control: Int
        let treatment: Int
        let total: Int
        let adequatePower: Bool
    }
    
    struct ExperimentConclusion: Codable {
        let winner: String
        let confidence: Double
        let summary: String
        let businessImpact: String
        let recommendation: Recommendation
        let riskAssessment: String
        
        enum Recommendation: String, CaseIterable, Codable {
            case deployTreatment = "Deploy Treatment"
            case keepControl = "Keep Control"
            case runLonger = "Run Longer"
            case redesignExperiment = "Redesign Experiment"
            case inconclusive = "Inconclusive"
        }
    }
    
    struct ExperimentData: Codable {
        let controlSamples: [DataPoint]
        let treatmentSamples: [DataPoint]
        let metadata: ExperimentMetadata
    }
    
    struct DataPoint: Codable {
        let timestamp: Date
        let userId: String
        let metrics: [String: Double]
        let modelVersion: String
        let deviceInfo: DeviceInfo
    }
    
    struct DeviceInfo: Codable {
        let model: String
        let osVersion: String
        let region: String
        let networkType: String
    }
    
    struct ExperimentMetadata: Codable {
        let totalRequests: Int
        let successfulRequests: Int
        let failedRequests: Int
        let averageSessionLength: TimeInterval
        let uniqueUsers: Int
    }
    
    struct ExperimentStats: Codable {
        let experimentId: UUID
        let elapsedTime: TimeInterval
        let samplesCollected: Int
        let currentWinner: String
        let confidence: Double
        let projectedCompletion: Date?
        let earlyStoppingRecommendation: String?
    }
    
    // MARK: - Public Methods
    
    /// Create a new A/B test experiment
    func createExperiment(
        name: String,
        description: String,
        hypothesis: String,
        modelA: ExperimentModel,
        modelB: ExperimentModel,
        trafficSplit: TrafficSplit,
        successMetrics: [SuccessMetric],
        targetAudience: TargetAudience,
        configuration: ExperimentConfiguration
    ) async -> Result<Experiment, ExperimentError> {
        
        // Validate experiment setup
        let validationResult = await validateExperimentSetup(
            modelA: modelA,
            modelB: modelB,
            trafficSplit: trafficSplit,
            successMetrics: successMetrics,
            configuration: configuration
        )
        
        if case .failure(let error) = validationResult {
            return .failure(error)
        }
        
        let experiment = Experiment(
            name: name,
            description: description,
            hypothesis: hypothesis,
            modelA: modelA,
            modelB: modelB,
            startDate: Date(),
            endDate: nil,
            status: .draft,
            trafficSplit: trafficSplit,
            successMetrics: successMetrics,
            targetAudience: targetAudience,
            configuration: configuration
        )
        
        await MainActor.run {
            activeExperiments.append(experiment)
        }
        
        // Save experiment to persistent storage
        saveExperiments()
        
        return .success(experiment)
    }
    
    /// Start running an experiment
    func startExperiment(_ experimentId: UUID) async -> Result<Void, ExperimentError> {
        guard let index = activeExperiments.firstIndex(where: { $0.id == experimentId }) else {
            return .failure(.experimentNotFound)
        }
        
        let experiment = activeExperiments[index]
        
        // Pre-flight validation
        let preflightResult = await performPreflightChecks(experiment: experiment)
        if case .failure(let error) = preflightResult {
            return .failure(error)
        }
        
        // Update experiment status
        await MainActor.run {
            activeExperiments[index] = Experiment(
                name: experiment.name,
                description: experiment.description,
                hypothesis: experiment.hypothesis,
                modelA: experiment.modelA,
                modelB: experiment.modelB,
                startDate: Date(),
                endDate: experiment.endDate,
                status: .running,
                trafficSplit: experiment.trafficSplit,
                successMetrics: experiment.successMetrics,
                targetAudience: experiment.targetAudience,
                configuration: experiment.configuration
            )
            isRunningExperiment = true
        }
        
        // Start monitoring
        startExperimentMonitoring(experimentId: experimentId)
        
        saveExperiments()
        return .success(())
    }
    
    /// Stop an experiment and analyze results
    func stopExperiment(_ experimentId: UUID, reason: String) async -> Result<ExperimentResult, ExperimentError> {
        guard let experimentIndex = activeExperiments.firstIndex(where: { $0.id == experimentId }) else {
            return .failure(.experimentNotFound)
        }
        
        let experiment = activeExperiments[experimentIndex]
        
        // Collect and analyze data
        let experimentData = await collectExperimentData(experiment: experiment)
        let statistics = await analyzeExperimentData(data: experimentData, experiment: experiment)
        let conclusion = await generateExperimentConclusion(statistics: statistics, experiment: experiment)
        
        let result = ExperimentResult(
            experimentId: experimentId,
            experimentName: experiment.name,
            completionDate: Date(),
            duration: Date().timeIntervalSince(experiment.startDate),
            statistics: statistics,
            conclusion: conclusion,
            recommendations: generateRecommendations(conclusion: conclusion, statistics: statistics),
            rawData: experimentData
        )
        
        // Update experiment status
        await MainActor.run {
            activeExperiments[experimentIndex] = Experiment(
                name: experiment.name,
                description: experiment.description,
                hypothesis: experiment.hypothesis,
                modelA: experiment.modelA,
                modelB: experiment.modelB,
                startDate: experiment.startDate,
                endDate: Date(),
                status: .completed,
                trafficSplit: experiment.trafficSplit,
                successMetrics: experiment.successMetrics,
                targetAudience: experiment.targetAudience,
                configuration: experiment.configuration
            )
            experimentResults.append(result)
            isRunningExperiment = false
        }
        
        saveExperiments()
        saveExperimentResults()
        
        return .success(result)
    }
    
    /// Get real-time experiment statistics
    func getExperimentStats(_ experimentId: UUID) async -> ExperimentStats? {
        guard let experiment = activeExperiments.first(where: { $0.id == experimentId }),
              experiment.status == .running else {
            return nil
        }
        
        let experimentData = await collectExperimentData(experiment: experiment)
        let elapsedTime = Date().timeIntervalSince(experiment.startDate)
        let samplesCollected = experimentData.controlSamples.count + experimentData.treatmentSamples.count
        
        // Perform interim analysis
        let interimAnalysis = await performInterimAnalysis(data: experimentData, experiment: experiment)
        
        let stats = ExperimentStats(
            experimentId: experimentId,
            elapsedTime: elapsedTime,
            samplesCollected: samplesCollected,
            currentWinner: interimAnalysis.currentWinner,
            confidence: interimAnalysis.confidence,
            projectedCompletion: calculateProjectedCompletion(experiment: experiment, samplesCollected: samplesCollected),
            earlyStoppingRecommendation: interimAnalysis.earlyStoppingRecommendation
        )
        
        await MainActor.run {
            currentExperimentStats = stats
        }
        
        return stats
    }
    
    /// Determine which model variant a user should see
    func getModelVariant(for experiment: Experiment, userId: String, deviceId: String) -> String {
        let hashInput: String
        
        switch experiment.trafficSplit.method {
        case .random:
            hashInput = UUID().uuidString
        case .userId:
            hashInput = userId
        case .deviceId:
            hashInput = deviceId
        case .geographic:
            // In real implementation, would use actual geographic info
            hashInput = deviceId
        }
        
        let hash = SHA256.hash(data: Data(hashInput.utf8))
        let hashValue = hash.compactMap { String(format: "%02x", $0) }.joined()
        let numericHash = UInt64(hashValue.prefix(16), radix: 16) ?? 0
        let percentage = Double(numericHash % 100)
        
        return percentage < experiment.trafficSplit.controlPercentage ? "control" : "treatment"
    }
    
    /// Record experiment event
    func recordExperimentEvent(
        experimentId: UUID,
        userId: String,
        modelVariant: String,
        metrics: [String: Double],
        deviceInfo: DeviceInfo
    ) {
        let dataPoint = DataPoint(
            timestamp: Date(),
            userId: userId,
            metrics: metrics,
            modelVersion: modelVariant,
            deviceInfo: deviceInfo
        )
        
        // In real implementation, this would be stored in a database
        // For now, we'll store in UserDefaults with a key based on experiment ID
        let key = "experiment_data_\(experimentId.uuidString)"
        var existingData = userDefaults.data(forKey: key) ?? Data()
        
        do {
            var dataPoints: [DataPoint] = []
            
            if !existingData.isEmpty {
                dataPoints = try JSONDecoder().decode([DataPoint].self, from: existingData)
            }
            
            dataPoints.append(dataPoint)
            
            // Keep only recent data to prevent storage bloat
            let cutoffDate = Date().addingTimeInterval(-maxExperimentDuration)
            dataPoints = dataPoints.filter { $0.timestamp > cutoffDate }
            
            let encodedData = try JSONEncoder().encode(dataPoints)
            userDefaults.set(encodedData, forKey: key)
            
        } catch {
            print("Failed to save experiment data: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func validateExperimentSetup(
        modelA: ExperimentModel,
        modelB: ExperimentModel,
        trafficSplit: TrafficSplit,
        successMetrics: [SuccessMetric],
        configuration: ExperimentConfiguration
    ) async -> Result<Void, ExperimentError> {
        
        // Validate traffic split
        if !trafficSplit.isValid {
            return .failure(.invalidTrafficSplit("Traffic split percentages must sum to 100%"))
        }
        
        // Validate models exist and are functional
        let modelAValidation = await modelValidator.quickValidation(modelPath: modelA.modelPath, modelName: modelA.name)
        if modelAValidation.status == .critical {
            return .failure(.invalidModel("Model A validation failed: \(modelAValidation.issues.first?.description ?? "Unknown error")"))
        }
        
        let modelBValidation = await modelValidator.quickValidation(modelPath: modelB.modelPath, modelName: modelB.name)
        if modelBValidation.status == .critical {
            return .failure(.invalidModel("Model B validation failed: \(modelBValidation.issues.first?.description ?? "Unknown error")"))
        }
        
        // Validate success metrics
        if successMetrics.isEmpty {
            return .failure(.invalidConfiguration("At least one success metric must be defined"))
        }
        
        let totalWeight = successMetrics.reduce(0) { $0 + $1.weight }
        if abs(totalWeight - 1.0) > 0.01 {
            return .failure(.invalidConfiguration("Metric weights must sum to 1.0"))
        }
        
        // Validate configuration
        if configuration.minSampleSize < 50 {
            return .failure(.invalidConfiguration("Minimum sample size must be at least 50"))
        }
        
        if configuration.significanceThreshold < 0.01 || configuration.significanceThreshold > 0.1 {
            return .failure(.invalidConfiguration("Significance threshold must be between 0.01 and 0.1"))
        }
        
        return .success(())
    }
    
    private func performPreflightChecks(experiment: Experiment) async -> Result<Void, ExperimentError> {
        // Check if there's already a running experiment
        let runningExperiments = activeExperiments.filter { $0.status == .running }
        if !runningExperiments.isEmpty {
            return .failure(.experimentAlreadyRunning)
        }
        
        // Validate models are still accessible
        if !FileManager.default.fileExists(atPath: experiment.modelA.modelPath) {
            return .failure(.modelNotFound("Model A not found at path: \(experiment.modelA.modelPath)"))
        }
        
        if !FileManager.default.fileExists(atPath: experiment.modelB.modelPath) {
            return .failure(.modelNotFound("Model B not found at path: \(experiment.modelB.modelPath)"))
        }
        
        // Check system resources
        let availableMemory = getAvailableMemory()
        if availableMemory < 100 * 1024 * 1024 { // 100MB
            return .failure(.insufficientResources("Insufficient memory to run experiment"))
        }
        
        return .success(())
    }
    
    private func startExperimentMonitoring(experimentId: UUID) {
        // Start periodic monitoring
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] timer in
            Task {
                await self?.performMonitoringCheck(experimentId: experimentId)
            }
        }
    }
    
    private func performMonitoringCheck(experimentId: UUID) async {
        guard let experiment = activeExperiments.first(where: { $0.id == experimentId }),
              experiment.status == .running else {
            return
        }
        
        let stats = await getExperimentStats(experimentId)
        
        // Check for early stopping conditions
        if let stats = stats,
           experiment.configuration.earlyStoppingEnabled,
           let recommendation = stats.earlyStoppingRecommendation,
           recommendation == "Stop experiment - significant result detected" {
            
            // Auto-stop experiment if configured
            _ = await stopExperiment(experimentId, reason: "Early stopping - significant result")
        }
        
        // Check for maximum duration
        let elapsedTime = Date().timeIntervalSince(experiment.startDate)
        if elapsedTime > experiment.configuration.maxDuration {
            _ = await stopExperiment(experimentId, reason: "Maximum duration reached")
        }
    }
    
    private func collectExperimentData(experiment: Experiment) async -> ExperimentData {
        let key = "experiment_data_\(experiment.id.uuidString)"
        let data = userDefaults.data(forKey: key) ?? Data()
        
        do {
            if !data.isEmpty {
                let allDataPoints = try JSONDecoder().decode([DataPoint].self, from: data)
                
                let controlSamples = allDataPoints.filter { $0.modelVersion == "control" }
                let treatmentSamples = allDataPoints.filter { $0.modelVersion == "treatment" }
                
                let metadata = ExperimentMetadata(
                    totalRequests: allDataPoints.count,
                    successfulRequests: allDataPoints.count, // Simplified
                    failedRequests: 0,
                    averageSessionLength: 0,
                    uniqueUsers: Set(allDataPoints.map { $0.userId }).count
                )
                
                return ExperimentData(
                    controlSamples: controlSamples,
                    treatmentSamples: treatmentSamples,
                    metadata: metadata
                )
            }
        } catch {
            print("Failed to load experiment data: \(error)")
        }
        
        // Return empty data if loading fails
        return ExperimentData(
            controlSamples: [],
            treatmentSamples: [],
            metadata: ExperimentMetadata(
                totalRequests: 0,
                successfulRequests: 0,
                failedRequests: 0,
                averageSessionLength: 0,
                uniqueUsers: 0
            )
        )
    }
    
    private func analyzeExperimentData(data: ExperimentData, experiment: Experiment) async -> ExperimentStatistics {
        let controlMetrics = calculateModelMetrics(samples: data.controlSamples)
        let treatmentMetrics = calculateModelMetrics(samples: data.treatmentSamples)
        
        var statisticalTests: [StatisticalTest] = []
        var effectSizes: [EffectSize] = []
        var confidenceIntervals: [ConfidenceInterval] = []
        
        // Perform statistical tests for each success metric
        for metric in experiment.successMetrics {
            let controlValues = extractMetricValues(samples: data.controlSamples, metric: metric.name)
            let treatmentValues = extractMetricValues(samples: data.treatmentSamples, metric: metric.name)
            
            if controlValues.count >= 30 && treatmentValues.count >= 30 {
                // Perform t-test
                let tTestResult = performTTest(control: controlValues, treatment: treatmentValues)
                statisticalTests.append(tTestResult)
                
                // Calculate effect size
                let effectSize = calculateEffectSize(control: controlValues, treatment: treatmentValues, metric: metric.name)
                effectSizes.append(effectSize)
                
                // Calculate confidence interval
                let ci = calculateConfidenceInterval(control: controlValues, treatment: treatmentValues, metric: metric.name)
                confidenceIntervals.append(ci)
            }
        }
        
        let sampleSizes = SampleSizes(
            control: data.controlSamples.count,
            treatment: data.treatmentSamples.count,
            total: data.controlSamples.count + data.treatmentSamples.count,
            adequatePower: data.controlSamples.count >= minimumSampleSize && data.treatmentSamples.count >= minimumSampleSize
        )
        
        return ExperimentStatistics(
            controlMetrics: controlMetrics,
            treatmentMetrics: treatmentMetrics,
            statisticalTests: statisticalTests,
            effectSizes: effectSizes,
            confidenceIntervals: confidenceIntervals,
            sampleSizes: sampleSizes
        )
    }
    
    private func calculateModelMetrics(samples: [DataPoint]) -> ModelMetrics {
        guard !samples.isEmpty else {
            return ModelMetrics(
                accuracy: 0,
                averageLatency: 0,
                memoryUsage: 0,
                errorRate: 0,
                userSatisfaction: 0,
                taskCompletionRate: 0,
                confidenceScore: 0
            )
        }
        
        let accuracy = samples.compactMap { $0.metrics["accuracy"] }.reduce(0, +) / Double(samples.count)
        let latency = samples.compactMap { $0.metrics["latency"] }.reduce(0, +) / Double(samples.count)
        let memory = samples.compactMap { $0.metrics["memoryUsage"] }.reduce(0, +) / Double(samples.count)
        let errorRate = samples.compactMap { $0.metrics["errorRate"] }.reduce(0, +) / Double(samples.count)
        let satisfaction = samples.compactMap { $0.metrics["userSatisfaction"] }.reduce(0, +) / Double(samples.count)
        let completion = samples.compactMap { $0.metrics["taskCompletion"] }.reduce(0, +) / Double(samples.count)
        let confidence = samples.compactMap { $0.metrics["confidence"] }.reduce(0, +) / Double(samples.count)
        
        return ModelMetrics(
            accuracy: accuracy,
            averageLatency: latency,
            memoryUsage: memory,
            errorRate: errorRate,
            userSatisfaction: satisfaction,
            taskCompletionRate: completion,
            confidenceScore: confidence
        )
    }
    
    private func extractMetricValues(samples: [DataPoint], metric: String) -> [Double] {
        return samples.compactMap { $0.metrics[metric] }
    }
    
    private func performTTest(control: [Double], treatment: [Double]) -> StatisticalTest {
        // Simplified t-test implementation
        let controlMean = control.reduce(0, +) / Double(control.count)
        let treatmentMean = treatment.reduce(0, +) / Double(treatment.count)
        
        let controlVariance = control.map { pow($0 - controlMean, 2) }.reduce(0, +) / Double(control.count - 1)
        let treatmentVariance = treatment.map { pow($0 - treatmentMean, 2) }.reduce(0, +) / Double(treatment.count - 1)
        
        let pooledStdError = sqrt(controlVariance / Double(control.count) + treatmentVariance / Double(treatment.count))
        let tStatistic = (treatmentMean - controlMean) / pooledStdError
        
        // Simplified p-value calculation (in reality, you'd use proper statistical libraries)
        let pValue = 2 * (1 - normalCDF(abs(tStatistic)))
        
        let effectSize = (treatmentMean - controlMean) / sqrt((controlVariance + treatmentVariance) / 2)
        
        return StatisticalTest(
            metric: "primary",
            testType: "t-test",
            pValue: pValue,
            isSignificant: pValue < significanceLevel,
            effectSize: effectSize,
            powerAnalysis: calculatePower(effectSize: effectSize, sampleSize: min(control.count, treatment.count))
        )
    }
    
    private func calculateEffectSize(control: [Double], treatment: [Double], metric: String) -> EffectSize {
        let controlMean = control.reduce(0, +) / Double(control.count)
        let treatmentMean = treatment.reduce(0, +) / Double(treatment.count)
        
        let controlStd = sqrt(control.map { pow($0 - controlMean, 2) }.reduce(0, +) / Double(control.count - 1))
        let treatmentStd = sqrt(treatment.map { pow($0 - treatmentMean, 2) }.reduce(0, +) / Double(treatment.count - 1))
        
        let pooledStd = sqrt((controlStd * controlStd + treatmentStd * treatmentStd) / 2)
        let cohensD = (treatmentMean - controlMean) / pooledStd
        
        let interpretation: String
        let practicalSignificance: Bool
        
        if abs(cohensD) < 0.2 {
            interpretation = "Small effect"
            practicalSignificance = false
        } else if abs(cohensD) < 0.5 {
            interpretation = "Medium effect"
            practicalSignificance = true
        } else {
            interpretation = "Large effect"
            practicalSignificance = true
        }
        
        return EffectSize(
            metric: metric,
            cohensD: cohensD,
            interpretation: interpretation,
            practicalSignificance: practicalSignificance
        )
    }
    
    private func calculateConfidenceInterval(control: [Double], treatment: [Double], metric: String) -> ConfidenceInterval {
        let controlMean = control.reduce(0, +) / Double(control.count)
        let treatmentMean = treatment.reduce(0, +) / Double(treatment.count)
        let difference = treatmentMean - controlMean
        
        let controlVariance = control.map { pow($0 - controlMean, 2) }.reduce(0, +) / Double(control.count - 1)
        let treatmentVariance = treatment.map { pow($0 - treatmentMean, 2) }.reduce(0, +) / Double(treatment.count - 1)
        
        let standardError = sqrt(controlVariance / Double(control.count) + treatmentVariance / Double(treatment.count))
        let marginOfError = 1.96 * standardError // 95% confidence interval
        
        let lowerBound = difference - marginOfError
        let upperBound = difference + marginOfError
        
        return ConfidenceInterval(
            metric: metric,
            lowerBound: lowerBound,
            upperBound: upperBound,
            confidenceLevel: 0.95,
            includesZero: lowerBound <= 0 && upperBound >= 0
        )
    }
    
    private func generateExperimentConclusion(statistics: ExperimentStatistics, experiment: Experiment) async -> ExperimentConclusion {
        let significantTests = statistics.statisticalTests.filter { $0.isSignificant }
        let hasSignificantResult = !significantTests.isEmpty
        
        let winner: String
        let confidence: Double
        let recommendation: ExperimentConclusion.Recommendation
        
        if hasSignificantResult {
            // Determine winner based on primary success metric
            let primaryMetric = experiment.successMetrics.first!
            let controlValue = getMetricValue(from: statistics.controlMetrics, metric: primaryMetric.name)
            let treatmentValue = getMetricValue(from: statistics.treatmentMetrics, metric: primaryMetric.name)
            
            if primaryMetric.direction == .increase {
                winner = treatmentValue > controlValue ? "Treatment" : "Control"
            } else {
                winner = treatmentValue < controlValue ? "Treatment" : "Control"
            }
            
            confidence = 1 - (significantTests.first?.pValue ?? 0.05)
            recommendation = winner == "Treatment" ? .deployTreatment : .keepControl
        } else {
            winner = "Inconclusive"
            confidence = 0.5
            
            if statistics.sampleSizes.total < minimumSampleSize * 2 {
                recommendation = .runLonger
            } else {
                recommendation = .inconclusive
            }
        }
        
        let summary = generateSummary(statistics: statistics, winner: winner, hasSignificantResult: hasSignificantResult)
        let businessImpact = generateBusinessImpact(statistics: statistics, experiment: experiment)
        let riskAssessment = generateRiskAssessment(statistics: statistics, experiment: experiment)
        
        return ExperimentConclusion(
            winner: winner,
            confidence: confidence,
            summary: summary,
            businessImpact: businessImpact,
            recommendation: recommendation,
            riskAssessment: riskAssessment
        )
    }
    
    private func generateSummary(statistics: ExperimentStatistics, winner: String, hasSignificantResult: Bool) -> String {
        if hasSignificantResult {
            return "Experiment shows statistically significant results with \(winner) as the winner. Sample sizes: Control (\(statistics.sampleSizes.control)), Treatment (\(statistics.sampleSizes.treatment))."
        } else {
            return "Experiment did not show statistically significant differences between variants. Sample sizes: Control (\(statistics.sampleSizes.control)), Treatment (\(statistics.sampleSizes.treatment))."
        }
    }
    
    private func generateBusinessImpact(statistics: ExperimentStatistics, experiment: Experiment) -> String {
        let primaryMetric = experiment.successMetrics.first!
        let controlValue = getMetricValue(from: statistics.controlMetrics, metric: primaryMetric.name)
        let treatmentValue = getMetricValue(from: statistics.treatmentMetrics, metric: primaryMetric.name)
        let improvement = ((treatmentValue - controlValue) / controlValue) * 100
        
        if abs(improvement) < 1 {
            return "Minimal business impact expected (< 1% change)"
        } else if abs(improvement) < 5 {
            return "Low business impact expected (\(String(format: "%.1f", improvement))% change)"
        } else if abs(improvement) < 15 {
            return "Moderate business impact expected (\(String(format: "%.1f", improvement))% change)"
        } else {
            return "High business impact expected (\(String(format: "%.1f", improvement))% change)"
        }
    }
    
    private func generateRiskAssessment(statistics: ExperimentStatistics, experiment: Experiment) -> String {
        let errorRateDifference = statistics.treatmentMetrics.errorRate - statistics.controlMetrics.errorRate
        let latencyDifference = statistics.treatmentMetrics.averageLatency - statistics.controlMetrics.averageLatency
        
        var risks: [String] = []
        
        if errorRateDifference > 0.01 {
            risks.append("Increased error rate")
        }
        
        if latencyDifference > 0.1 {
            risks.append("Increased latency")
        }
        
        if statistics.treatmentMetrics.memoryUsage > statistics.controlMetrics.memoryUsage * 1.2 {
            risks.append("Increased memory usage")
        }
        
        if risks.isEmpty {
            return "Low risk - no significant performance degradation detected"
        } else {
            return "Medium risk - potential issues: \(risks.joined(separator: ", "))"
        }
    }
    
    private func generateRecommendations(conclusion: ExperimentConclusion, statistics: ExperimentStatistics) -> [String] {
        var recommendations: [String] = []
        
        switch conclusion.recommendation {
        case .deployTreatment:
            recommendations.append("Deploy treatment model to production")
            recommendations.append("Monitor key metrics closely during rollout")
            recommendations.append("Prepare rollback plan in case of issues")
            
        case .keepControl:
            recommendations.append("Keep current control model")
            recommendations.append("Investigate why treatment didn't perform better")
            recommendations.append("Consider redesigning the treatment approach")
            
        case .runLonger:
            recommendations.append("Continue experiment to gather more data")
            recommendations.append("Target sample size: \(minimumSampleSize * 2) per variant")
            recommendations.append("Review interim results weekly")
            
        case .redesignExperiment:
            recommendations.append("Redesign experiment with different approach")
            recommendations.append("Consider different success metrics")
            recommendations.append("Analyze user feedback for insights")
            
        case .inconclusive:
            recommendations.append("Results are inconclusive")
            recommendations.append("Consider practical significance over statistical significance")
            recommendations.append("Gather qualitative feedback from users")
        }
        
        if !statistics.sampleSizes.adequatePower {
            recommendations.append("Increase sample size for better statistical power")
        }
        
        return recommendations
    }
    
    private func performInterimAnalysis(data: ExperimentData, experiment: Experiment) async -> (currentWinner: String, confidence: Double, earlyStoppingRecommendation: String?) {
        
        let statistics = await analyzeExperimentData(data: data, experiment: experiment)
        let significantTests = statistics.statisticalTests.filter { $0.isSignificant }
        
        let currentWinner: String
        let confidence: Double
        var earlyStoppingRecommendation: String?
        
        if !significantTests.isEmpty {
            let primaryMetric = experiment.successMetrics.first!
            let controlValue = getMetricValue(from: statistics.controlMetrics, metric: primaryMetric.name)
            let treatmentValue = getMetricValue(from: statistics.treatmentMetrics, metric: primaryMetric.name)
            
            if primaryMetric.direction == .increase {
                currentWinner = treatmentValue > controlValue ? "Treatment" : "Control"
            } else {
                currentWinner = treatmentValue < controlValue ? "Treatment" : "Control"
            }
            
            confidence = 1 - (significantTests.first?.pValue ?? 0.05)
            
            // Check for early stopping
            if confidence > 0.99 && statistics.sampleSizes.total > minimumSampleSize {
                earlyStoppingRecommendation = "Stop experiment - significant result detected"
            }
        } else {
            currentWinner = "Too early to determine"
            confidence = 0.5
        }
        
        return (currentWinner, confidence, earlyStoppingRecommendation)
    }
    
    private func calculateProjectedCompletion(experiment: Experiment, samplesCollected: Int) -> Date? {
        let targetSamples = experiment.configuration.minSampleSize * 2
        
        if samplesCollected >= targetSamples {
            return Date()
        }
        
        let elapsedTime = Date().timeIntervalSince(experiment.startDate)
        let samplesPerSecond = Double(samplesCollected) / elapsedTime
        
        if samplesPerSecond <= 0 {
            return nil
        }
        
        let remainingSamples = targetSamples - samplesCollected
        let remainingTime = Double(remainingSamples) / samplesPerSecond
        
        return Date().addingTimeInterval(remainingTime)
    }
    
    private func getMetricValue(from metrics: ModelMetrics, metric: String) -> Double {
        switch metric.lowercased() {
        case "accuracy":
            return metrics.accuracy
        case "latency":
            return metrics.averageLatency
        case "memoryusage":
            return metrics.memoryUsage
        case "errorrate":
            return metrics.errorRate
        case "usersatisfaction":
            return metrics.userSatisfaction
        case "taskcompletion":
            return metrics.taskCompletionRate
        case "confidence":
            return metrics.confidenceScore
        default:
            return 0.0
        }
    }
    
    // MARK: - Statistical Helper Functions
    
    private func normalCDF(_ x: Double) -> Double {
        // Simplified normal CDF approximation
        return 0.5 * (1 + erf(x / sqrt(2)))
    }
    
    private func erf(_ x: Double) -> Double {
        // Approximation of error function
        let a1 =  0.254829592
        let a2 = -0.284496736
        let a3 =  1.421413741
        let a4 = -1.453152027
        let a5 =  1.061405429
        let p  =  0.3275911
        
        let sign = x < 0 ? -1.0 : 1.0
        let x = abs(x)
        
        let t = 1.0 / (1.0 + p * x)
        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-x * x)
        
        return sign * y
    }
    
    private func calculatePower(effectSize: Double, sampleSize: Int) -> Double {
        // Simplified power calculation
        let ncp = effectSize * sqrt(Double(sampleSize) / 2)
        return 1 - normalCDF(1.96 - ncp)
    }
    
    private func getAvailableMemory() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            // Return available memory estimate
            return Int64(1024 * 1024 * 1024) - Int64(info.resident_size) // 1GB - current usage
        } else {
            return Int64(512 * 1024 * 1024) // Default 512MB estimate
        }
    }
    
    // MARK: - Persistence
    
    private func saveExperiments() {
        do {
            let data = try JSONEncoder().encode(activeExperiments)
            userDefaults.set(data, forKey: "active_experiments")
        } catch {
            print("Failed to save experiments: \(error)")
        }
    }
    
    private func saveExperimentResults() {
        do {
            let data = try JSONEncoder().encode(experimentResults)
            userDefaults.set(data, forKey: "experiment_results")
        } catch {
            print("Failed to save experiment results: \(error)")
        }
    }
    
    private func loadExperiments() {
        guard let data = userDefaults.data(forKey: "active_experiments") else { return }
        
        do {
            activeExperiments = try JSONDecoder().decode([Experiment].self, from: data)
        } catch {
            print("Failed to load experiments: \(error)")
        }
    }
    
    private func loadExperimentResults() {
        guard let data = userDefaults.data(forKey: "experiment_results") else { return }
        
        do {
            experimentResults = try JSONDecoder().decode([ExperimentResult].self, from: data)
        } catch {
            print("Failed to load experiment results: \(error)")
        }
    }
    
    // MARK: - Initialization
    
    init() {
        loadExperiments()
        loadExperimentResults()
    }
}

// MARK: - Error Types

enum ExperimentError: LocalizedError {
    case experimentNotFound
    case experimentAlreadyRunning
    case invalidTrafficSplit(String)
    case invalidModel(String)
    case invalidConfiguration(String)
    case modelNotFound(String)
    case insufficientResources(String)
    case dataCollectionFailed(String)
    case analysisError(String)
    
    var errorDescription: String? {
        switch self {
        case .experimentNotFound:
            return "Experiment not found"
        case .experimentAlreadyRunning:
            return "Another experiment is already running"
        case .invalidTrafficSplit(let message):
            return "Invalid traffic split: \(message)"
        case .invalidModel(let message):
            return "Invalid model: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .modelNotFound(let message):
            return "Model not found: \(message)"
        case .insufficientResources(let message):
            return "Insufficient resources: \(message)"
        case .dataCollectionFailed(let message):
            return "Data collection failed: \(message)"
        case .analysisError(let message):
            return "Analysis error: \(message)"
        }
    }
}

// MARK: - Extensions

extension ABTestingManager.Experiment.ExperimentStatus {
    var emoji: String {
        switch self {
        case .draft: return "📝"
        case .running: return "🏃‍♂️"
        case .paused: return "⏸️"
        case .completed: return "✅"
        case .stopped: return "🛑"
        }
    }
}

extension ABTestingManager.ExperimentModel.RiskLevel {
    var emoji: String {
        switch self {
        case .low: return "🟢"
        case .medium: return "🟡"
        case .high: return "🔴"
        }
    }
}

extension ABTestingManager.ExperimentConclusion.Recommendation {
    var emoji: String {
        switch self {
        case .deployTreatment: return "🚀"
        case .keepControl: return "🔄"
        case .runLonger: return "⏰"
        case .redesignExperiment: return "🔄"
        case .inconclusive: return "🤷‍♂️"
        }
    }
}