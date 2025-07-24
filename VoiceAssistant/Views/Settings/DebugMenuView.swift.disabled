//
//  DebugMenuView.swift
//  VoiceAssistant
//
//  Created by Core ML Testing Framework
//

import SwiftUI
import CoreML

@available(iOS 15.0, *)
struct DebugMenuView: View {
    @StateObject private var testingFramework = MLTestingFramework()
    @StateObject private var modelValidator = ModelValidator()
    @StateObject private var abTestingManager = ABTestingManager()
    @StateObject private var debuggingTools = MLDebuggingTools()
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DebugTab = .testing
    @State private var showingTestResults = false
    @State private var showingModelDetails = false
    @State private var showingPerformanceMetrics = false
    @State private var showingDebugLogs = false
    @State private var isRunningTests = false
    
    enum DebugTab: String, CaseIterable {
        case testing = "Testing"
        case validation = "Validation" 
        case experiments = "A/B Tests"
        case debugging = "Debug Tools"
        case metrics = "Metrics"
        case logs = "Logs"
        
        var icon: String {
            switch self {
            case .testing: return "flask"
            case .validation: return "checkmark.shield"
            case .experiments: return "chart.line.uptrend.xyaxis"
            case .debugging: return "ladybug"
            case .metrics: return "speedometer"
            case .logs: return "doc.text.magnifyingglass"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                tabSelectionView
                contentView
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingTestResults) {
            TestResultsDetailView(results: testingFramework.testResults)
        }
        .sheet(isPresented: $showingModelDetails) {
            ModelDetailsView(validator: modelValidator)
        }
        .sheet(isPresented: $showingPerformanceMetrics) {
            PerformanceMetricsView(debuggingTools: debuggingTools)
        }
        .sheet(isPresented: $showingDebugLogs) {
            DebugLogsView()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("🧪 Debug Menu")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Core ML Testing Framework")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Quick access to test all
            Button(action: runAllTests) {
                Image(systemName: isRunningTests ? "stop.circle" : "play.circle")
                    .font(.title2)
                    .foregroundColor(isRunningTests ? .red : .green)
            }
            .disabled(isRunningTests)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
    }
    
    // MARK: - Tab Selection View
    private var tabSelectionView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(DebugTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedTab == tab ? .blue : .white.opacity(0.6))
                            
                            Text(tab.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(selectedTab == tab ? .blue : .white.opacity(0.6))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.blue.opacity(0.2) : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
    }
    
    // MARK: - Content View
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                switch selectedTab {
                case .testing:
                    testingFrameworkSection
                case .validation:
                    modelValidationSection
                case .experiments:
                    abTestingSection
                case .debugging:
                    debuggingToolsSection
                case .metrics:
                    metricsSection
                case .logs:
                    logsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Testing Framework Section
    private var testingFrameworkSection: some View {
        VStack(spacing: 16) {
            SectionHeaderView(
                title: "ML Testing Framework",
                subtitle: "Comprehensive model testing and validation",
                icon: "flask.fill"
            )
            
            // Test Suite Status
            TestStatusCardView(
                title: "Test Suite Status",
                isRunning: testingFramework.isRunningTests,
                progress: testingFramework.currentTestProgress,
                totalResults: testingFramework.testResults.count,
                passedResults: testingFramework.testResults.filter { $0.passed }.count
            )
            
            // Quick Test Actions
            VStack(spacing: 12) {
                DebugActionButton(
                    title: "Run Complete Test Suite",
                    subtitle: "Execute all 8 test categories",
                    icon: "play.circle.fill",
                    color: .green,
                    isLoading: testingFramework.isRunningTests
                ) {
                    Task {
                        await testingFramework.runCompleteTestSuite()
                    }
                }
                
                DebugActionButton(
                    title: "Intent Classification Test",
                    subtitle: "Test model accuracy on intent recognition",
                    icon: "brain.head.profile",
                    color: .blue
                ) {
                    Task {
                        await testingFramework.runIntentClassificationTest()
                    }
                }
                
                DebugActionButton(
                    title: "Performance Benchmark",
                    subtitle: "Measure model inference speed and memory",
                    icon: "speedometer",
                    color: .orange
                ) {
                    Task {
                        await testingFramework.runPerformanceBenchmarks()
                    }
                }
                
                DebugActionButton(
                    title: "Edge Case Testing",
                    subtitle: "Test model robustness with unusual inputs",
                    icon: "exclamationmark.triangle",
                    color: .yellow
                ) {
                    Task {
                        await testingFramework.runEdgeCaseTests()
                    }
                }
            }
            
            // Recent Test Results
            if !testingFramework.testResults.isEmpty {
                RecentTestResultsView(
                    results: Array(testingFramework.testResults.prefix(5)),
                    onViewAll: { showingTestResults = true }
                )
            }
        }
    }
    
    // MARK: - Model Validation Section
    private var modelValidationSection: some View {
        VStack(spacing: 16) {
            SectionHeaderView(
                title: "Model Validation",
                subtitle: "Pre-deployment validation and regression testing",
                icon: "checkmark.shield.fill"
            )
            
            // Validation Status
            ModelValidationStatusView(validator: modelValidator)
            
            // Validation Actions
            VStack(spacing: 12) {
                DebugActionButton(
                    title: "Validate Current Model",
                    subtitle: "Run full deployment readiness check",
                    icon: "checkmark.circle",
                    color: .green
                ) {
                    Task {
                        await validateCurrentModel()
                    }
                }
                
                DebugActionButton(
                    title: "Regression Testing",
                    subtitle: "Compare with previous model versions",
                    icon: "arrow.triangle.branch",
                    color: .blue
                ) {
                    Task {
                        await runRegressionTests()
                    }
                }
                
                DebugActionButton(
                    title: "Memory Profiling",
                    subtitle: "Analyze memory usage and detect leaks",
                    icon: "memorychip",
                    color: .purple
                ) {
                    Task {
                        await runMemoryProfiling()
                    }
                }
            }
        }
    }
    
    // MARK: - A/B Testing Section
    private var abTestingSection: some View {
        VStack(spacing: 16) {
            SectionHeaderView(
                title: "A/B Testing",
                subtitle: "Statistical model comparison and experimentation",
                icon: "chart.line.uptrend.xyaxis"
            )
            
            // Active Experiments
            ActiveExperimentsView(abTestingManager: abTestingManager)
            
            // Experiment Actions
            VStack(spacing: 12) {
                DebugActionButton(
                    title: "Create New Experiment",
                    subtitle: "Set up A/B test between model versions",
                    icon: "plus.circle",
                    color: .green
                ) {
                    await createNewExperiment()
                }
                
                DebugActionButton(
                    title: "Analyze Results",
                    subtitle: "Statistical analysis of current experiments",
                    icon: "chart.bar",
                    color: .blue
                ) {
                    await analyzeExperimentResults()
                }
                
                DebugActionButton(
                    title: "Export Data",
                    subtitle: "Export experiment data for analysis",
                    icon: "square.and.arrow.up",
                    color: .orange
                ) {
                    await exportExperimentData()
                }
            }
        }
    }
    
    // MARK: - Debugging Tools Section
    private var debuggingToolsSection: some View {
        VStack(spacing: 16) {
            SectionHeaderView(
                title: "Debug Tools",
                subtitle: "Model inspection and performance profiling",
                icon: "ladybug.fill"
            )
            
            // Debug Tool Actions
            VStack(spacing: 12) {
                DebugActionButton(
                    title: "Prediction Inspector",
                    subtitle: "Step-by-step model prediction analysis",
                    icon: "magnifyingglass.circle",
                    color: .blue
                ) {
                    await inspectModelPredictions()
                }
                
                DebugActionButton(
                    title: "Performance Profiler",
                    subtitle: "Real-time performance monitoring",
                    icon: "chart.xyaxis.line",
                    color: .green
                ) {
                    showingPerformanceMetrics = true
                }
                
                DebugActionButton(
                    title: "Decision Tree Visualizer",
                    subtitle: "Visualize model decision paths",
                    icon: "point.3.connected.trianglepath.dotted",
                    color: .purple
                ) {
                    await visualizeDecisionTree()
                }
                
                DebugActionButton(
                    title: "Confidence Analyzer",
                    subtitle: "Analyze prediction confidence scores",
                    icon: "percent",
                    color: .orange
                ) {
                    await analyzeConfidenceScores()
                }
            }
            
            // Debug Insights
            DebugInsightsView(debuggingTools: debuggingTools)
        }
    }
    
    // MARK: - Metrics Section
    private var metricsSection: some View {
        VStack(spacing: 16) {
            SectionHeaderView(
                title: "Performance Metrics",
                subtitle: "Real-time system performance monitoring",
                icon: "speedometer"
            )
            
            // Live Metrics
            LiveMetricsGridView()
            
            // Historical Charts
            MetricsChartsView()
        }
    }
    
    // MARK: - Logs Section
    private var logsSection: some View {
        VStack(spacing: 16) {
            SectionHeaderView(
                title: "Debug Logs",
                subtitle: "System logs and debugging information",
                icon: "doc.text.magnifyingglass"
            )
            
            // Log Actions
            VStack(spacing: 12) {
                DebugActionButton(
                    title: "View Debug Logs",
                    subtitle: "Real-time system and model logs",
                    icon: "doc.text",
                    color: .blue
                ) {
                    showingDebugLogs = true
                }
                
                DebugActionButton(
                    title: "Export Logs",
                    subtitle: "Export logs for external analysis",
                    icon: "square.and.arrow.up",
                    color: .green
                ) {
                    await exportDebugLogs()
                }
                
                DebugActionButton(
                    title: "Clear Logs",
                    subtitle: "Clear all stored debug logs",
                    icon: "trash",
                    color: .red
                ) {
                    clearDebugLogs()
                }
            }
            
            // Recent Log Entries
            RecentLogsView()
        }
    }
    
    // MARK: - Action Methods
    private func runAllTests() {
        isRunningTests = true
        Task {
            await testingFramework.runCompleteTestSuite()
            isRunningTests = false
        }
    }
    
    private func validateCurrentModel() async {
        // Simulate model validation
        let modelPath = Bundle.main.path(forResource: "MockModel", ofType: "mlmodel") ?? ""
        let _ = await modelValidator.validateModel(at: modelPath, modelName: "Current", targetVersion: "1.0")
    }
    
    private func runRegressionTests() async {
        await modelValidator.runRegressionTests(
            baselineModel: "baseline_v1.0",
            candidateModel: "current_v1.1",
            testSuite: []
        )
    }
    
    private func runMemoryProfiling() async {
        await modelValidator.profileMemoryUsage(modelName: "Current", testDuration: 60.0)
    }
    
    private func createNewExperiment() async {
        let modelA = ABTestingManager.ExperimentModel(
            name: "Current Model",
            version: "1.0",
            description: "Production model"
        )
        let modelB = ABTestingManager.ExperimentModel(
            name: "Candidate Model", 
            version: "1.1",
            description: "Improved model with better accuracy"
        )
        
        let trafficSplit = ABTestingManager.TrafficSplit(
            controlPercentage: 0.5,
            treatmentPercentage: 0.5,
            rampUpSchedule: nil
        )
        
        let successMetrics = [
            ABTestingManager.SuccessMetric(
                name: "accuracy",
                type: .conversion,
                targetValue: 0.95,
                minimumDetectableEffect: 0.02
            )
        ]
        
        let _ = await abTestingManager.createExperiment(
            name: "Model Accuracy Test",
            modelA: modelA,
            modelB: modelB,
            trafficSplit: trafficSplit,
            successMetrics: successMetrics
        )
    }
    
    private func analyzeExperimentResults() async {
        await abTestingManager.generateExperimentReport(
            experimentId: "sample_experiment",
            includeRawData: true
        )
    }
    
    private func exportExperimentData() async {
        await abTestingManager.exportExperimentData(
            experimentId: "sample_experiment",
            format: .csv
        )
    }
    
    private func inspectModelPredictions() async {
        let _ = await debuggingTools.inspectPrediction(
            input: "What's the weather like?",
            modelName: "Current"
        )
    }
    
    private func visualizeDecisionTree() async {
        let _ = await debuggingTools.visualizeDecisionTree(
            modelName: "Current",
            maxDepth: 10
        )
    }
    
    private func analyzeConfidenceScores() async {
        let testCases = [
            (input: "What time is it?", expectedIntent: "time"),
            (input: "Send an email", expectedIntent: "email"),
            (input: "Play music", expectedIntent: "media")
        ]
        
        let _ = await debuggingTools.analyzeConfidence(
            modelName: "Current",
            testCases: testCases
        )
    }
    
    private func exportDebugLogs() async {
        // Implementation for exporting debug logs
        print("Exporting debug logs...")
    }
    
    private func clearDebugLogs() {
        // Implementation for clearing debug logs
        print("Clearing debug logs...")
    }
}

// MARK: - Supporting Views

struct SectionHeaderView: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct DebugActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: color))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: icon)
                            .foregroundColor(color)
                            .font(.system(size: 18, weight: .medium))
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }
}

struct TestStatusCardView: View {
    let title: String
    let isRunning: Bool
    let progress: Double
    let totalResults: Int
    let passedResults: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isRunning {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                        
                        Text("Running...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if isRunning && progress > 0 {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .background(Color.white.opacity(0.2))
            }
            
            if totalResults > 0 {
                HStack {
                    Label("\(passedResults) passed", systemImage: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Spacer()
                    
                    Label("\(totalResults - passedResults) failed", systemImage: "xmark.circle")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Spacer()
                    
                    Text("Total: \(totalResults)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// Placeholder views for complex components
struct ModelValidationStatusView: View {
    let validator: ModelValidator
    
    var body: some View {
        Text("Model validation status placeholder")
            .foregroundColor(.white.opacity(0.7))
            .padding()
    }
}

struct ActiveExperimentsView: View {
    let abTestingManager: ABTestingManager
    
    var body: some View {
        Text("Active experiments placeholder")
            .foregroundColor(.white.opacity(0.7))
            .padding()
    }
}

struct DebugInsightsView: View {
    let debuggingTools: MLDebuggingTools
    
    var body: some View {
        Text("Debug insights placeholder")
            .foregroundColor(.white.opacity(0.7))
            .padding()
    }
}

struct LiveMetricsGridView: View {
    var body: some View {
        Text("Live metrics placeholder")
            .foregroundColor(.white.opacity(0.7))
            .padding()
    }
}

struct MetricsChartsView: View {
    var body: some View {
        Text("Metrics charts placeholder")
            .foregroundColor(.white.opacity(0.7))
            .padding()
    }
}

struct RecentLogsView: View {
    var body: some View {
        Text("Recent logs placeholder")
            .foregroundColor(.white.opacity(0.7))
            .padding()
    }
}

struct RecentTestResultsView: View {
    let results: [MLTestingFramework.TestResult]
    let onViewAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Results")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("View All", action: onViewAll)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            ForEach(results, id: \.testName) { result in
                HStack {
                    Image(systemName: result.passed ? "checkmark.circle" : "xmark.circle")
                        .foregroundColor(result.passed ? .green : .red)
                    
                    Text(result.testName)
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(String(format: "%.2fs", result.executionTime))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// Detail view placeholders
struct TestResultsDetailView: View {
    let results: [MLTestingFramework.TestResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Test results detail view")
                .navigationTitle("Test Results")
                .toolbar {
                    Button("Done") { dismiss() }
                }
        }
    }
}

struct ModelDetailsView: View {
    let validator: ModelValidator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Model details view")
                .navigationTitle("Model Details")
                .toolbar {
                    Button("Done") { dismiss() }
                }
        }
    }
}

struct PerformanceMetricsView: View {
    let debuggingTools: MLDebuggingTools
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Performance metrics view")
                .navigationTitle("Performance Metrics")
                .toolbar {
                    Button("Done") { dismiss() }
                }
        }
    }
}

struct DebugLogsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Debug logs view")
                .navigationTitle("Debug Logs")
                .toolbar {
                    Button("Done") { dismiss() }
                }
        }
    }
}

#Preview {
    if #available(iOS 15.0, *) {
        DebugMenuView()
    } else {
        Text("Requires iOS 15.0+")
    }
}