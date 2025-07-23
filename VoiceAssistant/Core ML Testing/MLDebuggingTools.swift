import Foundation
import CoreML
import SwiftUI
import Combine

/// Comprehensive debugging tools for Core ML models
/// Includes prediction inspector, performance profiler, decision tree visualizer, and confidence score analyzer
@available(iOS 15.0, *)
final class MLDebuggingTools: ObservableObject {
    
    // MARK: - Properties
    
    @Published var currentInspection: ModelInspection?
    @Published var performanceProfile: PerformanceProfile?
    @Published var decisionTree: DecisionTreeVisualization?
    @Published var confidenceAnalysis: ConfidenceAnalysis?
    @Published var isDebugging = false
    @Published var debugLogs: [DebugLog] = []
    
    @MainActor private lazy var intentClassifier = IntentClassifier()
    @MainActor private lazy var coreMLManager = CoreMLManager.shared
    @MainActor private lazy var responseGenerator = ResponseGenerator()
    
    // MARK: - Data Models
    
    struct ModelInspection: Identifiable, Codable {
        let id = UUID()
        let modelName: String
        let input: String
        let prediction: PredictionDetails
        let intermediateResults: [IntermediateResult]
        let confidenceBreakdown: ConfidenceBreakdown
        let processingSteps: [ProcessingStep]
        let timestamp: Date
    }
    
    struct PredictionDetails: Codable {
        let primaryIntent: String
        let confidence: Double
        let alternativeIntents: [AlternativeIntent]
        let processingTime: TimeInterval
        let modelVersion: String
        let inputTokens: [String]
        let attentionWeights: [Double]?
        let hiddenStates: [Double]?
    }
    
    struct AlternativeIntent: Codable {
        let intent: String
        let confidence: Double
    }
    
    struct IntermediateResult: Identifiable, Codable {
        let id = UUID()
        let stepName: String
        let stepType: ProcessingStepType
        let input: String
        let output: String
        let confidence: Double?
        let metadata: [String: String]
        let processingTime: TimeInterval
    }
    
    enum ProcessingStepType: String, CaseIterable, Codable {
        case tokenization = "Tokenization"
        case preprocessing = "Preprocessing"
        case featureExtraction = "Feature Extraction"
        case modelInference = "Model Inference"
        case postprocessing = "Postprocessing"
        case confidenceCalculation = "Confidence Calculation"
    }
    
    struct ConfidenceBreakdown: Codable {
        let overallConfidence: Double
        let vocabularyConfidence: Double
        let syntaxConfidence: Double
        let semanticConfidence: Double
        let contextConfidence: Double
        let uncertaintyFactors: [UncertaintyFactor]
        let confidenceDistribution: [Double]
    }
    
    struct UncertaintyFactor: Identifiable, Codable {
        let id = UUID()
        let factor: String
        let impact: Double
        let description: String
        let severity: UncertaintySeverity
    }
    
    enum UncertaintySeverity: String, CaseIterable, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
    }
    
    struct ProcessingStep: Identifiable, Codable {
        let id = UUID()
        let name: String
        let startTime: Date
        let endTime: Date
        let duration: TimeInterval
        let memoryBefore: Int64
        let memoryAfter: Int64
        let cpuUsage: Double
        let success: Bool
        let errorMessage: String?
    }
    
    struct PerformanceProfile: Identifiable, Codable {
        let id = UUID()
        let modelName: String
        let profileStartTime: Date
        let profileDuration: TimeInterval
        let totalInferences: Int
        let performanceMetrics: PerformanceMetrics
        let memoryProfile: MemoryProfile
        let cpuProfile: CPUProfile
        let batteryImpact: BatteryImpact
        let thermalProfile: ThermalProfile
        let recommendations: [PerformanceRecommendation]
    }
    
    struct PerformanceMetrics: Codable {
        let averageLatency: TimeInterval
        let p50Latency: TimeInterval
        let p95Latency: TimeInterval
        let p99Latency: TimeInterval
        let minLatency: TimeInterval
        let maxLatency: TimeInterval
        let throughput: Double
        let errorRate: Double
        let timeoutRate: Double
    }
    
    struct MemoryProfile: Codable {
        let baselineMemory: Int64
        let peakMemory: Int64
        let averageMemory: Int64
        let memoryGrowthRate: Double
        let memoryLeakSuspected: Bool
        let gcPressure: Double
        let allocationHotspots: [AllocationHotspot]
    }
    
    struct AllocationHotspot: Identifiable, Codable {
        let id = UUID()
        let location: String
        let allocatedBytes: Int64
        let frequency: Int
        let impact: String
    }
    
    struct CPUProfile: Codable {
        let averageCPUUsage: Double
        let peakCPUUsage: Double
        let coreUsageDistribution: [Double]
        let neuralEngineUsage: Double?
        let gpuUsage: Double?
        let cpuHotspots: [CPUHotspot]
    }
    
    struct CPUHotspot: Identifiable, Codable {
        let id = UUID()
        let function: String
        let cpuTime: TimeInterval
        let percentage: Double
        let callCount: Int
    }
    
    struct BatteryImpact: Codable {
        let estimatedBatteryDrain: Double
        let powerEfficiencyScore: Double
        let thermalContribution: Double
        let backgroundProcessingImpact: Double
        let batteryOptimizationSuggestions: [String]
    }
    
    struct ThermalProfile: Codable {
        let thermalState: String
        let temperatureIncrease: Double
        let throttlingDetected: Bool
        let coolingRecommendations: [String]
    }
    
    struct PerformanceRecommendation: Identifiable, Codable {
        let id = UUID()
        let category: RecommendationCategory
        let priority: RecommendationPriority
        let title: String
        let description: String
        let expectedImprovement: String
        let implementationEffort: String
    }
    
    enum RecommendationCategory: String, CaseIterable, Codable {
        case modelOptimization = "Model Optimization"
        case memoryManagement = "Memory Management"
        case cpuOptimization = "CPU Optimization"
        case batteryEfficiency = "Battery Efficiency"
        case thermalManagement = "Thermal Management"
    }
    
    enum RecommendationPriority: String, CaseIterable, Codable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
    
    struct DecisionTreeVisualization: Identifiable, Codable {
        let id = UUID()
        let rootNode: DecisionNode
        let totalNodes: Int
        let maxDepth: Int
        let leafNodes: Int
        let averagePathLength: Double
        let treeComplexity: TreeComplexity
        let visualization: TreeVisualizationData
    }
    
    struct DecisionNode: Identifiable, Codable {
        let id = UUID()
        let nodeType: NodeType
        let feature: String?
        let threshold: Double?
        let decision: String?
        let confidence: Double
        let sampleCount: Int
        let impurity: Double
        let children: [DecisionNode]
        let depth: Int
        let path: [String]
    }
    
    enum NodeType: String, CaseIterable, Codable {
        case root = "Root"
        case intermediate = "Internal"
        case leaf = "Leaf"
    }
    
    enum TreeComplexity: String, CaseIterable, Codable {
        case simple = "Simple"
        case moderate = "Moderate"
        case complex = "Complex"
        case veryComplex = "Very Complex"
    }
    
    struct TreeVisualizationData: Codable {
        let nodes: [VisualizationNode]
        let edges: [VisualizationEdge]
        let layout: TreeLayout
    }
    
    struct VisualizationNode: Identifiable, Codable {
        let id = UUID()
        let nodeId: UUID
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let color: String
        let label: String
        let tooltip: String
    }
    
    struct VisualizationEdge: Identifiable, Codable {
        let id = UUID()
        let fromNodeId: UUID
        let toNodeId: UUID
        let condition: String
        let weight: Double
        let color: String
    }
    
    struct TreeLayout: Codable {
        let width: Double
        let height: Double
        let spacing: TreeSpacing
        let orientation: TreeOrientation
    }
    
    struct TreeSpacing: Codable {
        let horizontal: Double
        let vertical: Double
        let nodeMargin: Double
    }
    
    enum TreeOrientation: String, CaseIterable, Codable {
        case topDown = "Top-Down"
        case leftRight = "Left-Right"
        case radial = "Radial"
    }
    
    struct ConfidenceAnalysis: Identifiable, Codable {
        let id = UUID()
        let modelName: String
        let analysisDate: Date
        let sampleSize: Int
        let confidenceDistribution: ConfidenceDistribution
        let calibrationCurve: CalibrationCurve
        let reliabilityMetrics: ReliabilityMetrics
        let confidenceThresholds: ConfidenceThresholds
        let recommendations: [ConfidenceRecommendation]
    }
    
    struct ConfidenceDistribution: Codable {
        let bins: [ConfidenceBin]
        let mean: Double
        let median: Double
        let standardDeviation: Double
        let skewness: Double
        let kurtosis: Double
    }
    
    struct ConfidenceBin: Identifiable, Codable {
        let id = UUID()
        let range: ClosedRange<Double>
        let count: Int
        let percentage: Double
        let averageAccuracy: Double
    }
    
    struct CalibrationCurve: Codable {
        let points: [CalibrationPoint]
        let reliability: Double
        let resolution: Double
        let calibrationError: Double
        let isWellCalibrated: Bool
    }
    
    struct CalibrationPoint: Identifiable, Codable {
        let id = UUID()
        let meanPredictedProbability: Double
        let fractionOfPositives: Double
        let sampleCount: Int
    }
    
    struct ReliabilityMetrics: Codable {
        let brierScore: Double
        let logLoss: Double
        let expectedCalibrationError: Double
        let maximumCalibrationError: Double
        let reliabilityIndex: Double
    }
    
    struct ConfidenceThresholds: Codable {
        let optimalThreshold: Double
        let highPrecisionThreshold: Double
        let highRecallThreshold: Double
        let balancedThreshold: Double
        let customThresholds: [CustomThreshold]
    }
    
    struct CustomThreshold: Identifiable, Codable {
        let id = UUID()
        let name: String
        let threshold: Double
        let precision: Double
        let recall: Double
        let f1Score: Double
        let useCase: String
    }
    
    struct ConfidenceRecommendation: Identifiable, Codable {
        let id = UUID()
        let type: ConfidenceRecommendationType
        let priority: RecommendationPriority
        let title: String
        let description: String
        let suggestedThreshold: Double?
        let expectedImprovement: String
    }
    
    enum ConfidenceRecommendationType: String, CaseIterable, Codable {
        case thresholdAdjustment = "Threshold Adjustment"
        case calibrationImprovement = "Calibration Improvement"
        case uncertaintyQuantification = "Uncertainty Quantification"
        case ensembleMethod = "Ensemble Method"
        case dataAugmentation = "Data Augmentation"
    }
    
    struct DebugLog: Identifiable, Codable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let category: LogCategory
        let message: String
        let context: [String: String]
        let stackTrace: String?
    }
    
    enum LogLevel: String, CaseIterable, Codable {
        case debug = "Debug"
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
        case critical = "Critical"
    }
    
    enum LogCategory: String, CaseIterable, Codable {
        case modelLoading = "Model Loading"
        case inference = "Inference"
        case preprocessing = "Preprocessing"
        case postprocessing = "Postprocessing"
        case performance = "Performance"
        case memory = "Memory"
        case error = "Error"
    }
    
    // MARK: - Public Methods
    
    /// Inspect a model prediction with detailed analysis
    func inspectPrediction(input: String, modelName: String) async -> ModelInspection {
        await MainActor.run { isDebugging = true }
        
        logDebug("Starting prediction inspection for input: '\(input)'", category: .inference)
        
        let inspectionStartTime = Date()
        var processingSteps: [ProcessingStep] = []
        var intermediateResults: [IntermediateResult] = []
        
        // Step 1: Tokenization
        let tokenizationStep = await measureProcessingStep(name: "Tokenization") {
            let tokens = tokenizeInput(input)
            intermediateResults.append(IntermediateResult(
                stepName: "Tokenization",
                stepType: .tokenization,
                input: input,
                output: tokens.joined(separator: " | "),
                confidence: nil,
                metadata: ["tokenCount": "\(tokens.count)"],
                processingTime: 0.001
            ))
            return tokens
        }
        processingSteps.append(tokenizationStep.step)
        
        // Step 2: Preprocessing
        let preprocessingStep = await measureProcessingStep(name: "Preprocessing") {
            let preprocessed = preprocessTokens(tokenizationStep.result)
            intermediateResults.append(IntermediateResult(
                stepName: "Preprocessing",
                stepType: .preprocessing,
                input: tokenizationStep.result.joined(separator: " "),
                output: preprocessed.joined(separator: " "),
                confidence: nil,
                metadata: ["transformations": "lowercase, punctuation removal"],
                processingTime: 0.002
            ))
            return preprocessed
        }
        processingSteps.append(preprocessingStep.step)
        
        // Step 3: Feature Extraction
        let featureExtractionStep = await measureProcessingStep(name: "Feature Extraction") {
            let features = extractFeatures(preprocessingStep.result)
            intermediateResults.append(IntermediateResult(
                stepName: "Feature Extraction",
                stepType: .featureExtraction,
                input: preprocessingStep.result.joined(separator: " "),
                output: "Feature vector (length: \(features.count))",
                confidence: nil,
                metadata: ["featureCount": "\(features.count)", "vectorNorm": String(format: "%.3f", calculateVectorNorm(features))],
                processingTime: 0.005
            ))
            return features
        }
        processingSteps.append(featureExtractionStep.step)
        
        // Step 4: Model Inference
        let inferenceStep = await measureProcessingStep(name: "Model Inference") {
            do {
                let result = await intentClassifier.classifyIntent(input)
                intermediateResults.append(IntermediateResult(
                    stepName: "Model Inference",
                    stepType: .modelInference,
                    input: "Feature vector",
                    output: "Intent: \(result.intent), Confidence: \(String(format: "%.3f", result.confidence))",
                    confidence: result.confidence,
                    metadata: ["modelVersion": "1.0", "inferenceTime": String(format: "%.3f", 0.1)],
                    processingTime: 0.1
                ))
                return result
            } catch {
                logError("Model inference failed: \(error.localizedDescription)", category: .inference)
                return IntentClassificationResult(intent: "error", confidence: 0.0, metadata: [:])
            }
        }
        processingSteps.append(inferenceStep.step)
        
        // Step 5: Confidence Calculation
        let confidenceStep = await measureProcessingStep(name: "Confidence Calculation") {
            let breakdown = calculateConfidenceBreakdown(
                input: input,
                tokens: tokenizationStep.result,
                features: featureExtractionStep.result,
                prediction: inferenceStep.result
            )
            intermediateResults.append(IntermediateResult(
                stepName: "Confidence Calculation",
                stepType: .confidenceCalculation,
                input: "Prediction result",
                output: "Confidence breakdown calculated",
                confidence: breakdown.overallConfidence,
                metadata: ["uncertaintyFactors": "\(breakdown.uncertaintyFactors.count)"],
                processingTime: 0.003
            ))
            return breakdown
        }
        processingSteps.append(confidenceStep.step)
        
        // Generate alternative intents
        let alternativeIntents = generateAlternativeIntents(
            input: input,
            primaryIntent: inferenceStep.result.intent,
            confidence: inferenceStep.result.confidence
        )
        
        let predictionDetails = PredictionDetails(
            primaryIntent: inferenceStep.result.intent,
            confidence: inferenceStep.result.confidence,
            alternativeIntents: alternativeIntents,
            processingTime: Date().timeIntervalSince(inspectionStartTime),
            modelVersion: "IntentClassifier-v1.0",
            inputTokens: tokenizationStep.result,
            attentionWeights: generateMockAttentionWeights(tokenCount: tokenizationStep.result.count),
            hiddenStates: generateMockHiddenStates(size: 128)
        )
        
        let inspection = ModelInspection(
            modelName: modelName,
            input: input,
            prediction: predictionDetails,
            intermediateResults: intermediateResults,
            confidenceBreakdown: confidenceStep.result,
            processingSteps: processingSteps,
            timestamp: Date()
        )
        
        await MainActor.run {
            currentInspection = inspection
            isDebugging = false
        }
        
        logInfo("Prediction inspection completed for '\(input)'", category: .inference)
        
        return inspection
    }
    
    /// Profile model performance over multiple inferences
    func profilePerformance(modelName: String, testInputs: [String], duration: TimeInterval = 60.0) async -> PerformanceProfile {
        await MainActor.run { isDebugging = true }
        
        logInfo("Starting performance profiling for \(modelName)", category: .performance)
        
        let profileStartTime = Date()
        var latencies: [TimeInterval] = []
        var memorySnapshots: [Int64] = []
        var cpuUsageSnapshots: [Double] = []
        var errors = 0
        var timeouts = 0
        
        let baselineMemory = getCurrentMemoryUsage()
        var peakMemory = baselineMemory
        
        // Run inferences for the specified duration
        let endTime = Date().addingTimeInterval(duration)
        var inferenceCount = 0
        
        while Date() < endTime && inferenceCount < 1000 { // Safety limit
            let input = testInputs[inferenceCount % testInputs.count]
            let startTime = Date()
            let memoryBefore = getCurrentMemoryUsage()
            
            do {
                let result = await intentClassifier.classifyIntent(input)
                let latency = Date().timeIntervalSince(startTime)
                latencies.append(latency)
                
                if latency > 5.0 { // 5 second timeout
                    timeouts += 1
                }
                
            } catch {
                errors += 1
                logError("Inference error during profiling: \(error.localizedDescription)", category: .performance)
            }
            
            let memoryAfter = getCurrentMemoryUsage()
            memorySnapshots.append(memoryAfter)
            peakMemory = max(peakMemory, memoryAfter)
            
            // Mock CPU usage (in real implementation, would use actual CPU monitoring)
            cpuUsageSnapshots.append(Double.random(in: 20...80))
            
            inferenceCount += 1
            
            // Small delay to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        let actualDuration = Date().timeIntervalSince(profileStartTime)
        
        // Calculate performance metrics
        let sortedLatencies = latencies.sorted()
        let performanceMetrics = PerformanceMetrics(
            averageLatency: latencies.reduce(0, +) / Double(latencies.count),
            p50Latency: percentile(sortedLatencies, 0.5),
            p95Latency: percentile(sortedLatencies, 0.95),
            p99Latency: percentile(sortedLatencies, 0.99),
            minLatency: sortedLatencies.first ?? 0,
            maxLatency: sortedLatencies.last ?? 0,
            throughput: Double(inferenceCount) / actualDuration,
            errorRate: Double(errors) / Double(inferenceCount),
            timeoutRate: Double(timeouts) / Double(inferenceCount)
        )
        
        // Memory profile
        let averageMemory = memorySnapshots.reduce(0, +) / Int64(memorySnapshots.count)
        let memoryGrowth = memorySnapshots.count > 1 ? 
            Double(memorySnapshots.last! - memorySnapshots.first!) / Double(memorySnapshots.count) : 0
        
        let memoryProfile = MemoryProfile(
            baselineMemory: baselineMemory,
            peakMemory: peakMemory,
            averageMemory: averageMemory,
            memoryGrowthRate: memoryGrowth,
            memoryLeakSuspected: memoryGrowth > 1024 * 1024, // 1MB growth per inference
            gcPressure: calculateGCPressure(memorySnapshots),
            allocationHotspots: generateMockAllocationHotspots()
        )
        
        // CPU profile
        let averageCPU = cpuUsageSnapshots.reduce(0, +) / Double(cpuUsageSnapshots.count)
        let peakCPU = cpuUsageSnapshots.max() ?? 0
        
        let cpuProfile = CPUProfile(
            averageCPUUsage: averageCPU,
            peakCPUUsage: peakCPU,
            coreUsageDistribution: generateMockCoreUsageDistribution(),
            neuralEngineUsage: Double.random(in: 0...100),
            gpuUsage: Double.random(in: 0...50),
            cpuHotspots: generateMockCPUHotspots()
        )
        
        // Battery and thermal profiles
        let batteryImpact = BatteryImpact(
            estimatedBatteryDrain: estimateBatteryDrain(cpuUsage: averageCPU, duration: actualDuration),
            powerEfficiencyScore: calculatePowerEfficiency(throughput: performanceMetrics.throughput, cpuUsage: averageCPU),
            thermalContribution: averageCPU * 0.8,
            backgroundProcessingImpact: 0.1,
            batteryOptimizationSuggestions: generateBatteryOptimizationSuggestions(performanceMetrics)
        )
        
        let thermalProfile = ThermalProfile(
            thermalState: getThermalState(),
            temperatureIncrease: averageCPU * 0.5,
            throttlingDetected: peakCPU > 90,
            coolingRecommendations: generateCoolingRecommendations(peakCPU)
        )
        
        // Generate recommendations
        let recommendations = generatePerformanceRecommendations(
            performanceMetrics: performanceMetrics,
            memoryProfile: memoryProfile,
            cpuProfile: cpuProfile
        )
        
        let profile = PerformanceProfile(
            modelName: modelName,
            profileStartTime: profileStartTime,
            profileDuration: actualDuration,
            totalInferences: inferenceCount,
            performanceMetrics: performanceMetrics,
            memoryProfile: memoryProfile,
            cpuProfile: cpuProfile,
            batteryImpact: batteryImpact,
            thermalProfile: thermalProfile,
            recommendations: recommendations
        )
        
        await MainActor.run {
            performanceProfile = profile
            isDebugging = false
        }
        
        logInfo("Performance profiling completed. Processed \(inferenceCount) inferences in \(String(format: "%.2f", actualDuration))s", category: .performance)
        
        return profile
    }
    
    /// Visualize decision tree for interpretability
    func visualizeDecisionTree(modelName: String, maxDepth: Int = 10) async -> DecisionTreeVisualization {
        await MainActor.run { isDebugging = true }
        
        logInfo("Generating decision tree visualization for \(modelName)", category: .inference)
        
        // Generate mock decision tree (in real implementation, would extract from actual model)
        let rootNode = generateMockDecisionTree(depth: 0, maxDepth: maxDepth)
        let (totalNodes, leafNodes) = countNodes(rootNode)
        let averagePathLength = calculateAveragePathLength(rootNode)
        let complexity = determineTreeComplexity(totalNodes: totalNodes, maxDepth: maxDepth)
        
        // Generate visualization data
        let visualization = generateTreeVisualization(rootNode: rootNode)
        
        let treeVisualization = DecisionTreeVisualization(
            rootNode: rootNode,
            totalNodes: totalNodes,
            maxDepth: maxDepth,
            leafNodes: leafNodes,
            averagePathLength: averagePathLength,
            treeComplexity: complexity,
            visualization: visualization
        )
        
        await MainActor.run {
            decisionTree = treeVisualization
            isDebugging = false
        }
        
        logInfo("Decision tree visualization generated with \(totalNodes) nodes", category: .inference)
        
        return treeVisualization
    }
    
    /// Analyze confidence scores and calibration
    func analyzeConfidence(modelName: String, testCases: [(input: String, expectedIntent: String)]) async -> ConfidenceAnalysis {
        await MainActor.run { isDebugging = true }
        
        logInfo("Starting confidence analysis for \(modelName)", category: .inference)
        
        var predictions: [(predicted: String, confidence: Double, actual: String)] = []
        
        // Collect predictions
        for testCase in testCases {
            do {
                let result = await intentClassifier.classifyIntent(testCase.input)
                predictions.append((result.intent, result.confidence, testCase.expectedIntent))
            } catch {
                logError("Failed to get prediction for confidence analysis: \(error.localizedDescription)", category: .inference)
            }
        }
        
        // Calculate confidence distribution
        let confidences = predictions.map { $0.confidence }
        let distribution = calculateConfidenceDistribution(confidences)
        
        // Calculate calibration curve
        let calibrationCurve = calculateCalibrationCurve(predictions)
        
        // Calculate reliability metrics
        let reliabilityMetrics = calculateReliabilityMetrics(predictions)
        
        // Determine optimal thresholds
        let thresholds = calculateOptimalThresholds(predictions)
        
        // Generate recommendations
        let recommendations = generateConfidenceRecommendations(
            distribution: distribution,
            calibration: calibrationCurve,
            reliability: reliabilityMetrics
        )
        
        let analysis = ConfidenceAnalysis(
            modelName: modelName,
            analysisDate: Date(),
            sampleSize: predictions.count,
            confidenceDistribution: distribution,
            calibrationCurve: calibrationCurve,
            reliabilityMetrics: reliabilityMetrics,
            confidenceThresholds: thresholds,
            recommendations: recommendations
        )
        
        await MainActor.run {
            confidenceAnalysis = analysis
            isDebugging = false
        }
        
        logInfo("Confidence analysis completed for \(predictions.count) predictions", category: .inference)
        
        return analysis
    }
    
    /// Clear all debugging data
    func clearDebuggingData() {
        currentInspection = nil
        performanceProfile = nil
        decisionTree = nil
        confidenceAnalysis = nil
        debugLogs.removeAll()
        
        logInfo("Debugging data cleared", category: .debug)
    }
    
    /// Export debugging data
    func exportDebuggingData() -> Data? {
        let exportData = DebuggingExport(
            inspection: currentInspection,
            performanceProfile: performanceProfile,
            decisionTree: decisionTree,
            confidenceAnalysis: confidenceAnalysis,
            debugLogs: debugLogs,
            exportDate: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(exportData)
        } catch {
            logError("Failed to export debugging data: \(error.localizedDescription)", category: .error)
            return nil
        }
    }
    
    struct DebuggingExport: Codable {
        let inspection: ModelInspection?
        let performanceProfile: PerformanceProfile?
        let decisionTree: DecisionTreeVisualization?
        let confidenceAnalysis: ConfidenceAnalysis?
        let debugLogs: [DebugLog]
        let exportDate: Date
    }
    
    // MARK: - Private Helper Methods
    
    private func logDebug(_ message: String, category: LogCategory, context: [String: String] = [:]) {
        let log = DebugLog(
            timestamp: Date(),
            level: .debug,
            category: category,
            message: message,
            context: context,
            stackTrace: nil
        )
        
        DispatchQueue.main.async {
            self.debugLogs.append(log)
            // Keep only recent logs
            if self.debugLogs.count > 1000 {
                self.debugLogs.removeFirst(self.debugLogs.count - 1000)
            }
        }
        
        print("🐛 [\(category.rawValue)] \(message)")
    }
    
    private func logInfo(_ message: String, category: LogCategory, context: [String: String] = [:]) {
        let log = DebugLog(
            timestamp: Date(),
            level: .info,
            category: category,
            message: message,
            context: context,
            stackTrace: nil
        )
        
        DispatchQueue.main.async {
            self.debugLogs.append(log)
        }
        
        print("ℹ️ [\(category.rawValue)] \(message)")
    }
    
    private func logError(_ message: String, category: LogCategory, context: [String: String] = [:]) {
        let log = DebugLog(
            timestamp: Date(),
            level: .error,
            category: category,
            message: message,
            context: context,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n")
        )
        
        DispatchQueue.main.async {
            self.debugLogs.append(log)
        }
        
        print("❌ [\(category.rawValue)] \(message)")
    }
    
    private func measureProcessingStep<T>(name: String, operation: () async throws -> T) async -> (result: T, step: ProcessingStep) {
        let startTime = Date()
        let memoryBefore = getCurrentMemoryUsage()
        
        var result: T
        var success = true
        var errorMessage: String?
        
        do {
            result = try await operation()
        } catch {
            success = false
            errorMessage = error.localizedDescription
            // Provide a default value - this is a simplified approach
            result = "Error" as! T
        }
        
        let endTime = Date()
        let memoryAfter = getCurrentMemoryUsage()
        
        let step = ProcessingStep(
            name: name,
            startTime: startTime,
            endTime: endTime,
            duration: endTime.timeIntervalSince(startTime),
            memoryBefore: memoryBefore,
            memoryAfter: memoryAfter,
            cpuUsage: Double.random(in: 10...60), // Mock CPU usage
            success: success,
            errorMessage: errorMessage
        )
        
        return (result, step)
    }
    
    private func tokenizeInput(_ input: String) -> [String] {
        return input.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
    
    private func preprocessTokens(_ tokens: [String]) -> [String] {
        return tokens.map { token in
            token.lowercased()
                .trimmingCharacters(in: .punctuationCharacters)
        }.filter { !$0.isEmpty }
    }
    
    private func extractFeatures(_ tokens: [String]) -> [Double] {
        // Mock feature extraction - in reality, would use word embeddings, TF-IDF, etc.
        return tokens.map { token in
            Double(token.count) * Double.random(in: 0.5...1.5)
        } + Array(repeating: Double.random(in: -1...1), count: 100) // Padding to 100+ features
    }
    
    private func calculateVectorNorm(_ vector: [Double]) -> Double {
        return sqrt(vector.map { $0 * $0 }.reduce(0, +))
    }
    
    private func calculateConfidenceBreakdown(
        input: String,
        tokens: [String],
        features: [Double],
        prediction: IntentClassificationResult
    ) -> ConfidenceBreakdown {
        
        // Mock confidence breakdown calculation
        let vocabularyConfidence = min(1.0, Double(tokens.count) / 10.0)
        let syntaxConfidence = prediction.confidence * Double.random(in: 0.8...1.2)
        let semanticConfidence = prediction.confidence * Double.random(in: 0.7...1.1)
        let contextConfidence = prediction.confidence * Double.random(in: 0.9...1.0)
        
        var uncertaintyFactors: [UncertaintyFactor] = []
        
        if tokens.count < 3 {
            uncertaintyFactors.append(UncertaintyFactor(
                factor: "Short input",
                impact: 0.2,
                description: "Input has fewer than 3 tokens",
                severity: .medium
            ))
        }
        
        if prediction.confidence < 0.7 {
            uncertaintyFactors.append(UncertaintyFactor(
                factor: "Low model confidence",
                impact: 0.3,
                description: "Model confidence below 70%",
                severity: .high
            ))
        }
        
        let confidenceDistribution = generateConfidenceDistribution(baseConfidence: prediction.confidence)
        
        return ConfidenceBreakdown(
            overallConfidence: prediction.confidence,
            vocabularyConfidence: vocabularyConfidence,
            syntaxConfidence: min(1.0, syntaxConfidence),
            semanticConfidence: min(1.0, semanticConfidence),
            contextConfidence: min(1.0, contextConfidence),
            uncertaintyFactors: uncertaintyFactors,
            confidenceDistribution: confidenceDistribution
        )
    }
    
    private func generateAlternativeIntents(input: String, primaryIntent: String, confidence: Double) -> [AlternativeIntent] {
        let alternativeIntents = [
            "general_conversation",
            "calendar_query",
            "email_compose",
            "task_create",
            "weather_query",
            "time_query",
            "calculation",
            "device_control"
        ].filter { $0 != primaryIntent }
        
        return alternativeIntents.prefix(3).map { intent in
            AlternativeIntent(intent: intent, confidence: (1.0 - confidence) * Double.random(in: 0.1...0.8))
        }.sorted { $0.confidence > $1.confidence }
    }
    
    private func generateMockAttentionWeights(tokenCount: Int) -> [Double] {
        return (0..<tokenCount).map { _ in Double.random(in: 0.0...1.0) }
    }
    
    private func generateMockHiddenStates(size: Int) -> [Double] {
        return (0..<size).map { _ in Double.random(in: -1.0...1.0) }
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
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
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
    
    private func percentile(_ sortedArray: [TimeInterval], _ percentile: Double) -> TimeInterval {
        guard !sortedArray.isEmpty else { return 0 }
        
        let index = percentile * Double(sortedArray.count - 1)
        let lowerIndex = Int(index.rounded(.down))
        let upperIndex = Int(index.rounded(.up))
        
        if lowerIndex == upperIndex {
            return sortedArray[lowerIndex]
        } else {
            let weight = index - Double(lowerIndex)
            return sortedArray[lowerIndex] * (1 - weight) + sortedArray[upperIndex] * weight
        }
    }
    
    private func calculateGCPressure(_ memorySnapshots: [Int64]) -> Double {
        guard memorySnapshots.count > 1 else { return 0 }
        
        var pressure = 0.0
        for i in 1..<memorySnapshots.count {
            let change = Double(memorySnapshots[i] - memorySnapshots[i-1])
            if change < 0 { // Memory decrease indicates GC
                pressure += abs(change) / Double(memorySnapshots[i-1])
            }
        }
        
        return pressure / Double(memorySnapshots.count - 1)
    }
    
    private func generateMockAllocationHotspots() -> [AllocationHotspot] {
        return [
            AllocationHotspot(
                location: "IntentClassifier.classifyIntent",
                allocatedBytes: 2_048_576, // 2MB
                frequency: 150,
                impact: "High"
            ),
            AllocationHotspot(
                location: "FeatureExtractor.extractFeatures",
                allocatedBytes: 1_024_000, // 1MB
                frequency: 100,
                impact: "Medium"
            ),
            AllocationHotspot(
                location: "TokenProcessor.preprocess",
                allocatedBytes: 512_000, // 512KB
                frequency: 200,
                impact: "Low"
            )
        ]
    }
    
    private func generateMockCoreUsageDistribution() -> [Double] {
        // Mock CPU core usage distribution
        return [
            Double.random(in: 20...80), // Core 0
            Double.random(in: 15...70), // Core 1
            Double.random(in: 10...60), // Core 2
            Double.random(in: 5...50),  // Core 3
        ]
    }
    
    private func generateMockCPUHotspots() -> [CPUHotspot] {
        return [
            CPUHotspot(
                id: UUID(),
                function: "MLModel.prediction",
                cpuTime: 0.45,
                percentage: 35.2,
                callCount: 150
            ),
            CPUHotspot(
                id: UUID(),
                function: "FeatureExtraction.process",
                cpuTime: 0.28,
                percentage: 22.1,
                callCount: 150
            ),
            CPUHotspot(
                id: UUID(),
                function: "Tokenizer.tokenize",
                cpuTime: 0.15,
                percentage: 11.8,
                callCount: 200
            )
        ]
    }
    
    private func estimateBatteryDrain(cpuUsage: Double, duration: TimeInterval) -> Double {
        // Rough estimate: 1% battery per hour at 50% CPU usage
        let baseRate = 1.0 / 3600.0 // 1% per hour in %/second
        let cpuMultiplier = cpuUsage / 50.0
        return baseRate * cpuMultiplier * duration
    }
    
    private func calculatePowerEfficiency(throughput: Double, cpuUsage: Double) -> Double {
        // Efficiency = throughput per unit of CPU usage
        guard cpuUsage > 0 else { return 0 }
        return min(100.0, (throughput / cpuUsage) * 10)
    }
    
    private func generateBatteryOptimizationSuggestions(_ metrics: PerformanceMetrics) -> [String] {
        var suggestions: [String] = []
        
        if metrics.averageLatency > 0.5 {
            suggestions.append("Optimize model inference speed to reduce CPU time")
        }
        
        if metrics.throughput < 10 {
            suggestions.append("Implement batch processing to improve throughput efficiency")
        }
        
        if metrics.errorRate > 0.01 {
            suggestions.append("Reduce error rate to avoid unnecessary reprocessing")
        }
        
        suggestions.append("Consider using Neural Engine for more power-efficient inference")
        
        return suggestions
    }
    
    private func getThermalState() -> String {
        let thermalStates = ["Nominal", "Fair", "Serious", "Critical"]
        return thermalStates.randomElement() ?? "Nominal"
    }
    
    private func generateCoolingRecommendations(_ peakCPU: Double) -> [String] {
        var recommendations: [String] = []
        
        if peakCPU > 90 {
            recommendations.append("Reduce model complexity to lower CPU usage")
            recommendations.append("Implement thermal throttling in inference loop")
        }
        
        if peakCPU > 70 {
            recommendations.append("Add processing delays to allow cooling")
            recommendations.append("Monitor thermal state and adjust workload")
        }
        
        return recommendations
    }
    
    private func generatePerformanceRecommendations(
        performanceMetrics: PerformanceMetrics,
        memoryProfile: MemoryProfile,
        cpuProfile: CPUProfile
    ) -> [PerformanceRecommendation] {
        
        var recommendations: [PerformanceRecommendation] = []
        
        // Latency recommendations
        if performanceMetrics.averageLatency > 0.5 {
            recommendations.append(PerformanceRecommendation(
                category: .modelOptimization,
                priority: .high,
                title: "Optimize Model Inference Speed",
                description: "Average latency of \(String(format: "%.3f", performanceMetrics.averageLatency))s exceeds recommended threshold",
                expectedImprovement: "20-40% latency reduction",
                implementationEffort: "Medium"
            ))
        }
        
        // Memory recommendations
        if memoryProfile.memoryLeakSuspected {
            recommendations.append(PerformanceRecommendation(
                category: .memoryManagement,
                priority: .critical,
                title: "Address Memory Leak",
                description: "Memory growth rate indicates potential memory leak",
                expectedImprovement: "Stable memory usage",
                implementationEffort: "High"
            ))
        }
        
        // CPU recommendations
        if cpuProfile.averageCPUUsage > 70 {
            recommendations.append(PerformanceRecommendation(
                category: .cpuOptimization,
                priority: .medium,
                title: "Reduce CPU Usage",
                description: "High CPU usage may impact battery life and thermal performance",
                expectedImprovement: "15-25% CPU reduction",
                implementationEffort: "Medium"
            ))
        }
        
        // Throughput recommendations
        if performanceMetrics.throughput < 5 {
            recommendations.append(PerformanceRecommendation(
                category: .modelOptimization,
                priority: .medium,
                title: "Improve Processing Throughput",
                description: "Low throughput may impact user experience during high load",
                expectedImprovement: "2-3x throughput increase",
                implementationEffort: "Low"
            ))
        }
        
        return recommendations
    }
    
    // Decision Tree Generation
    private func generateMockDecisionTree(depth: Int, maxDepth: Int, feature: String = "input_length") -> DecisionNode {
        if depth >= maxDepth || Double.random(in: 0...1) < 0.3 {
            // Leaf node
            let intents = ["calendar_query", "email_compose", "task_create", "weather_query", "general"]
            return DecisionNode(
                nodeType: .leaf,
                feature: nil,
                threshold: nil,
                decision: intents.randomElement(),
                confidence: Double.random(in: 0.7...0.95),
                sampleCount: Int.random(in: 10...100),
                impurity: Double.random(in: 0...0.3),
                children: [],
                depth: depth,
                path: generatePath(depth: depth)
            )
        } else {
            // Internal node
            let features = ["input_length", "keyword_count", "sentiment_score", "complexity"]
            let selectedFeature = features.randomElement() ?? feature
            let threshold = Double.random(in: 0.1...0.9)
            
            let leftChild = generateMockDecisionTree(
                depth: depth + 1,
                maxDepth: maxDepth,
                feature: selectedFeature
            )
            let rightChild = generateMockDecisionTree(
                depth: depth + 1,
                maxDepth: maxDepth,
                feature: selectedFeature
            )
            
            return DecisionNode(
                nodeType: depth == 0 ? .root : .intermediate,
                feature: selectedFeature,
                threshold: threshold,
                decision: nil,
                confidence: Double.random(in: 0.5...0.8),
                sampleCount: leftChild.sampleCount + rightChild.sampleCount,
                impurity: Double.random(in: 0.3...0.7),
                children: [leftChild, rightChild],
                depth: depth,
                path: generatePath(depth: depth)
            )
        }
    }
    
    private func generatePath(depth: Int) -> [String] {
        var path: [String] = []
        for i in 0..<depth {
            path.append("level_\(i)")
        }
        return path
    }
    
    private func countNodes(_ node: DecisionNode) -> (total: Int, leaves: Int) {
        if node.children.isEmpty {
            return (1, 1)
        } else {
            var totalNodes = 1
            var totalLeaves = 0
            
            for child in node.children {
                let (childTotal, childLeaves) = countNodes(child)
                totalNodes += childTotal
                totalLeaves += childLeaves
            }
            
            return (totalNodes, totalLeaves)
        }
    }
    
    private func calculateAveragePathLength(_ node: DecisionNode) -> Double {
        func calculatePathLengths(_ node: DecisionNode, currentDepth: Int) -> [Int] {
            if node.children.isEmpty {
                return [currentDepth]
            } else {
                var pathLengths: [Int] = []
                for child in node.children {
                    pathLengths.append(contentsOf: calculatePathLengths(child, currentDepth: currentDepth + 1))
                }
                return pathLengths
            }
        }
        
        let pathLengths = calculatePathLengths(node, currentDepth: 0)
        return pathLengths.isEmpty ? 0 : Double(pathLengths.reduce(0, +)) / Double(pathLengths.count)
    }
    
    private func determineTreeComplexity(totalNodes: Int, maxDepth: Int) -> TreeComplexity {
        if totalNodes <= 10 && maxDepth <= 3 {
            return .simple
        } else if totalNodes <= 50 && maxDepth <= 6 {
            return .moderate
        } else if totalNodes <= 200 && maxDepth <= 10 {
            return .complex
        } else {
            return .veryComplex
        }
    }
    
    private func generateTreeVisualization(rootNode: DecisionNode) -> TreeVisualizationData {
        var nodes: [VisualizationNode] = []
        var edges: [VisualizationEdge] = []
        
        func traverse(_ node: DecisionNode, x: Double, y: Double, level: Int) {
            let nodeColor = node.nodeType == .leaf ? "#90EE90" : "#ADD8E6"
            let label = node.nodeType == .leaf ? 
                (node.decision ?? "Unknown") : 
                "\(node.feature ?? "Unknown") <= \(String(format: "%.2f", node.threshold ?? 0))"
            
            let visualNode = VisualizationNode(
                nodeId: node.id,
                x: x,
                y: y,
                width: 120,
                height: 60,
                color: nodeColor,
                label: label,
                tooltip: "Samples: \(node.sampleCount), Confidence: \(String(format: "%.2f", node.confidence))"
            )
            nodes.append(visualNode)
            
            // Add children
            if !node.children.isEmpty {
                let childSpacing = 200.0 / Double(node.children.count)
                for (index, child) in node.children.enumerated() {
                    let childX = x - 100 + Double(index) * childSpacing
                    let childY = y + 100
                    
                    let edge = VisualizationEdge(
                        fromNodeId: node.id,
                        toNodeId: child.id,
                        condition: index == 0 ? "Yes" : "No",
                        weight: child.confidence,
                        color: "#333333"
                    )
                    edges.append(edge)
                    
                    traverse(child, x: childX, y: childY, level: level + 1)
                }
            }
        }
        
        traverse(rootNode, x: 400, y: 50, level: 0)
        
        let layout = TreeLayout(
            width: 800,
            height: 600,
            spacing: TreeSpacing(horizontal: 150, vertical: 100, nodeMargin: 20),
            orientation: .topDown
        )
        
        return TreeVisualizationData(nodes: nodes, edges: edges, layout: layout)
    }
    
    // Confidence Analysis Methods
    private func calculateConfidenceDistribution(_ confidences: [Double]) -> ConfidenceDistribution {
        let binCount = 10
        let binSize = 1.0 / Double(binCount)
        var bins: [ConfidenceBin] = []
        
        for i in 0..<binCount {
            let lowerBound = Double(i) * binSize
            let upperBound = Double(i + 1) * binSize
            let range = lowerBound...upperBound
            
            let binConfidences = confidences.filter { range.contains($0) }
            let count = binConfidences.count
            let percentage = Double(count) / Double(confidences.count) * 100
            let averageAccuracy = count > 0 ? Double.random(in: 0.7...0.95) : 0 // Mock accuracy
            
            bins.append(ConfidenceBin(
                range: range,
                count: count,
                percentage: percentage,
                averageAccuracy: averageAccuracy
            ))
        }
        
        let mean = confidences.reduce(0, +) / Double(confidences.count)
        let sortedConfidences = confidences.sorted()
        let median = sortedConfidences[sortedConfidences.count / 2]
        let variance = confidences.map { pow($0 - mean, 2) }.reduce(0, +) / Double(confidences.count)
        let standardDeviation = sqrt(variance)
        
        return ConfidenceDistribution(
            bins: bins,
            mean: mean,
            median: median,
            standardDeviation: standardDeviation,
            skewness: calculateSkewness(confidences, mean: mean, std: standardDeviation),
            kurtosis: calculateKurtosis(confidences, mean: mean, std: standardDeviation)
        )
    }
    
    private func calculateSkewness(_ values: [Double], mean: Double, std: Double) -> Double {
        guard std > 0 else { return 0 }
        let skew = values.map { pow(($0 - mean) / std, 3) }.reduce(0, +) / Double(values.count)
        return skew
    }
    
    private func calculateKurtosis(_ values: [Double], mean: Double, std: Double) -> Double {
        guard std > 0 else { return 0 }
        let kurt = values.map { pow(($0 - mean) / std, 4) }.reduce(0, +) / Double(values.count) - 3
        return kurt
    }
    
    private func calculateCalibrationCurve(_ predictions: [(predicted: String, confidence: Double, actual: String)]) -> CalibrationCurve {
        let binCount = 10
        var points: [CalibrationPoint] = []
        
        for i in 0..<binCount {
            let lowerBound = Double(i) / Double(binCount)
            let upperBound = Double(i + 1) / Double(binCount)
            
            let binPredictions = predictions.filter { 
                $0.confidence >= lowerBound && $0.confidence < upperBound 
            }
            
            if !binPredictions.isEmpty {
                let meanConfidence = binPredictions.map { $0.confidence }.reduce(0, +) / Double(binPredictions.count)
                let correctPredictions = binPredictions.filter { $0.predicted == $0.actual }.count
                let accuracy = Double(correctPredictions) / Double(binPredictions.count)
                
                points.append(CalibrationPoint(
                    meanPredictedProbability: meanConfidence,
                    fractionOfPositives: accuracy,
                    sampleCount: binPredictions.count
                ))
            }
        }
        
        let reliability = calculateReliability(points)
        let resolution = calculateResolution(points)
        let calibrationError = calculateCalibrationError(points)
        let isWellCalibrated = calibrationError < 0.1
        
        return CalibrationCurve(
            points: points,
            reliability: reliability,
            resolution: resolution,
            calibrationError: calibrationError,
            isWellCalibrated: isWellCalibrated
        )
    }
    
    private func calculateReliability(_ points: [CalibrationPoint]) -> Double {
        // Simplified reliability calculation
        return points.map { abs($0.meanPredictedProbability - $0.fractionOfPositives) }.reduce(0, +) / Double(points.count)
    }
    
    private func calculateResolution(_ points: [CalibrationPoint]) -> Double {
        // Simplified resolution calculation
        let overallAccuracy = points.map { $0.fractionOfPositives * Double($0.sampleCount) }.reduce(0, +) / 
                             Double(points.map { $0.sampleCount }.reduce(0, +))
        
        return points.map { 
            pow($0.fractionOfPositives - overallAccuracy, 2) * Double($0.sampleCount) 
        }.reduce(0, +) / Double(points.map { $0.sampleCount }.reduce(0, +))
    }
    
    private func calculateCalibrationError(_ points: [CalibrationPoint]) -> Double {
        let totalSamples = Double(points.map { $0.sampleCount }.reduce(0, +))
        return points.map { 
            abs($0.meanPredictedProbability - $0.fractionOfPositives) * Double($0.sampleCount) / totalSamples 
        }.reduce(0, +)
    }
    
    private func calculateReliabilityMetrics(_ predictions: [(predicted: String, confidence: Double, actual: String)]) -> ReliabilityMetrics {
        let correctPredictions = predictions.filter { $0.predicted == $0.actual }
        let accuracy = Double(correctPredictions.count) / Double(predictions.count)
        
        // Simplified metrics (in real implementation, would use proper statistical calculations)
        let brierScore = predictions.map { prediction in
            let isCorrect = prediction.predicted == prediction.actual ? 1.0 : 0.0
            return pow(prediction.confidence - isCorrect, 2)
        }.reduce(0, +) / Double(predictions.count)
        
        let logLoss = predictions.map { prediction in
            let isCorrect = prediction.predicted == prediction.actual ? 1.0 : 0.0
            let epsilon = 1e-15
            let clampedConfidence = max(epsilon, min(1 - epsilon, prediction.confidence))
            return -(isCorrect * log(clampedConfidence) + (1 - isCorrect) * log(1 - clampedConfidence))
        }.reduce(0, +) / Double(predictions.count)
        
        return ReliabilityMetrics(
            brierScore: brierScore,
            logLoss: logLoss,
            expectedCalibrationError: Double.random(in: 0.05...0.15),
            maximumCalibrationError: Double.random(in: 0.1...0.3),
            reliabilityIndex: accuracy
        )
    }
    
    private func calculateOptimalThresholds(_ predictions: [(predicted: String, confidence: Double, actual: String)]) -> ConfidenceThresholds {
        // Simplified threshold calculation
        let sortedByConfidence = predictions.sorted { $0.confidence > $1.confidence }
        
        var bestF1Threshold = 0.5
        var bestF1Score = 0.0
        
        for threshold in stride(from: 0.1, through: 0.9, by: 0.1) {
            let thresholdPredictions = sortedByConfidence.filter { $0.confidence >= threshold }
            let tp = Double(thresholdPredictions.filter { $0.predicted == $0.actual }.count)
            let fp = Double(thresholdPredictions.filter { $0.predicted != $0.actual }.count)
            let fn = Double(predictions.filter { $0.confidence < threshold && $0.predicted == $0.actual }.count)
            
            let precision = tp + fp > 0 ? tp / (tp + fp) : 0
            let recall = tp + fn > 0 ? tp / (tp + fn) : 0
            let f1 = precision + recall > 0 ? 2 * (precision * recall) / (precision + recall) : 0
            
            if f1 > bestF1Score {
                bestF1Score = f1
                bestF1Threshold = threshold
            }
        }
        
        return ConfidenceThresholds(
            optimalThreshold: bestF1Threshold,
            highPrecisionThreshold: 0.9,
            highRecallThreshold: 0.3,
            balancedThreshold: 0.5,
            customThresholds: []
        )
    }
    
    private func generateConfidenceRecommendations(
        distribution: ConfidenceDistribution,
        calibration: CalibrationCurve,
        reliability: ReliabilityMetrics
    ) -> [ConfidenceRecommendation] {
        
        var recommendations: [ConfidenceRecommendation] = []
        
        if !calibration.isWellCalibrated {
            recommendations.append(ConfidenceRecommendation(
                type: .calibrationImprovement,
                priority: .high,
                title: "Improve Model Calibration",
                description: "Model confidence scores are not well calibrated with actual accuracy",
                suggestedThreshold: nil,
                expectedImprovement: "Better confidence reliability"
            ))
        }
        
        if distribution.standardDeviation < 0.1 {
            recommendations.append(ConfidenceRecommendation(
                type: .uncertaintyQuantification,
                priority: .medium,
                title: "Increase Confidence Variance",
                description: "Model shows low confidence variance, may be overconfident",
                suggestedThreshold: nil,
                expectedImprovement: "More discriminative confidence scores"
            ))
        }
        
        if reliability.brierScore > 0.25 {
            recommendations.append(ConfidenceRecommendation(
                type: .thresholdAdjustment,
                priority: .medium,
                title: "Adjust Confidence Thresholds",
                description: "High Brier score indicates poor probability estimates",
                suggestedThreshold: 0.7,
                expectedImprovement: "Better decision boundaries"
            ))
        }
        
        return recommendations
    }
    
    private func generateConfidenceDistribution(baseConfidence: Double) -> [Double] {
        // Generate a distribution around the base confidence
        return (0..<10).map { _ in
            max(0.0, min(1.0, baseConfidence + Double.random(in: -0.2...0.2)))
        }
    }
}

// MARK: - Extensions

extension MLDebuggingTools.ProcessingStepType {
    var emoji: String {
        switch self {
        case .tokenization: return "✂️"
        case .preprocessing: return "🔧"
        case .featureExtraction: return "🎯"
        case .modelInference: return "🧠"
        case .postprocessing: return "⚙️"
        case .confidenceCalculation: return "📊"
        }
    }
}

extension MLDebuggingTools.UncertaintySeverity {
    var emoji: String {
        switch self {
        case .low: return "🟢"
        case .medium: return "🟡"
        case .high: return "🟠"
        case .critical: return "🔴"
        }
    }
}

extension MLDebuggingTools.LogLevel {
    var emoji: String {
        switch self {
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}