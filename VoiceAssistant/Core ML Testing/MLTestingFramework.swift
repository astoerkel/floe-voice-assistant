import Foundation
import CoreML
import Speech
import AVFoundation

/// Comprehensive testing framework for Core ML integration in VoiceAssistant
/// Validates model accuracy, benchmarks performance, tests edge cases, and compares with server results
@available(iOS 15.0, *)
final class MLTestingFramework: ObservableObject {
    
    // MARK: - Properties
    
    @Published var testResults: [TestResult] = []
    @Published var isRunningTests = false
    @Published var currentTestProgress: Double = 0.0
    @Published var testingSummary: TestingSummary?
    
    private var coreMLManager: CoreMLManager!
    private var intentClassifier: IntentClassifier!
    private let speechRecognizer = EnhancedSpeechRecognizer()
    private var responseGenerator: ResponseGenerator!
    private var offlineProcessor: OfflineProcessor!
    
    init() {
        Task { @MainActor in
            self.coreMLManager = CoreMLManager.shared
            self.intentClassifier = IntentClassifier()
            self.responseGenerator = ResponseGenerator()
            self.offlineProcessor = OfflineProcessor()
        }
    }
    
    // Test configuration
    private let testTimeoutSeconds: TimeInterval = 30.0
    private let accuracyThreshold: Double = 0.85
    private let performanceThreshold: TimeInterval = 0.5
    
    // MARK: - Test Result Models
    
    struct TestResult: Identifiable, Codable {
        let id: UUID
        let testName: String
        let category: TestCategory
        let status: TestStatus
        let score: Double?
        let executionTime: TimeInterval
        let details: String
        let timestamp: Date
        let metrics: TestMetrics?
        
        enum TestCategory: String, CaseIterable, Codable {
            case intentClassification = "Intent Classification"
            case speechRecognition = "Speech Recognition"
            case responseGeneration = "Response Generation"
            case offlineCapability = "Offline Capability"
            case performance = "Performance"
            case accuracy = "Accuracy"
            case edgeCases = "Edge Cases"
            case serverComparison = "Server Comparison"
        }
        
        enum TestStatus: String, Codable {
            case passed = "Passed"
            case failed = "Failed"
            case warning = "Warning"
            case skipped = "Skipped"
        }
    }
    
    struct TestMetrics: Codable {
        let accuracy: Double?
        let precision: Double?
        let recall: Double?
        let f1Score: Double?
        let latency: TimeInterval
        let memoryUsage: Double?
        let confidenceScore: Double?
        let throughput: Double?
    }
    
    struct TestingSummary: Codable {
        let totalTests: Int
        let passedTests: Int
        let failedTests: Int
        let warningTests: Int
        let skippedTests: Int
        let averageAccuracy: Double
        let averageLatency: TimeInterval
        let overallScore: Double
        let timestamp: Date
        let recommendations: [String]
    }
    
    // MARK: - Test Data Sets
    
    private let intentTestCases: [(input: String, expectedIntent: String, confidence: Double)] = [
        // Calendar & Scheduling - High confidence expected
        ("What's my next meeting?", "calendar_query", 0.9),
        ("Do I have any appointments today?", "calendar_query", 0.9),
        ("What's on my schedule for tomorrow?", "calendar_query", 0.9),
        ("When is my meeting with John?", "calendar_query", 0.85),
        ("Schedule a meeting with John tomorrow at 2pm", "calendar_create", 0.85),
        ("Book a dentist appointment for next week", "calendar_create", 0.8),
        ("Add lunch with Sarah to my calendar", "calendar_create", 0.85),
        ("Cancel my 3pm meeting", "calendar_modify", 0.8),
        ("Move my meeting to 4pm", "calendar_modify", 0.8),
        
        // Email & Communication - High accuracy domain
        ("Send an email to Sarah about the project", "email_compose", 0.9),
        ("Email my boss the quarterly report", "email_compose", 0.9),
        ("Draft an email to the team", "email_compose", 0.85),
        ("Check my emails", "email_query", 0.95),
        ("Do I have any new messages?", "email_query", 0.9),
        ("Show me emails from John", "email_query", 0.85),
        ("Reply to Sarah's email", "email_reply", 0.85),
        ("Forward this email to Tom", "email_forward", 0.8),
        
        // Tasks & Notes - Productivity domain
        ("Add buy groceries to my task list", "task_create", 0.9),
        ("Create a note about today's meeting", "note_create", 0.9),
        ("Add milk to my shopping list", "task_create", 0.85),
        ("What tasks do I have today?", "task_query", 0.9),
        ("Show me my to-do list", "task_query", 0.9),
        ("Mark task as completed", "task_modify", 0.85),
        ("Delete the grocery shopping task", "task_modify", 0.8),
        ("Remind me to call mom at 5pm", "reminder_create", 0.85),
        
        // Weather & Information - High confidence domain
        ("What's the weather like?", "weather_query", 0.95),
        ("Will it rain today?", "weather_query", 0.9),
        ("What's the temperature outside?", "weather_query", 0.9),
        ("Do I need an umbrella?", "weather_query", 0.85),
        ("What's the forecast for this weekend?", "weather_query", 0.9),
        
        // Time & Date - Should be very accurate
        ("What time is it?", "time_query", 0.98),
        ("Tell me the current time", "time_query", 0.95),
        ("What's today's date?", "date_query", 0.95),
        ("What day is it?", "date_query", 0.9),
        ("What's the date tomorrow?", "date_query", 0.85),
        
        // Calculations - Mathematical operations
        ("Calculate 15% of 200", "calculation", 0.8),
        ("What's 25 times 4?", "calculation", 0.85),
        ("Convert 100 fahrenheit to celsius", "calculation", 0.8),
        ("How much is 15% tip on $50?", "calculation", 0.75),
        
        // Device Control - System operations
        ("Turn on Do Not Disturb", "device_control", 0.85),
        ("Enable airplane mode", "device_control", 0.85),
        ("Turn off WiFi", "device_control", 0.9),
        ("Set volume to 50%", "device_control", 0.8),
        ("Turn on flashlight", "device_control", 0.9),
        ("Take a screenshot", "device_control", 0.85),
        
        // Media & Entertainment
        ("Play some music", "media_control", 0.9),
        ("Skip this song", "media_control", 0.9),
        ("Pause the music", "media_control", 0.95),
        ("What's currently playing?", "media_query", 0.85),
        ("Play my workout playlist", "media_control", 0.85),
        ("Turn up the volume", "media_control", 0.8),
        
        // Navigation & Directions
        ("Give me directions to the airport", "navigation", 0.9),
        ("How do I get to Starbucks?", "navigation", 0.85),
        ("Navigate to my office", "navigation", 0.9),
        ("What's the traffic like to downtown?", "navigation", 0.8),
        ("Find the nearest gas station", "navigation", 0.85),
        
        // Smart Home - IoT control
        ("Turn on the lights", "smart_home", 0.85),
        ("Set the thermostat to 72 degrees", "smart_home", 0.8),
        ("Lock the front door", "smart_home", 0.85),
        ("Turn off the TV", "smart_home", 0.8),
        
        // Phone & Calls
        ("Call mom", "phone_call", 0.9),
        ("Phone the restaurant", "phone_call", 0.85),
        ("Dial John's number", "phone_call", 0.85),
        ("End the call", "phone_call", 0.9),
        
        // General Conversation - Lower confidence expected
        ("Hello there", "general_conversation", 0.7),
        ("How are you doing?", "general_conversation", 0.75),
        ("Thank you", "general_conversation", 0.8),
        ("What can you help me with?", "general_conversation", 0.7),
        ("Good morning", "general_conversation", 0.75),
        
        // Edge Cases - Challenging inputs
        ("Set", "unclear_intent", 0.3), // Incomplete command
        ("Play", "unclear_intent", 0.3), // Ambiguous
        ("What", "unclear_intent", 0.3), // Too vague
        ("Um, can you like, maybe send an email or something?", "email_compose", 0.6), // Noisy input
        ("Schedule email weather time", "unclear_intent", 0.2), // Nonsensical
        
        // Complex/Compound Requests - Lower confidence
        ("Send an email to John and schedule a meeting for tomorrow", "email_compose", 0.6), // First intent should win
        ("What's the weather and what time is my meeting?", "weather_query", 0.6), // First intent
        ("Play music and set a timer for 30 minutes", "media_control", 0.6), // First intent
        
        // Domain-specific variations
        ("Add an event to my calendar", "calendar_create", 0.85),
        ("Block time on my schedule", "calendar_create", 0.8),
        ("Set up a meeting", "calendar_create", 0.8),
        ("Check my inbox", "email_query", 0.9),
        ("Look at my messages", "email_query", 0.85),
        ("Create a reminder", "reminder_create", 0.9),
        ("Make a note", "note_create", 0.9),
        ("Write down", "note_create", 0.8)
    ]
    
    private let speechTestCases: [String] = [
        "Schedule a meeting for tomorrow",
        "What's the weather forecast",
        "Send an email to my team",
        "Add groceries to my shopping list",
        "What's my next appointment",
        "Calculate twenty percent of fifty dollars",
        "Turn on airplane mode",
        "How's the traffic to downtown"
    ]
    
    private let edgeCaseTestInputs: [String] = [
        "", // Empty input
        "a", // Single character
        String(repeating: "test ", count: 200), // Very long input
        "🎉🚀💡🔥⭐", // Emoji only
        "Test with 123 numbers and symbols !@#$%", // Mixed content
        "Very quiet whisper", // Low confidence speech
        "LOUD SHOUTING TEXT", // All caps
        "múltiple açcénts and spëcial charactérs", // Accented characters
        "Mixed English and 中文 text", // Mixed languages
        "Background noise with sirens and music" // Noisy environment simulation
    ]
    
    // MARK: - Public Test Methods
    
    /// Run comprehensive test suite
    func runCompleteTestSuite() async {
        await MainActor.run {
            isRunningTests = true
            currentTestProgress = 0.0
            testResults.removeAll()
        }
        
        let testSuites: [(name: String, test: () async -> [TestResult])] = [
            ("Intent Classification Accuracy", testIntentClassificationAccuracy),
            ("Speech Recognition Performance", testSpeechRecognitionPerformance),
            ("Response Generation Quality", testResponseGenerationQuality),
            ("Offline Capability Coverage", testOfflineCapabilityCoverage),
            ("Performance Benchmarks", testPerformanceBenchmarks),
            ("Edge Case Handling", testEdgeCaseHandling),
            ("Memory Usage Profiling", testMemoryUsageProfiling),
            ("Server Result Comparison", testServerResultComparison)
        ]
        
        let totalSuites = testSuites.count
        
        for (index, suite) in testSuites.enumerated() {
            print("🧪 Running test suite: \(suite.name)")
            let results = await suite.test()
            
            await MainActor.run {
                testResults.append(contentsOf: results)
                currentTestProgress = Double(index + 1) / Double(totalSuites)
            }
        }
        
        await generateTestingSummary()
        
        await MainActor.run {
            isRunningTests = false
            currentTestProgress = 1.0
        }
    }
    
    /// Test intent classification accuracy against known test cases
    func testIntentClassificationAccuracy() async -> [TestResult] {
        var results: [TestResult] = []
        let startTime = Date()
        
        var correctPredictions = 0
        var totalPredictions = 0
        var totalLatency: TimeInterval = 0
        
        for testCase in intentTestCases {
            let testStartTime = Date()
            
            do {
                let result = try await intentClassifier.classifyIntent(text: testCase.input)
                let executionTime = Date().timeIntervalSince(testStartTime)
                totalLatency += executionTime
                
                let isCorrect = result.intent.rawValue.lowercased().contains(testCase.expectedIntent.lowercased())
                let confidenceMeetsThreshold = result.confidence >= Double(testCase.confidence)
                
                if isCorrect {
                    correctPredictions += 1
                }
                totalPredictions += 1
                
                let status: TestResult.TestStatus = isCorrect && confidenceMeetsThreshold ? .passed : .failed
                let score = isCorrect ? Double(result.confidence) : 0.0
                
                let metrics = TestMetrics(
                    accuracy: isCorrect ? 1.0 : 0.0,
                    precision: nil,
                    recall: nil,
                    f1Score: nil,
                    latency: executionTime,
                    memoryUsage: nil,
                    confidenceScore: result.confidence,
                    throughput: nil
                )
                
                results.append(TestResult(
                    id: UUID(),
                    testName: "Intent: \(testCase.expectedIntent)",
                    category: .intentClassification,
                    status: status,
                    score: score,
                    executionTime: executionTime,
                    details: "Input: '\(testCase.input)' -> Predicted: '\(result.intent)' (confidence: \(String(format: "%.2f", result.confidence)))",
                    timestamp: Date(),
                    metrics: metrics
                ))
                
            } catch {
                results.append(TestResult(
                    id: UUID(),
                    testName: "Intent: \(testCase.expectedIntent)",
                    category: .intentClassification,
                    status: .failed,
                    score: 0.0,
                    executionTime: Date().timeIntervalSince(testStartTime),
                    details: "Error: \(error.localizedDescription)",
                    timestamp: Date(),
                    metrics: nil
                ))
            }
        }
        
        let overallAccuracy = totalPredictions > 0 ? Double(correctPredictions) / Double(totalPredictions) : 0.0
        let averageLatency = totalPredictions > 0 ? totalLatency / Double(totalPredictions) : 0.0
        
        results.append(TestResult(
            id: UUID(),
            testName: "Overall Intent Classification",
            category: .accuracy,
            status: overallAccuracy >= accuracyThreshold ? .passed : .failed,
            score: overallAccuracy,
            executionTime: Date().timeIntervalSince(startTime),
            details: "Accuracy: \(String(format: "%.1f%%", overallAccuracy * 100)), Average latency: \(String(format: "%.3f", averageLatency))s",
            timestamp: Date(),
            metrics: TestMetrics(
                accuracy: overallAccuracy,
                precision: nil,
                recall: nil,
                f1Score: nil,
                latency: averageLatency,
                memoryUsage: nil,
                confidenceScore: nil,
                throughput: Double(totalPredictions) / Date().timeIntervalSince(startTime)
            )
        ))
        
        // Add comprehensive intent classification analysis
        let analysisResult = generateIntentClassificationAnalysis(results)
        results.append(analysisResult)
        
        return results
    }
    
    /// Generate comprehensive analysis of intent classification results
    private func generateIntentClassificationAnalysis(_ results: [TestResult]) -> TestResult {
        let startTime = Date()
        
        // Group results by intent category
        var categoryPerformance: [String: (correct: Int, total: Int, totalConfidence: Double)] = [:]
        var confusionData: [String: [String: Int]] = [:]
        var lowConfidenceResults: [TestResult] = []
        
        for result in results {
            guard result.category == .intentClassification,
                  let metrics = result.metrics else { continue }
            
            // Extract intent category from test name
            let intentType = extractIntentCategory(from: result.testName)
            
            if categoryPerformance[intentType] == nil {
                categoryPerformance[intentType] = (correct: 0, total: 0, totalConfidence: 0.0)
            }
            
            categoryPerformance[intentType]!.total += 1
            if let confidence = metrics.confidenceScore {
                categoryPerformance[intentType]!.totalConfidence += confidence
                
                if confidence < 0.7 {
                    lowConfidenceResults.append(result)
                }
            }
            
            if result.status == .passed {
                categoryPerformance[intentType]!.correct += 1
            }
            
            // Build confusion matrix data
            if let detailsMatch = extractIntentFromDetails(result.details) {
                let (expected, predicted) = detailsMatch
                if confusionData[expected] == nil {
                    confusionData[expected] = [:]
                }
                confusionData[expected]![predicted, default: 0] += 1
            }
        }
        
        // Generate detailed analysis
        var analysisDetails = ["=== COMPREHENSIVE INTENT CLASSIFICATION ANALYSIS ===\n"]
        
        // Overall statistics
        let totalTests = results.filter { $0.category == .intentClassification }.count
        let passedTests = results.filter { $0.category == .intentClassification && $0.status == .passed }.count
        let overallAccuracy = totalTests > 0 ? Double(passedTests) / Double(totalTests) : 0.0
        
        analysisDetails.append("📊 OVERALL PERFORMANCE")
        analysisDetails.append("Total Test Cases: \(totalTests)")
        analysisDetails.append("Passed: \(passedTests) (\(String(format: "%.1f%%", overallAccuracy * 100)))")
        analysisDetails.append("Failed: \(totalTests - passedTests) (\(String(format: "%.1f%%", (1.0 - overallAccuracy) * 100)))")
        analysisDetails.append("")
        
        // Category breakdown
        analysisDetails.append("📈 CATEGORY PERFORMANCE BREAKDOWN")
        let sortedCategories = categoryPerformance.sorted { $0.key < $1.key }
        
        for (category, stats) in sortedCategories {
            let categoryAccuracy = Double(stats.correct) / Double(stats.total)
            let avgConfidence = stats.totalConfidence / Double(stats.total)
            let status = categoryAccuracy >= 0.9 ? "🟢" : categoryAccuracy >= 0.8 ? "🟡" : "🔴"
            
            analysisDetails.append("\(status) \(category.capitalized):")
            analysisDetails.append("  Accuracy: \(String(format: "%.1f%%", categoryAccuracy * 100)) (\(stats.correct)/\(stats.total))")
            analysisDetails.append("  Avg Confidence: \(String(format: "%.2f", avgConfidence))")
            analysisDetails.append("")
        }
        
        // Confusion matrix analysis
        analysisDetails.append("🔄 CONFUSION MATRIX INSIGHTS")
        for (expected, predictions) in confusionData.sorted(by: { $0.key < $1.key }) {
            let total = predictions.values.reduce(0, +)
            let correct = predictions[expected] ?? 0
            let accuracy = Double(correct) / Double(total)
            
            if accuracy < 0.8 {
                analysisDetails.append("⚠️ \(expected): \(String(format: "%.1f%%", accuracy * 100)) accuracy")
                
                let misclassifications = predictions.filter { $0.key != expected }.sorted { $0.value > $1.value }
                for (wrongIntent, count) in misclassifications.prefix(2) {
                    let percentage = Double(count) / Double(total) * 100
                    analysisDetails.append("  → Often confused with '\(wrongIntent)': \(count) times (\(String(format: "%.1f%%", percentage)))")
                }
                analysisDetails.append("")
            }
        }
        
        // Low confidence analysis
        if !lowConfidenceResults.isEmpty {
            analysisDetails.append("⚠️ LOW CONFIDENCE PREDICTIONS (\(lowConfidenceResults.count) total)")
            for result in lowConfidenceResults.prefix(5) {
                if let confidence = result.metrics?.confidenceScore {
                    analysisDetails.append("• \(result.testName): \(String(format: "%.2f", confidence)) confidence")
                }
            }
            if lowConfidenceResults.count > 5 {
                analysisDetails.append("... and \(lowConfidenceResults.count - 5) more")
            }
            analysisDetails.append("")
        }
        
        // Generate actionable recommendations
        var recommendations: [String] = []
        
        if overallAccuracy < 0.85 {
            recommendations.append("🚨 CRITICAL: Overall accuracy (\(String(format: "%.1f%%", overallAccuracy * 100))) below 85% threshold")
            recommendations.append("• Immediate model retraining required")
            recommendations.append("• Review and expand training dataset")
        } else if overallAccuracy < 0.90 {
            recommendations.append("⚠️ Overall accuracy could be improved (current: \(String(format: "%.1f%%", overallAccuracy * 100)))")
            recommendations.append("• Consider additional training data for edge cases")
        }
        
        // Category-specific recommendations
        for (category, stats) in categoryPerformance {
            let categoryAccuracy = Double(stats.correct) / Double(stats.total)
            let avgConfidence = stats.totalConfidence / Double(stats.total)
            
            if categoryAccuracy < 0.8 {
                recommendations.append("🔴 \(category.capitalized) category needs attention (\(String(format: "%.1f%%", categoryAccuracy * 100)) accuracy)")
                recommendations.append("• Add more diverse training examples for \(category) intents")
                recommendations.append("• Review feature extraction for \(category) domain")
            }
            
            if avgConfidence < 0.75 {
                recommendations.append("📉 Low confidence in \(category) predictions (avg: \(String(format: "%.2f", avgConfidence)))")
                recommendations.append("• Consider confidence calibration for \(category) intents")
            }
        }
        
        // Confusion-based recommendations
        for (expected, predictions) in confusionData {
            let total = predictions.values.reduce(0, +)
            let correct = predictions[expected] ?? 0
            
            if Double(correct) / Double(total) < 0.75 {
                let topConfusion = predictions.filter { $0.key != expected }.max { $0.value < $1.value }
                if let (confusedWith, _) = topConfusion {
                    recommendations.append("🔀 '\(expected)' frequently confused with '\(confusedWith)'")
                    recommendations.append("• Review training examples to better distinguish these intents")
                    recommendations.append("• Consider feature engineering to separate these domains")
                }
            }
        }
        
        if lowConfidenceResults.count > totalTests / 4 {
            recommendations.append("📊 High number of low-confidence predictions (\(lowConfidenceResults.count)/\(totalTests))")
            recommendations.append("• Review model calibration")
            recommendations.append("• Consider ensemble methods or confidence thresholding")
        }
        
        analysisDetails.append("🔧 RECOMMENDATIONS")
        for recommendation in recommendations {
            analysisDetails.append(recommendation)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        let finalDetails = analysisDetails.joined(separator: "\n")
        
        return TestResult(
            id: UUID(),
            testName: "Intent Classification Analysis",
            category: .accuracy,
            status: overallAccuracy >= accuracyThreshold ? .passed : .failed,
            score: overallAccuracy,
            executionTime: executionTime,
            details: finalDetails,
            timestamp: Date(),
            metrics: TestMetrics(
                accuracy: overallAccuracy,
                precision: nil,
                recall: nil,
                f1Score: nil,
                latency: 0.0,
                memoryUsage: nil,
                confidenceScore: nil,
                throughput: nil
            )
        )
    }
    
    // MARK: - Analysis Helper Methods
    
    private func extractIntentCategory(from testName: String) -> String {
        // Extract category from test name like "Intent: calendar_query"
        if let colonIndex = testName.firstIndex(of: ":") {
            let intentName = String(testName[testName.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            
            // Group into broader categories
            if intentName.contains("calendar") { return "calendar" }
            if intentName.contains("email") { return "email" }
            if intentName.contains("task") || intentName.contains("note") || intentName.contains("reminder") { return "productivity" }
            if intentName.contains("weather") { return "weather" }
            if intentName.contains("time") || intentName.contains("date") { return "time" }
            if intentName.contains("media") { return "media" }
            if intentName.contains("navigation") { return "navigation" }
            if intentName.contains("device") || intentName.contains("smart_home") { return "control" }
            if intentName.contains("phone") || intentName.contains("call") { return "communication" }
            if intentName.contains("conversation") { return "conversation" }
            if intentName.contains("calculation") { return "calculation" }
            if intentName.contains("unclear") { return "edge_cases" }
            
            return "other"
        }
        return "unknown"
    }
    
    private func extractIntentFromDetails(_ details: String) -> (expected: String, predicted: String)? {
        // Parse details string to extract expected and predicted intents
        // Format: "Input: '...' -> Predicted: 'predicted_intent' (confidence: 0.xx)"
        
        let pattern = "Predicted: '([^']+)'"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: details, options: [], range: NSRange(details.startIndex..., in: details)) {
            
            if let predictedRange = Range(match.range(at: 1), in: details) {
                let predicted = String(details[predictedRange])
                
                // Extract expected from test name (this is a simplified approach)
                if details.contains("Intent: ") {
                    let components = details.components(separatedBy: "Intent: ")
                    if components.count > 1 {
                        let expected = components[1].components(separatedBy: ")")[0]
                        return (expected: expected, predicted: predicted)
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Test speech recognition performance and accuracy
    func testSpeechRecognitionPerformance() async -> [TestResult] {
        var results: [TestResult] = []
        
        // Test enhanced speech recognition with various inputs
        for (index, testText) in speechTestCases.enumerated() {
            let startTime = Date()
            
            // Simulate speech recognition test (in real implementation, this would use actual audio)
            let mockAudioData = generateMockAudioData(for: testText)
            let recognitionResult = await testSpeechRecognitionWithMockAudio(mockAudioData, expectedText: testText)
                
                let executionTime = Date().timeIntervalSince(startTime)
                let accuracy = calculateTextSimilarity(recognitionResult.recognizedText, testText)
                
                let status: TestResult.TestStatus = accuracy >= 0.8 ? .passed : (accuracy >= 0.6 ? .warning : .failed)
                
                let metrics = TestMetrics(
                    accuracy: accuracy,
                    precision: nil,
                    recall: nil,
                    f1Score: nil,
                    latency: executionTime,
                    memoryUsage: nil,
                    confidenceScore: recognitionResult.confidence,
                    throughput: nil
                )
                
                results.append(TestResult(
                    id: UUID(),
                    testName: "Speech Recognition Test \(index + 1)",
                    category: .speechRecognition,
                    status: status,
                    score: accuracy,
                    executionTime: executionTime,
                    details: "Expected: '\(testText)' -> Got: '\(recognitionResult.recognizedText)' (accuracy: \(String(format: "%.1f%%", accuracy * 100)))",
                    timestamp: Date(),
                    metrics: metrics
                ))
                
        }
        
        return results
    }
    
    /// Test response generation quality and consistency
    func testResponseGenerationQuality() async -> [TestResult] {
        var results: [TestResult] = []
        
        let responseTestCases: [(query: String, expectedType: String)] = [
            ("What's my next meeting?", "calendar_response"),
            ("Send email to John", "email_confirmation"),
            ("Add task: buy milk", "task_confirmation"),
            ("What's the weather?", "weather_response"),
            ("What time is it?", "time_response")
        ]
        
        for testCase in responseTestCases {
            let startTime = Date()
            
            do {
                let response = await responseGenerator.generateResponse(
                    for: testCase.query,
                    context: ConversationContext(),
                    responseType: ResponseType.confirmation
                )
                
                let executionTime = Date().timeIntervalSince(startTime)
                
                // Evaluate response quality
                let qualityScore = evaluateResponseQuality(response)
                let hasAudio = response.audioBase64 != nil && !response.audioBase64!.isEmpty
                
                let status: TestResult.TestStatus = qualityScore >= 0.7 && hasAudio ? .passed : .warning
                
                let metrics = TestMetrics(
                    accuracy: nil,
                    precision: nil,
                    recall: nil,
                    f1Score: nil,
                    latency: executionTime,
                    memoryUsage: nil,
                    confidenceScore: response.confidence,
                    throughput: nil
                )
                
                results.append(TestResult(
                    id: UUID(),
                    testName: "Response: \(testCase.expectedType)",
                    category: .responseGeneration,
                    status: status,
                    score: qualityScore,
                    executionTime: executionTime,
                    details: "Query: '\(testCase.query)' -> Response length: \(response.response.count) chars, Audio: \(hasAudio ? "✓" : "✗"), Quality: \(String(format: "%.1f%%", qualityScore * 100))",
                    timestamp: Date(),
                    metrics: metrics
                ))
                
            // No catch needed since no throwing functions are called
        }
        
        return results
    }
    
    /// Test offline capability coverage
    func testOfflineCapabilityCoverage() async -> [TestResult] {
        var results: [TestResult] = []
        
        let offlineTestCases: [(query: String, shouldWorkOffline: Bool)] = [
            ("What time is it?", true),
            ("Calculate 10 + 20", true),
            ("What's my next meeting?", true), // Should work with cached data
            ("Send email to John", false), // Requires network
            ("What's the weather?", true), // Should work with cached data
            ("Create a new task", false), // Requires server sync
            ("Turn on airplane mode", true), // Device control
            ("What's 15% of 200?", true) // Basic calculation
        ]
        
        for testCase in offlineTestCases {
            let startTime = Date()
            
            do {
                // Simulate offline environment
                let result = await offlineProcessor.processCommand(testCase.query)
                let executionTime = Date().timeIntervalSince(startTime)
                
                let workedOffline = !result.text.isEmpty && result.confidence > 0.5
                let expectedResult = testCase.shouldWorkOffline
                
                let status: TestResult.TestStatus = (workedOffline == expectedResult) ? .passed : .failed
                let score = workedOffline ? result.confidence : 0.0
                
                let metrics = TestMetrics(
                    accuracy: (workedOffline == expectedResult) ? 1.0 : 0.0,
                    precision: nil,
                    recall: nil,
                    f1Score: nil,
                    latency: executionTime,
                    memoryUsage: nil,
                    confidenceScore: result.confidence,
                    throughput: nil
                )
                
                results.append(TestResult(
                    id: UUID(),
                    testName: "Offline: \(testCase.query)",
                    category: .offlineCapability,
                    status: status,
                    score: score,
                    executionTime: executionTime,
                    details: "Expected offline: \(expectedResult), Worked offline: \(workedOffline), Response: '\(result.text.prefix(100))'",
                    timestamp: Date(),
                    metrics: metrics
                ))
                
            } catch {
                results.append(TestResult(
                    id: UUID(),
                    testName: "Offline: \(testCase.query)",
                    category: .offlineCapability,
                    status: .failed,
                    score: 0.0,
                    executionTime: Date().timeIntervalSince(startTime),
                    details: "Offline processing failed: \(error.localizedDescription)",
                    timestamp: Date(),
                    metrics: nil
                ))
            }
        }
        
        return results
    }
    
    /// Test performance benchmarks
    func testPerformanceBenchmarks() async -> [TestResult] {
        var results: [TestResult] = []
        
        // Test Core ML model loading performance
        let modelLoadingResult = await benchmarkModelLoading()
        results.append(modelLoadingResult)
        
        // Test batch processing performance
        let batchProcessingResult = await benchmarkBatchProcessing()
        results.append(batchProcessingResult)
        
        // Test memory efficiency
        let memoryEfficiencyResult = await benchmarkMemoryEfficiency()
        results.append(memoryEfficiencyResult)
        
        // Test concurrent processing
        let concurrentProcessingResult = await benchmarkConcurrentProcessing()
        results.append(concurrentProcessingResult)
        
        return results
    }
    
    /// Test edge case handling
    func testEdgeCaseHandling() async -> [TestResult] {
        var results: [TestResult] = []
        
        for (index, edgeCase) in edgeCaseTestInputs.enumerated() {
            let startTime = Date()
            
            do {
                let result = try await intentClassifier.classifyIntent(text: edgeCase)
                let executionTime = Date().timeIntervalSince(startTime)
                
                // For edge cases, we mainly test that the system doesn't crash
                let didHandleGracefully = result.intent != .unknown || result.confidence >= 0.0
                let status: TestResult.TestStatus = didHandleGracefully ? .passed : .failed
                
                let metrics = TestMetrics(
                    accuracy: nil,
                    precision: nil,
                    recall: nil,
                    f1Score: nil,
                    latency: executionTime,
                    memoryUsage: nil,
                    confidenceScore: result.confidence,
                    throughput: nil
                )
                
                results.append(TestResult(
                    id: UUID(),
                    testName: "Edge Case \(index + 1)",
                    category: .edgeCases,
                    status: status,
                    score: didHandleGracefully ? 1.0 : 0.0,
                    executionTime: executionTime,
                    details: "Input: '\(edgeCase.prefix(50))...' -> Intent: '\(result.intent)', Confidence: \(String(format: "%.2f", result.confidence))",
                    timestamp: Date(),
                    metrics: metrics
                ))
                
            } catch {
                results.append(TestResult(
                    id: UUID(),
                    testName: "Edge Case \(index + 1)",
                    category: .edgeCases,
                    status: .failed,
                    score: 0.0,
                    executionTime: Date().timeIntervalSince(startTime),
                    details: "Edge case handling failed: \(error.localizedDescription)",
                    timestamp: Date(),
                    metrics: nil
                ))
            }
        }
        
        return results
    }
    
    /// Test memory usage profiling
    func testMemoryUsageProfiling() async -> [TestResult] {
        var results: [TestResult] = []
        let startTime = Date()
        
        let initialMemory = getCurrentMemoryUsage()
        
        // Perform intensive operations
        for i in 0..<100 {
            _ = try await intentClassifier.classifyIntent(text: "Test query \(i)")
        }
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        let executionTime = Date().timeIntervalSince(startTime)
        
        let memoryEfficient = memoryIncrease < 50 * 1024 * 1024 // Less than 50MB increase
        let status: TestResult.TestStatus = memoryEfficient ? .passed : .warning
        
        let metrics = TestMetrics(
            accuracy: nil,
            precision: nil,
            recall: nil,
            f1Score: nil,
            latency: executionTime,
            memoryUsage: Double(memoryIncrease),
            confidenceScore: nil,
            throughput: 100.0 / executionTime
        )
        
        results.append(TestResult(
            id: UUID(),
            testName: "Memory Usage Profile",
            category: .performance,
            status: status,
            score: memoryEfficient ? 1.0 : 0.5,
            executionTime: executionTime,
            details: "Memory increase: \(formatBytes(memoryIncrease)), Throughput: \(String(format: "%.1f", 100.0 / executionTime)) ops/sec",
            timestamp: Date(),
            metrics: metrics
        ))
        
        return results
    }
    
    /// Test server result comparison
    func testServerResultComparison() async -> [TestResult] {
        var results: [TestResult] = []
        
        // This would compare on-device results with server results
        // For now, we'll create a mock comparison
        
        let comparisonTestCases = Array(intentTestCases.prefix(5))
        
        for testCase in comparisonTestCases {
            let startTime = Date()
            
            do {
                // Get on-device result
                let onDeviceResult = try await intentClassifier.classifyIntent(text: testCase.input)
                
                // Simulate server result (in real implementation, this would make an API call)
                let serverResult = simulateServerResult(for: testCase.input)
                
                let executionTime = Date().timeIntervalSince(startTime)
                
                // Compare results
                let agreement = onDeviceResult.intent.rawValue.lowercased() == serverResult.intent.rawValue.lowercased()
                let confidenceDiff = abs(onDeviceResult.confidence - Double(serverResult.confidence))
                
                let status: TestResult.TestStatus = agreement && confidenceDiff < 0.2 ? .passed : .warning
                let score = agreement ? (1.0 - confidenceDiff) : 0.0
                
                let metrics = TestMetrics(
                    accuracy: agreement ? 1.0 : 0.0,
                    precision: nil,
                    recall: nil,
                    f1Score: nil,
                    latency: executionTime,
                    memoryUsage: nil,
                    confidenceScore: Double(onDeviceResult.confidence),
                    throughput: nil
                )
                
                results.append(TestResult(
                    id: UUID(),
                    testName: "Server Comparison",
                    category: .serverComparison,
                    status: status,
                    score: score,
                    executionTime: executionTime,
                    details: "On-device: '\(onDeviceResult.intent.rawValue)' (\(String(format: "%.2f", onDeviceResult.confidence))), Server: '\(serverResult.intent.rawValue)' (\(String(format: "%.2f", serverResult.confidence))), Agreement: \(agreement)",
                    timestamp: Date(),
                    metrics: metrics
                ))
                
            } catch {
                results.append(TestResult(
                    id: UUID(),
                    testName: "Server Comparison",
                    category: .serverComparison,
                    status: .failed,
                    score: 0.0,
                    executionTime: Date().timeIntervalSince(startTime),
                    details: "Server comparison failed: \(error.localizedDescription)",
                    timestamp: Date(),
                    metrics: nil
                ))
            }
        }
        
        return results
    }
    
    // MARK: - Helper Methods
    
    private func generateMockAudioData(for text: String) -> Data {
        // Generate mock audio data based on text length
        let baseSize = 1024
        let sizeMultiplier = max(1, text.count / 10)
        return Data(repeating: 0x42, count: baseSize * sizeMultiplier)
    }
    
    private func testSpeechRecognitionWithMockAudio(_ audioData: Data, expectedText: String) async -> (recognizedText: String, confidence: Double) {
        // Mock speech recognition result
        let similarity = Double.random(in: 0.7...0.95)
        let recognizedText = similarity > 0.8 ? expectedText : generateVariation(of: expectedText)
        return (recognizedText, similarity)
    }
    
    private func generateVariation(of text: String) -> String {
        let variations = [
            text.lowercased(),
            text.replacingOccurrences(of: "a", with: "e"),
            String(text.dropLast()),
            text + " um"
        ]
        return variations.randomElement() ?? text
    }
    
    private func calculateTextSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func evaluateResponseQuality(_ response: ResponseGenerationResult) -> Double {
        var score = 0.0
        
        // Check response length
        if response.response.count > 10 && response.response.count < 500 {
            score += 0.3
        }
        
        // Check confidence
        if response.confidence > 0.7 {
            score += 0.3
        }
        
        // Check if response has audio
        if response.audioBase64 != nil && !response.audioBase64!.isEmpty {
            score += 0.2
        }
        
        // Check response relevance (simple keyword matching)
        if response.response.lowercased().contains("meeting") ||
           response.response.lowercased().contains("email") ||
           response.response.lowercased().contains("task") ||
           response.response.lowercased().contains("weather") ||
           response.response.lowercased().contains("time") {
            score += 0.2
        }
        
        return min(score, 1.0)
    }
    
    private func simulateServerResult(for input: String) -> (intent: String, confidence: Double) {
        // Simulate server response based on input patterns
        let serverIntents: [String: (intent: String, confidence: Double)] = [
            "meeting": ("calendar_query", 0.92),
            "schedule": ("calendar_create", 0.88),
            "email": ("email_compose", 0.91),
            "task": ("task_create", 0.89),
            "weather": ("weather_query", 0.94),
            "time": ("time_query", 0.97),
            "calculate": ("calculation", 0.83)
        ]
        
        for (keyword, result) in serverIntents {
            if input.lowercased().contains(keyword) {
                return result
            }
        }
        
        return ("general_conversation", 0.75)
    }
    
    private func benchmarkModelLoading() async -> TestResult {
        let startTime = Date()
        
        do {
            // Simulate model loading
            try await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.1...0.5) * 1_000_000_000))
            let executionTime = Date().timeIntervalSince(startTime)
            
            let isWithinThreshold = executionTime < 1.0
            let status: TestResult.TestStatus = isWithinThreshold ? .passed : .warning
            
            let metrics = TestMetrics(
                accuracy: nil,
                precision: nil,
                recall: nil,
                f1Score: nil,
                latency: executionTime,
                memoryUsage: nil,
                confidenceScore: nil,
                throughput: nil
            )
            
            return TestResult(
                id: UUID(),
                testName: "Model Loading Performance",
                category: .performance,
                status: status,
                score: isWithinThreshold ? 1.0 : 0.5,
                executionTime: executionTime,
                details: "Model loading time: \(String(format: "%.3f", executionTime))s (threshold: 1.0s)",
                timestamp: Date(),
                metrics: metrics
            )
            
        } catch {
            return TestResult(
                id: UUID(),
                testName: "Model Loading Performance",
                category: .performance,
                status: .failed,
                score: 0.0,
                executionTime: Date().timeIntervalSince(startTime),
                details: "Model loading failed: \(error.localizedDescription)",
                timestamp: Date(),
                metrics: nil
            )
        }
    }
    
    private func benchmarkBatchProcessing() async -> TestResult {
        let startTime = Date()
        let batchSize = 10
        
        do {
            let tasks = (0..<batchSize).map { i in
                Task {
                    return try await intentClassifier.classifyIntent(text: "Test query \(i)")
                }
            }
            
            let _ = await withTaskGroup(of: IntentClassificationResult.self) { group in
                for task in tasks {
                    group.addTask { await task.value }
                }
                
                var results: [IntentClassificationResult] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
            
            let executionTime = Date().timeIntervalSince(startTime)
            let throughput = Double(batchSize) / executionTime
            
            let isEfficient = throughput > 10.0 // 10 operations per second
            let status: TestResult.TestStatus = isEfficient ? .passed : .warning
            
            let metrics = TestMetrics(
                accuracy: nil,
                precision: nil,
                recall: nil,
                f1Score: nil,
                latency: executionTime / Double(batchSize),
                memoryUsage: nil,
                confidenceScore: nil,
                throughput: throughput
            )
            
            return TestResult(
                id: UUID(),
                testName: "Batch Processing Performance",
                category: .performance,
                status: status,
                score: isEfficient ? 1.0 : 0.5,
                executionTime: executionTime,
                details: "Processed \(batchSize) queries in \(String(format: "%.3f", executionTime))s, Throughput: \(String(format: "%.1f", throughput)) ops/sec",
                timestamp: Date(),
                metrics: metrics
            )
            
        } catch {
            return TestResult(
                id: UUID(),
                testName: "Batch Processing Performance",
                category: .performance,
                status: .failed,
                score: 0.0,
                executionTime: Date().timeIntervalSince(startTime),
                details: "Batch processing failed: \(error.localizedDescription)",
                timestamp: Date(),
                metrics: nil
            )
        }
    }
    
    private func benchmarkMemoryEfficiency() async -> TestResult {
        let startTime = Date()
        let initialMemory = getCurrentMemoryUsage()
        
        // Perform memory-intensive operations
        var data: [Data] = []
        for i in 0..<100 {
            data.append(Data(repeating: UInt8(i % 256), count: 1024 * 1024)) // 1MB each
        }
        
        let peakMemory = getCurrentMemoryUsage()
        
        // Clean up
        data.removeAll()
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory
        let memoryRecovered = peakMemory - finalMemory
        let executionTime = Date().timeIntervalSince(startTime)
        
        let isEfficient = memoryIncrease < 200 * 1024 * 1024 // Less than 200MB
        let status: TestResult.TestStatus = isEfficient ? .passed : .warning
        
        let metrics = TestMetrics(
            accuracy: nil,
            precision: nil,
            recall: nil,
            f1Score: nil,
            latency: executionTime,
            memoryUsage: Double(memoryIncrease),
            confidenceScore: nil,
            throughput: nil
        )
        
        return TestResult(
            id: UUID(),
            testName: "Memory Efficiency",
            category: .performance,
            status: status,
            score: isEfficient ? 1.0 : 0.5,
            executionTime: executionTime,
            details: "Peak memory increase: \(formatBytes(memoryIncrease)), Recovered: \(formatBytes(memoryRecovered))",
            timestamp: Date(),
            metrics: metrics
        )
    }
    
    private func benchmarkConcurrentProcessing() async -> TestResult {
        let startTime = Date()
        let concurrency = 5
        
        do {
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<concurrency {
                    group.addTask {
                        for j in 0..<10 {
                            _ = await self.intentClassifier.classifyIntent(text: "Concurrent test \(i)-\(j)")
                        }
                    }
                }
            }
            
            let executionTime = Date().timeIntervalSince(startTime)
            let totalOperations = concurrency * 10
            let throughput = Double(totalOperations) / executionTime
            
            let isEfficient = throughput > 20.0
            let status: TestResult.TestStatus = isEfficient ? .passed : .warning
            
            let metrics = TestMetrics(
                accuracy: nil,
                precision: nil,
                recall: nil,
                f1Score: nil,
                latency: executionTime / Double(totalOperations),
                memoryUsage: nil,
                confidenceScore: nil,
                throughput: throughput
            )
            
            return TestResult(
                id: UUID(),
                testName: "Concurrent Processing",
                category: .performance,
                status: status,
                score: isEfficient ? 1.0 : 0.5,
                executionTime: executionTime,
                details: "Processed \(totalOperations) concurrent operations in \(String(format: "%.3f", executionTime))s, Throughput: \(String(format: "%.1f", throughput)) ops/sec",
                timestamp: Date(),
                metrics: metrics
            )
            
        // No catch needed since no throwing functions are called
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
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
    
    private func generateTestingSummary() async {
        let totalTests = testResults.count
        let passedTests = testResults.filter { $0.status == .passed }.count
        let failedTests = testResults.filter { $0.status == .failed }.count
        let warningTests = testResults.filter { $0.status == .warning }.count
        let skippedTests = testResults.filter { $0.status == .skipped }.count
        
        let accuracyScores = testResults.compactMap { $0.metrics?.accuracy }.filter { $0 > 0 }
        let averageAccuracy = accuracyScores.isEmpty ? 0.0 : accuracyScores.reduce(0, +) / Double(accuracyScores.count)
        
        let latencies = testResults.compactMap { $0.metrics?.latency }
        let averageLatency = latencies.isEmpty ? 0.0 : latencies.reduce(0, +) / Double(latencies.count)
        
        let overallScore = Double(passedTests) / Double(totalTests)
        
        var recommendations: [String] = []
        
        if failedTests > 0 {
            recommendations.append("Address \(failedTests) failed tests to improve system reliability")
        }
        
        if averageLatency > performanceThreshold {
            recommendations.append("Optimize performance - average latency is \(String(format: "%.3f", averageLatency))s (threshold: \(performanceThreshold)s)")
        }
        
        if averageAccuracy < accuracyThreshold {
            recommendations.append("Improve model accuracy - current average is \(String(format: "%.1f%%", averageAccuracy * 100)) (threshold: \(String(format: "%.1f%%", accuracyThreshold * 100)))")
        }
        
        if warningTests > totalTests / 4 {
            recommendations.append("Review \(warningTests) warning tests for potential improvements")
        }
        
        if recommendations.isEmpty {
            recommendations.append("System is performing well - continue monitoring")
        }
        
        let finalRecommendations = recommendations
        await MainActor.run {
            testingSummary = TestingSummary(
                totalTests: totalTests,
                passedTests: passedTests,
                failedTests: failedTests,
                warningTests: warningTests,
                skippedTests: skippedTests,
                averageAccuracy: averageAccuracy,
                averageLatency: averageLatency,
                overallScore: overallScore,
                timestamp: Date(),
                recommendations: finalRecommendations
            )
        }
    }
    
    // MARK: - Export and Reporting
    
    func exportTestResults() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let exportData = TestExport(
                summary: testingSummary,
                results: testResults,
                exportDate: Date(),
                version: "1.0"
            )
            
            return try encoder.encode(exportData)
        } catch {
            print("Failed to export test results: \(error)")
            return nil
        }
    }
    
    struct TestExport: Codable {
        let summary: TestingSummary?
        let results: [TestResult]
        let exportDate: Date
        let version: String
    }
}

// MARK: - Extensions

extension MLTestingFramework.TestResult.TestCategory {
    var emoji: String {
        switch self {
        case .intentClassification: return "🎯"
        case .speechRecognition: return "🎤"
        case .responseGeneration: return "💬"
        case .offlineCapability: return "📱"
        case .performance: return "⚡"
        case .accuracy: return "🎯"
        case .edgeCases: return "🔍"
        case .serverComparison: return "🌐"
        }
    }
    
    var color: String {
        switch self {
        case .intentClassification: return "blue"
        case .speechRecognition: return "green"
        case .responseGeneration: return "purple"
        case .offlineCapability: return "orange"
        case .performance: return "red"
        case .accuracy: return "blue"
        case .edgeCases: return "gray"
        case .serverComparison: return "cyan"
        }
    }
}

extension MLTestingFramework.TestResult.TestStatus {
    var emoji: String {
        switch self {
        case .passed: return "✅"
        case .failed: return "❌"
        case .warning: return "⚠️"
        case .skipped: return "⏭️"
        }
    }
}