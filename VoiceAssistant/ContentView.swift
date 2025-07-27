import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioRecorder = MinimalAudioRecorder()
    @ObservedObject private var apiClient = APIClient.shared
    @ObservedObject private var oauthManager = OAuthManager.shared
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var enhancedVoiceProcessor: EnhancedVoiceProcessor
    @StateObject private var offlineProcessor = OfflineProcessor()
    @StateObject private var offlineEnhancementManager = OfflineEnhancementManager()
    @ObservedObject private var transitionManager = OfflineTransitionManager.shared
    @StateObject private var performanceOptimizer = MLPerformanceOptimizer()
    @StateObject private var quantization: ModelQuantization
    @StateObject private var batchProcessor: BatchProcessor
    @StateObject private var personalizationEngine = PersonalizationEngine()
    @StateObject private var intentClassifier: IntentClassifier
    @State private var transcribedText = ""
    @State private var statusMessage = "Tap to record"
    @State private var showError = false
    @State private var showSettings = false
    @StateObject private var conversationHistoryManager = ConversationHistoryManager()
    
    // Audio playback for responses
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isAudioPlaying = false
    
    // Initialize with dependencies
    init() {
        let speechRecognizer = SpeechRecognizer()
        let apiClient = APIClient.shared
        let performanceOptimizer = MLPerformanceOptimizer()
        let quantization = ModelQuantization(performanceOptimizer: performanceOptimizer)
        let batchProcessor = BatchProcessor(
            performanceOptimizer: performanceOptimizer,
            quantization: quantization
        )
        let intentClassifier = IntentClassifier()
        
        _speechRecognizer = StateObject(wrappedValue: speechRecognizer)
        _performanceOptimizer = StateObject(wrappedValue: performanceOptimizer)
        _quantization = StateObject(wrappedValue: quantization)
        _batchProcessor = StateObject(wrappedValue: batchProcessor)
        _intentClassifier = StateObject(wrappedValue: intentClassifier)
        _enhancedVoiceProcessor = StateObject(wrappedValue: EnhancedVoiceProcessor(
            speechRecognizer: speechRecognizer,
            apiClient: apiClient
        ))
    }
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()
            
            // Particle effect background
            ParticleBackgroundView(
                isVoiceActive: audioRecorder.isRecording,
                isAudioPlaying: isAudioPlaying,
                audioLevel: 0.0
            )
            
            // Main content
            VStack(spacing: 20) {
                headerView
                offlineStatusView
                permissionView
                conversationView
                statusView
                recordingButton
                recordingTimeView
                audioLevelMeter
                quickActionsView
                Spacer()
                debugView
            }
            .padding()
        }
        .alert("Recording Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(audioRecorder.error?.errorDescription ?? "Unknown error occurred")
        }
        .onChange(of: audioRecorder.error) { _, error in
            showError = (error != nil)
        }
        .sheet(isPresented: $showSettings) {
            EnhancedSettingsViewWithActions(
                conversationHistory: $conversationHistoryManager.conversationHistory,
                onDismiss: { showSettings = false }
            )
        }
        .onAppear {
            oauthManager.checkIntegrationStatus()
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            // Empty space for balance
            Color.clear
                .frame(width: 44, height: 44)
                .padding(.leading, 20)
            
            Spacer()
            
            // FLOE Title - Centered
            Text("Floe")
                .font(.custom("Corinthia", size: 48))
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Spacer()
            
            // Settings Button
            Button(action: { showSettings.toggle() }) {
                ZStack {
                    // Show a badge if Google is connected
                    if oauthManager.isGoogleConnected {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .offset(x: 12, y: -12)
                    }
                    
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .padding(.trailing, 20)
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens the settings menu")
        }
        .padding(.top, 60)
    }
    
    private var offlineStatusView: some View {
        VStack {
            if transitionManager.currentMode != .online || transitionManager.degradedModeActive {
                VStack {
                    OfflineStatusCard(
                        mode: transitionManager.currentMode,
                        connectionQuality: transitionManager.connectionStatus.quality,
                        availableCapabilities: offlineProcessor.offlineCapabilities.map { $0.rawValue },
                        queuedCommandsCount: offlineProcessor.queuedCommandsCount,
                        isDegraded: transitionManager.degradedModeActive
                    )
                    
                    // Enhanced offline status
                    if offlineEnhancementManager.enhancedCacheStatus != .ready {
                        EnhancedOfflineStatusView(enhancementManager: offlineEnhancementManager)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: transitionManager.currentMode)
            }
        }
    }
    
    private var conversationView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if conversationHistoryManager.conversationHistory.isEmpty {
                        ConversationEmptyStateView()
                    } else {
                        // Show conversation history
                        ForEach(conversationHistoryManager.conversationHistory) { message in
                            ConversationBubbleChat(
                                message: message,
                                onTap: {
                                    if !message.isUser {
                                        HapticManager.shared.cardTapped()
                                    }
                                }
                            )
                            .id(message.id)
                        }
                    }
                    
                    // Live transcription bubble
                    if !transcribedText.isEmpty && audioRecorder.isRecording {
                        LiveTranscriptionBubbleChat(text: transcribedText)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 400)
            .onChange(of: conversationHistoryManager.conversationHistory.count) { _, _ in
                // Scroll to bottom when new messages are added
                withAnimation {
                    proxy.scrollTo(conversationHistoryManager.conversationHistory.last?.id, anchor: .bottom)
                }
            }
        }
    }
    
    private var permissionView: some View {
        Group {
            if !audioRecorder.hasPermission {
                Label("Microphone permission required", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }
        }
    }
    
    private var statusView: some View {
        VStack(spacing: 4) {
            Text(statusMessage)
                .foregroundColor(.white.opacity(0.6))
                .font(.subheadline)
            
            // Google Services Connection Status
            if oauthManager.isGoogleConnected {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text("Google Services Connected")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }
            
            // Processing status indicator
            if enhancedVoiceProcessor.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    
                    Text(enhancedVoiceProcessor.currentProcessingStep.displayText)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Batch processing status
            if batchProcessor.isProcessing || batchProcessor.queuedRequestsCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: batchProcessor.isProcessing ? "cpu" : "clock")
                        .foregroundColor(.purple)
                        .font(.caption)
                    
                    Text(batchProcessor.isProcessing ? 
                         "Batch processing..." : 
                         "\(batchProcessor.queuedRequestsCount) queued")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Personalization status
            if personalizationEngine.isLearning {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("Learning preferences...")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Intent classification status
            if intentClassifier.isProcessing {
                HStack(spacing: 8) {
                    Image(systemName: "brain")
                        .foregroundColor(.cyan)
                        .font(.caption)
                    
                    Text("Analyzing intent...")
                        .font(.caption)
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.cyan.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var recordingButton: some View {
        RecordingButtonView(
            isRecording: audioRecorder.isRecording,
            audioLevel: audioRecorder.audioLevel,
            hasPermission: audioRecorder.hasPermission,
            action: toggleRecording
        )
    }
    
    private var recordingTimeView: some View {
        Group {
            if audioRecorder.isRecording {
                Text(timeString(from: audioRecorder.recordingTime))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundColor(.red)
            }
        }
    }
    
    private var audioLevelMeter: some View {
        Group {
            if audioRecorder.isRecording {
                AudioLevelMeterView(audioLevel: audioRecorder.audioLevel)
            }
        }
    }
    
    private var quickActionsView: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    SimpleQuickActionButton(
                        action: QuickAction(
                            id: "schedule",
                            title: "Schedule",
                            icon: "calendar.badge.plus",
                            voiceCommand: "What's on my calendar today?",
                            color: "blue"
                        ),
                        onTap: processQuickAction
                    )
                    
                    SimpleQuickActionButton(
                        action: QuickAction(
                            id: "email",
                            title: "Email",
                            icon: "envelope",
                            voiceCommand: "Check my unread emails",
                            color: "red"
                        ),
                        onTap: processQuickAction
                    )
                    
                    SimpleQuickActionButton(
                        action: QuickAction(
                            id: "tasks",
                            title: "Tasks",
                            icon: "checkmark.circle",
                            voiceCommand: "Show me my tasks for today",
                            color: "green"
                        ),
                        onTap: processQuickAction
                    )
                    
                    SimpleQuickActionButton(
                        action: QuickAction(
                            id: "weather",
                            title: "Weather",
                            icon: "cloud.sun",
                            voiceCommand: "What's the weather like today?",
                            color: "orange"
                        ),
                        onTap: processQuickAction
                    )
                    
                    SimpleQuickActionButton(
                        action: QuickAction(
                            id: "time",
                            title: "Time",
                            icon: "clock",
                            voiceCommand: "What time is it?",
                            color: "purple"
                        ),
                        onTap: processQuickAction
                    )
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
    
    
    private var debugView: some View {
        Group {
            #if DEBUG
            VStack(spacing: 8) {
                Button("Check Circuit Breakers") {
                    FeatureCircuitBreakers.printStatus()
                }
                .font(.caption)
                .foregroundColor(.gray)
                
                Button("Test Batch Processing") {
                    testBatchProcessing()
                }
                .font(.caption)
                .foregroundColor(.purple)
                
                Button("Test ML & Personalization") {
                    testMLAndPersonalization()
                }
                .font(.caption)
                .foregroundColor(.green)
                
                if batchProcessor.queuedRequestsCount > 0 {
                    Button("Force Process Batch") {
                        batchProcessor.forceBatchProcessing()
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
            #endif
        }
    }
    
    // MARK: - Methods
    
    func toggleRecording() {
        if audioRecorder.isRecording {
            // Stop recording with circuit breaker
            FeatureCircuitBreakers.audioRecording.executeFeature {
                statusMessage = "Processing..."
                
                if let audioURL = audioRecorder.stopRecording() {
                    Task {
                        // First transcribe the audio using our fixed speech recognition
                        await transcribeAudio(audioURL)
                        
                        // Add user message after we have transcription
                        await MainActor.run {
                            if !transcribedText.isEmpty {
                                let userMessage = ConversationMessage(
                                    text: transcribedText,
                                    isUser: true,
                                    isTranscribed: true
                                )
                                conversationHistoryManager.addMessage(userMessage)
                            }
                        }
                        
                        // Check if we should use offline processing
                        // Only use offline if truly disconnected or explicitly in offline mode
                        if !transitionManager.connectionStatus.isConnected || 
                           (transitionManager.currentMode == .offline && !transitionManager.connectionStatus.isConnected) {
                            // Use enhanced offline processor
                            let audioData = try? Data(contentsOf: audioURL)
                            let context = createProcessingContext()
                            
                            // Try enhanced offline processing first
                            let enhancedResult = await offlineEnhancementManager.processOfflineIntent(
                                transcribedText,
                                context: context
                            )
                            
                            // Fallback to basic offline processor if needed
                            let result: OfflineProcessor.OfflineResponse
                            if enhancedResult.confidence > 0.6 {
                                // Convert enhanced result to basic result
                                result = OfflineProcessor.OfflineResponse(
                                    text: enhancedResult.text,
                                    audioBase64: enhancedResult.audioBase64,
                                    confidence: enhancedResult.confidence,
                                    source: .template,
                                    capabilities: [],
                                    processingTime: 0.0,
                                    requiresSync: enhancedResult.requiresSync,
                                    metadata: [:]
                                )
                            } else {
                                result = await offlineProcessor.processCommand(
                                    transcribedText,
                                    audioData: audioData
                                )
                            }
                            
                            await MainActor.run {
                                // Add AI response with offline indicator
                                let aiMessage = ConversationMessage(
                                    text: result.text,
                                    isUser: false,
                                    audioBase64: result.audioBase64,
                                    isTranscribed: false,
                                    confidence: result.confidence
                                )
                                conversationHistoryManager.addMessage(aiMessage)
                                
                                // Play audio if available
                                if let audioBase64 = result.audioBase64, !audioBase64.isEmpty {
                                    playAudioResponse(audioBase64: audioBase64)
                                }
                                
                                // Update status based on result
                                if result.requiresSync {
                                    statusMessage = "Command queued for sync"
                                } else {
                                    statusMessage = "Tap to record"
                                }
                            }
                        } else {
                            // SIMPLE BACKEND PROCESSING - Use simple text processing
                            do {
                                // Instead of complex processing, use simple backend
                                await MainActor.run {
                                    statusMessage = "Processing with simple backend..."
                                }
                                
                                // Use simple backend text processing
                                try await processWithSimpleBackend(transcribedText)
                            } catch {
                                await MainActor.run {
                                    // Provide user-friendly error messages
                                    let errorMessage: String
                                    switch error {
                                    case APIError.httpError(let code) where code == 401:
                                        errorMessage = "Authentication required. Please sign in."
                                    case APIError.httpError(let code) where code == 429:
                                        errorMessage = "Rate limit exceeded. Please try again later."
                                    case APIError.httpError(let code) where code >= 500:
                                        errorMessage = "Server error. Please try again later."
                                    case APIError.fileReadError:
                                        errorMessage = "Failed to read audio file."
                                    case APIError.noResponseText:
                                        errorMessage = "No response from server. Please try again."
                                    case APIError.invalidAudioFormat(let message):
                                        errorMessage = "Audio format issue: \(message)"
                                    default:
                                        errorMessage = "Connection error: \(error.localizedDescription)"
                                    }
                                    
                                    // Add error as AI message
                                    let errorAIMessage = ConversationMessage(
                                        text: errorMessage,
                                        isUser: false,
                                        isTranscribed: false
                                    )
                                    conversationHistoryManager.addMessage(errorAIMessage)
                                    statusMessage = "Tap to record"
                                }
                            }
                        }
                    }
                } else {
                    statusMessage = "Failed to stop recording"
                }
            }
        } else {
            // Start recording with circuit breaker
            let success = FeatureCircuitBreakers.audioRecording.executeFeature {
                audioRecorder.startRecording()
                statusMessage = "Recording..."
                transcribedText = ""
                
                // Real speech recognition instead of demo simulation
                startRealTimeTranscription()
            }
            
            if !success {
                statusMessage = "Recording temporarily disabled"
                // Add error as system message
                let errorMessage = ConversationMessage(
                    text: "Audio recording has been disabled due to repeated failures. Please try again later.",
                    isUser: false,
                    isTranscribed: false
                )
                conversationHistoryManager.addMessage(errorMessage)
            }
        }
    }
    
    // Helper function to format time
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
    
    // Process quick action commands
    private func processQuickAction(_ action: QuickAction) {
        statusMessage = "Processing..."
        
        // Add user message for quick action
        let userMessage = ConversationMessage(
            text: action.voiceCommand,
            isUser: true,
            isTranscribed: false
        )
        conversationHistoryManager.addMessage(userMessage)
        
        Task {
            // Check if we should use offline processing
            // Only use offline if truly disconnected
            if !transitionManager.connectionStatus.isConnected {
                // Use offline processor for text
                let result = await offlineProcessor.processCommand(
                    action.voiceCommand,
                    audioData: nil
                )
                
                await MainActor.run {
                    // Add AI response with offline indicator
                    let aiMessage = ConversationMessage(
                        text: result.text,
                        isUser: false,
                        audioBase64: result.audioBase64,
                        isTranscribed: false,
                        confidence: result.confidence
                    )
                    conversationHistoryManager.addMessage(aiMessage)
                    
                    // Play audio if available
                    if let audioBase64 = result.audioBase64, !audioBase64.isEmpty {
                        playAudioResponse(audioBase64: audioBase64)
                    }
                    
                    statusMessage = result.requiresSync ? "Command queued" : "Tap to record"
                }
            } else {
                // Try enhanced offline processing first for quick actions
                let context = createProcessingContext()
                let enhancedResult = await offlineEnhancementManager.processOfflineIntent(
                    action.voiceCommand,
                    context: context
                )
                
                if enhancedResult.confidence > 0.7 {
                    // Use enhanced offline result
                    await MainActor.run {
                        let aiMessage = ConversationMessage(
                            text: enhancedResult.text,
                            isUser: false,
                            audioBase64: enhancedResult.audioBase64,
                            isTranscribed: false,
                            confidence: enhancedResult.confidence
                        )
                        conversationHistoryManager.addMessage(aiMessage)
                        
                        // Play audio if available
                        if let audioBase64 = enhancedResult.audioBase64, !audioBase64.isEmpty {
                            playAudioResponse(audioBase64: audioBase64)
                        }
                        
                        statusMessage = enhancedResult.requiresSync ? "Command queued" : "Tap to record"
                    }
                    return
                }
                
                // Use enhanced voice processor for text processing
                do {
                    let context = createProcessingContext()
                    let result = try await enhancedVoiceProcessor.processTextCommand(
                        text: action.voiceCommand,
                        context: context
                    )
                    
                    await MainActor.run {
                        // Add AI response with enhanced metadata
                        let aiMessage = ConversationMessage(
                            text: result.response.text,
                            isUser: false,
                            audioBase64: result.response.audioBase64,
                            isTranscribed: false,
                            intent: result.intent.rawValue,
                            confidence: Double(result.confidence),
                            agentUsed: result.processingMethod.description,
                            executionTime: result.processingTime
                        )
                        conversationHistoryManager.addMessage(aiMessage)
                        
                        // Play audio if available
                        if let audioBase64 = result.response.audioBase64, !audioBase64.isEmpty {
                            playAudioResponse(audioBase64: audioBase64)
                        }
                        statusMessage = "Tap to record"
                    }
                } catch {
                    await MainActor.run {
                        // Add error message
                        let errorMessage = ConversationMessage(
                            text: "Failed to process: \(error.localizedDescription)",
                            isUser: false,
                            isTranscribed: false
                        )
                        conversationHistoryManager.addMessage(errorMessage)
                        statusMessage = "Tap to record"
                    }
                }
            }
        }
    }
    
    // Helper function to create processing context
    private func createProcessingContext() -> VoiceProcessingContext {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        let timeOfDay = dateFormatter.string(from: Date())
        
        let deviceState = DeviceState(
            batteryLevel: UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel : 1.0,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            isNetworkAvailable: apiClient.isWebSocketConnected,
            isWifiConnected: true, // Simplified for now
            memoryUsage: 0.5 // Simplified for now
        )
        
        return VoiceProcessingContext(
            timeOfDay: timeOfDay,
            location: nil, // Could be integrated with CoreLocation
            previousIntent: nil, // Could track from conversation history
            conversationHistory: conversationHistoryManager.conversationHistory,
            userPreferences: [:], // Could be loaded from UserDefaults
            deviceState: deviceState
        )
    }
    
    // Helper function to handle processing errors
    private func handleProcessingError(_ error: Error) {
        // Provide user-friendly error messages
        let errorMessage: String
        switch error {
        case APIError.httpError(let code) where code == 401:
            errorMessage = "Authentication required. Please sign in."
        case APIError.httpError(let code) where code == 429:
            errorMessage = "Rate limit exceeded. Please try again later."
        case APIError.httpError(let code) where code >= 500:
            errorMessage = "Server error. Please try again later."
        case APIError.fileReadError:
            errorMessage = "Failed to read audio file."
        case APIError.noResponseText:
            errorMessage = "No response from server. Please try again."
        case APIError.invalidAudioFormat(let message):
            errorMessage = "Audio format issue: \(message)"
        default:
            errorMessage = "Connection error: \(error.localizedDescription)"
        }
        
        // Add error as AI message
        let errorAIMessage = ConversationMessage(
            text: errorMessage,
            isUser: false,
            isTranscribed: false
        )
        conversationHistoryManager.addMessage(errorAIMessage)
        statusMessage = "Tap to record"
    }
    
    // MARK: - ML and Personalization Methods
    
    /// Classify user intent using ML models
    private func classifyIntentWithML(_ text: String) async -> IntentClassificationResult {
        do {
            return try await intentClassifier.classifyIntent(text: text)
        } catch {
            // Fallback to basic intent classification
            return IntentClassificationResult(
                intent: .general,
                confidence: 0.5,
                processingTime: 0.1,
                processingMethod: .rulesBased,
                alternativeIntents: [],
                extractedEntities: [:],
                shouldRouteToServer: true,
                routingExplanation: "ML classification failed, using fallback"
            )
        }
    }
    
    /// Personalize the processing context based on user preferences and intent
    private func personalizeContextForUser(
        _ context: VoiceProcessingContext,
        intentResult: IntentClassificationResult
    ) async -> VoiceProcessingContext {
        // Get current user preferences from personalization engine
        let userPrefs = personalizationEngine.currentPreferences
        
        // Create enhanced context with personalization data
        var personalizedPrefs = context.userPreferences
        personalizedPrefs["responseLength"] = userPrefs.responseLength.rawValue
        personalizedPrefs["formalityLevel"] = userPrefs.formalityLevel
        personalizedPrefs["detectedIntent"] = intentResult.intent.rawValue
        personalizedPrefs["intentConfidence"] = intentResult.confidence
        personalizedPrefs["measurementSystem"] = userPrefs.measurementSystem.rawValue
        
        return VoiceProcessingContext(
            timeOfDay: context.timeOfDay,
            location: context.location,
            previousIntent: intentResult.intent,
            conversationHistory: context.conversationHistory,
            userPreferences: personalizedPrefs,
            deviceState: context.deviceState
        )
    }
    
    #if DEBUG
    // Test batch processing functionality
    private func testBatchProcessing() {
        // Submit multiple test requests to batch processor
        let testAudioData = Data(repeating: 0, count: 1024) // Mock audio data
        let context = createProcessingContext()
        
        // Submit requests with different priorities
        for i in 1...5 {
            let priority: RequestPriority = i == 1 ? .high : .normal
            batchProcessor.submitRequest(
                modelType: "voice_processing",
                input: VoiceBatchInput(audioData: testAudioData, context: context),
                priority: priority
            ) { (result: Result<EnhancedVoiceProcessingResult, Error>) in
                Task { @MainActor in
                    switch result {
                    case .success(let batchResult):
                        let testMessage = ConversationMessage(
                            text: "Test \(i): \(batchResult.response.text)",
                            isUser: false,
                            isTranscribed: false
                        )
                        conversationHistoryManager.addMessage(testMessage)
                    case .failure(let error):
                        let errorMessage = ConversationMessage(
                            text: "Test \(i) failed: \(error.localizedDescription)",
                            isUser: false,
                            isTranscribed: false
                        )
                        conversationHistoryManager.addMessage(errorMessage)
                    }
                }
            }
        }
        
        statusMessage = "Batch processing test submitted - \(batchProcessor.queuedRequestsCount) queued"
    }
    
    // Test ML models and personalization functionality
    private func testMLAndPersonalization() {
        Task {
            let testPhrases = [
                "What's the weather like today?",
                "Schedule a meeting for tomorrow",
                "Set a reminder to call mom",
                "Play some relaxing music",
                "How are you feeling today?"
            ]
            
            for (index, phrase) in testPhrases.enumerated() {
                // Test intent classification
                let intentResult = await classifyIntentWithML(phrase)
                
                let testMessage = ConversationMessage(
                    text: "Test ML \(index + 1): \"\(phrase)\" → Intent: \(intentResult.intent.rawValue) (confidence: \(String(format: "%.2f", intentResult.confidence)))",
                    isUser: false,
                    isTranscribed: false
                )
                conversationHistoryManager.addMessage(testMessage)
                
                // Small delay between tests
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            await MainActor.run {
                statusMessage = "ML and personalization tests completed"
            }
        }
    }
    #endif
    
    // MARK: - Real Speech Recognition Functions
    
    private func startRealTimeTranscription() {
        // For now, just show that we're preparing to transcribe
        // Real-time transcription can be complex, so we'll do post-recording transcription
        statusMessage = "Recording... Tap again when done"
    }
    
    private func transcribeAudio(_ audioURL: URL) async {
        print("🎤 Starting real speech recognition transcription")
        statusMessage = "Transcribing..."
        
        do {
            let audioData = try Data(contentsOf: audioURL)
            
            // Use our fixed simple speech recognition
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                speechRecognizer.transcribe(audioData) { result in
                    Task { @MainActor in
                        switch result {
                        case .success(let transcribedTextResult):
                            self.transcribedText = transcribedTextResult
                            print("✅ Real transcription: '\(transcribedTextResult)'")
                            continuation.resume()
                        case .failure(let error):
                            print("❌ Transcription failed: \(error.localizedDescription)")
                            self.transcribedText = "Transcription failed"
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        } catch {
            await MainActor.run {
                transcribedText = "Speech recognition error"
                statusMessage = "Transcription failed"
            }
        }
    }
    
    // MARK: - Audio Playback Functions
    
    private func playAudioResponse(audioBase64: String) {
        guard !audioBase64.isEmpty,
              let audioData = Data(base64Encoded: audioBase64) else {
            print("❌ No valid audio data for playback")
            return
        }
        
        do {
            // Configure audio session for playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Create and configure audio player
            audioPlayer = try AVAudioPlayer(data: audioData)
            // Set up a simple delegate that will reset the playing state
            let delegate = SimpleAudioDelegate()
            audioPlayer?.delegate = delegate
            audioPlayer?.prepareToPlay()
            
            // Start playback
            isAudioPlaying = true
            audioPlayer?.play()
            
            print("✅ Playing audio response")
        } catch {
            print("❌ Failed to play audio: \(error)")
            isAudioPlaying = false
        }
    }
    
    private func stopAudioPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isAudioPlaying = false
    }
    
    // MARK: - Simple Backend Processing
    
    private func processWithSimpleBackend(_ text: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            apiClient.processTextSimple(text: text) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let voiceResponse):
                        // Add AI response to conversation
                        let aiMessage = ConversationMessage(
                            text: voiceResponse.text,
                            isUser: false,
                            audioBase64: voiceResponse.audioBase64,
                            isTranscribed: false,
                            confidence: 1.0
                        )
                        conversationHistoryManager.addMessage(aiMessage)
                        
                        // Play audio if available
                        if let audioBase64 = voiceResponse.audioBase64, !audioBase64.isEmpty {
                            playAudioResponse(audioBase64: audioBase64)
                        }
                        
                        statusMessage = "Tap to record"
                        continuation.resume()
                        
                    case .failure(let error):
                        let errorMessage: String
                        if let voiceError = error as? VoiceAssistantError {
                            switch voiceError {
                            case .authenticationRequired:
                                errorMessage = "Please sign in to use voice features"
                            case .networkError:
                                errorMessage = "Network connection error"
                            case .authenticationFailed:
                                errorMessage = "Authentication failed"
                            case .invalidResponse:
                                errorMessage = "Invalid response from server"
                            default:
                                errorMessage = "Error: \(error.localizedDescription)"
                            }
                        } else {
                            errorMessage = "Error: \(error.localizedDescription)"
                        }
                        
                        // Add error as AI message
                        let errorAIMessage = ConversationMessage(
                            text: errorMessage,
                            isUser: false,
                            isTranscribed: false
                        )
                        conversationHistoryManager.addMessage(errorAIMessage)
                        statusMessage = "Tap to record"
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

/// Input structure for voice batch processing
struct VoiceBatchInput {
    let audioData: Data
    let context: VoiceProcessingContext
}

// MARK: - Extensions

extension EnhancedVoiceProcessor.ProcessingStep {
    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .transcribing:
            return "Converting speech..."
        case .classifyingIntent:
            return "Understanding intent..."
        case .routingDecision:
            return "Choosing processor..."
        case .processingOnDevice:
            return "Processing locally..."
        case .processingOnServer:
            return "Processing online..."
        case .generatingResponse:
            return "Generating response..."
        case .completed:
            return "Complete"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

extension ProcessingMethod {
    var description: String {
        switch self {
        case .fullyOnDevice:
            return "On-Device"
        case .fullyServer:
            return "Server"
        case .hybrid(let onDevice, let server):
            return "Hybrid (On-Device: \(onDevice.joined(separator: ", ")), Server: \(server.joined(separator: ", ")))"
        }
    }
}

// MARK: - Recording Button Component

struct RecordingButtonView: View {
    let isRecording: Bool
    let audioLevel: Float
    let hasPermission: Bool
    let action: () -> Void
    
    var body: some View {
        ZStack {
            // Outer ring animation
            if isRecording {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: buttonSize + 20, height: buttonSize + 20)
                    .scaleEffect(isRecording ? 1.1 : 1.0)
                    .opacity(isRecording ? 0.8 : 0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
            }
            
            // Audio level indicator
            if isRecording {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.1)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: buttonSize + (CGFloat(audioLevel) * 60),
                           height: buttonSize + (CGFloat(audioLevel) * 60))
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
            
            Button(action: action) {
                ZStack {
                    // Background gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isRecording ? [Color.red, Color.orange] : [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: buttonSize, height: buttonSize)
                    
                    // Shadow
                    Circle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: buttonSize, height: buttonSize)
                        .offset(y: 2)
                        .blur(radius: 4)
                    
                    // Main button
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isRecording ? [Color.red, Color.orange] : [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: buttonSize, height: buttonSize)
                    
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(isRecording ? 0.8 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isRecording)
                }
            }
            .disabled(!hasPermission)
            .scaleEffect(hasPermission ? 1.0 : 0.9)
            .opacity(hasPermission ? 1.0 : 0.6)
        }
    }
    
    private var buttonSize: CGFloat { 100 }
}

// MARK: - Audio Player Delegate

class SimpleAudioDelegate: NSObject, AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Audio finished playing - simple implementation without callbacks
        print("✅ Audio playback finished")
    }
}

// MARK: - Audio Level Meter Component

struct AudioLevelMeterView: View {
    let audioLevel: Float
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<20) { index in
                Rectangle()
                    .fill(audioLevelColor(for: index))
                    .frame(width: 8, height: 20)
                    .opacity(isActive(index: index) ? 1.0 : 0.3)
            }
        }
        .frame(height: 20)
        .padding(.horizontal)
    }
    
    private func isActive(index: Int) -> Bool {
        Double(index) / 20.0 <= Double(audioLevel)
    }
    
    private func audioLevelColor(for index: Int) -> Color {
        let percentage = Double(index) / 20.0
        if percentage < 0.5 {
            return .green
        } else if percentage < 0.8 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Quick Action Button Component

struct SimpleQuickActionButton: View {
    let action: QuickAction
    let onTap: (QuickAction) -> Void
    
    var body: some View {
        let color = colorFromString(action.color)
        
        Button(action: { onTap(action) }) {
            VStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(color.opacity(0.2))
                    )
                
                Text(action.title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "orange": return Color(red: 1.0, green: 0.65, blue: 0.0) // Custom orange color
        case "purple": return .purple
        case "yellow": return .yellow
        case "pink": return .pink
        case "gray": return .gray
        default: return .blue
        }
    }
}