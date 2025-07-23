import SwiftUI
import AVFoundation

// Temporary debug helper - inline to avoid import issues
struct AuthDebugger {
    static func printFullAuthStatus() {
        print("🔍 ===== AUTHENTICATION DEBUG INFO =====")
        
        // Check API configuration
        print("🔧 API Configuration:")
        print("   Base URL: \(Constants.API.baseURL)")
        print("   API Key: \(Constants.API.apiKey.isEmpty ? "EMPTY" : "SET (\(Constants.API.apiKey.count) chars)")")
        print("   Webhook URL: \(Constants.API.webhookURL)")
        
        // Check stored tokens
        print("🔑 Token Status:")
        let accessToken = UserDefaults.standard.string(forKey: Constants.StorageKeys.accessToken)
        let refreshToken = UserDefaults.standard.string(forKey: Constants.StorageKeys.refreshToken)
        
        print("   Access Token: \(accessToken?.isEmpty == false ? "SET (\(accessToken!.count) chars)" : "MISSING")")
        print("   Refresh Token: \(refreshToken?.isEmpty == false ? "SET (\(refreshToken!.count) chars)" : "MISSING")")
        
        if let accessToken = accessToken, !accessToken.isEmpty {
            print("   Access Token Preview: \(String(accessToken.prefix(20)))...")
        }
        
        // Check APIClient state
        print("📱 APIClient Status:")
        let apiClient = APIClient.shared
        print("   isAuthenticated: \(apiClient.isAuthenticated)")
        print("   isWebSocketConnected: \(apiClient.isWebSocketConnected)")
        
        // Check development mode
        print("🔧 Development Mode:")
        let devMode = UserDefaults.standard.bool(forKey: "development_mode")
        print("   Development Mode: \(devMode)")
        
        // Check onboarding status
        print("📋 Onboarding Status:")
        let onboardingCompleted = UserDefaults.standard.bool(forKey: "onboarding_completed")
        print("   Onboarding Completed: \(onboardingCompleted)")
        
        print("🔍 ======================================")
    }
    
    static func testAPIKeyFormat() {
        let apiKey = Constants.API.apiKey
        print("🔍 ===== API KEY TEST =====")
        print("API Key: '\(apiKey)'")
        print("Length: \(apiKey.count)")
        print("Is Empty: \(apiKey.isEmpty)")
        print("First 10 chars: \(String(apiKey.prefix(10)))")
        
        if apiKey == "dev-api-key" {
            print("⚠️  Using development API key!")
        } else if apiKey.isEmpty {
            print("❌ API key is EMPTY!")
        } else {
            print("✅ API key appears to be set")
        }
        print("🔍 =========================")
    }
    
    static func simulateAuthenticatedRequest() {
        print("🔍 ===== SIMULATING API REQUEST =====")
        
        let apiClient = APIClient.shared
        
        // Check if we're authenticated
        if !apiClient.isAuthenticated {
            print("❌ NOT AUTHENTICATED - This will cause 401 error")
            return
        }
        
        // Create a test request
        guard let url = URL(string: "\(Constants.API.baseURL)/api/voice/process") else {
            print("❌ Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Check what headers would be added
        print("📤 Request would be sent with headers:")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.API.apiKey, forHTTPHeaderField: "x-api-key")
        
        if let accessToken = UserDefaults.standard.string(forKey: Constants.StorageKeys.accessToken) {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("   Content-Type: application/json")
            print("   x-api-key: \(Constants.API.apiKey.isEmpty ? "EMPTY!" : "SET")")
            print("   Authorization: Bearer \(String(accessToken.prefix(20)))...")
        } else {
            print("   Content-Type: application/json")
            print("   x-api-key: \(Constants.API.apiKey.isEmpty ? "EMPTY!" : "SET")")
            print("   Authorization: MISSING!")
        }
        
        print("🔍 ===================================")
    }
}

struct ContentView: View {
    @ObservedObject private var watchConnector = WatchConnector.shared
    @ObservedObject private var apiClient = APIClient.shared
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var enhancedVoiceProcessor: EnhancedVoiceProcessor
    @StateObject private var offlineProcessor = OfflineProcessor()
    @StateObject private var transitionManager = OfflineTransitionManager.shared
    
    @State private var isConnected = false
    @State private var lastMessage = ""
    @State private var currentStatus: VoiceAssistantStatus = .idle
    @State private var webhookURL = Constants.API.webhookURL
    @State private var showSettings = false
    
    // Voice testing
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioPlayerDelegate = AudioPlayerDelegate()
    @State private var audioSession = AVAudioSession.sharedInstance()
    @State private var conversationHistory: [ConversationMessage] = []
    @State private var currentTranscription = ""
    @State private var audioLevels: [CGFloat] = Array(repeating: 0.3, count: 50)
    @State private var showMenu = false
    @State private var selectedMessage: ConversationMessage?
    @State private var showError = false
    @State private var lastError = ""
    
    // MARK: - Initialization
    init() {
        let speechRecognizer = SpeechRecognizer()
        let apiClient = APIClient.shared
        _enhancedVoiceProcessor = StateObject(wrappedValue: EnhancedVoiceProcessor(
            speechRecognizer: speechRecognizer,
            apiClient: apiClient
        ))
    }
    
    // Quick Actions
    private let quickActions: [QuickAction] = [
        QuickAction(
            id: "calendar",
            title: "Schedule",
            icon: "calendar.badge.plus",
            voiceCommand: "Schedule a meeting",
            color: "blue"
        ),
        QuickAction(
            id: "email",
            title: "Email",
            icon: "envelope",
            voiceCommand: "Check my emails",
            color: "red"
        ),
        QuickAction(
            id: "tasks",
            title: "Tasks",
            icon: "checkmark.circle",
            voiceCommand: "Add a new task",
            color: "green"
        ),
        QuickAction(
            id: "weather",
            title: "Weather",
            icon: "cloud.sun",
            voiceCommand: "What's the weather like?",
            color: "orange"
        ),
        QuickAction(
            id: "time",
            title: "Time",
            icon: "clock",
            voiceCommand: "What time is it?",
            color: "purple"
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView
                contentView
            }
        }
        .onAppear {
            setupView()
        }
        .sheet(isPresented: $showSettings) {
            EnhancedSettingsView()
        }
        .sheet(isPresented: $showMenu) {
            MenuView(conversationHistory: $conversationHistory, apiClient: apiClient)
        }
        .sheet(item: $selectedMessage) { message in
            ResultBottomSheet(message: message)
        }
    }
    
    // MARK: - View Components
    private var backgroundView: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()
            
            // Particle effect background
            ParticleBackgroundView(
                isVoiceActive: isRecording || currentStatus == .recording,
                isAudioPlaying: currentStatus == .playing || audioPlayer?.isPlaying == true
            )
        }
    }
    
    private var contentView: some View {
        VStack {
            headerViewMain
            offlineStatusView
            quickActionsSection
            conversationView
            voiceButtonSection
        }
    }
    
    private var headerViewMain: some View {
        HStack {
            // Hamburger Menu Button
            Button(action: { showMenu.toggle() }) {
                Image(systemName: "line.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .padding(.leading, 20)
            .accessibilityLabel("Menu")
            .accessibilityHint("Opens the main menu with settings and options")
            
            Spacer()
            
            // SORA Title - Centered
            Text("Sora")
                .font(.custom("Corinthia", size: 48))
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Spacer()
            
            // Empty space for balance (same size as hamburger button)
            Color.clear
                .frame(width: 44, height: 44)
                .padding(.trailing, 20)
        }
        .padding(.top, 60)
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Quick Actions")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.leading, 20)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quickActions) { action in
                        CompactQuickActionButton(
                            action: action,
                            onTap: { executeQuickAction(action) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
    }
    
    private var offlineStatusView: some View {
        Group {
            if transitionManager.currentMode != .online || transitionManager.degradedModeActive {
                OfflineStatusCard(
                    mode: transitionManager.currentMode,
                    connectionQuality: transitionManager.connectionStatus.quality,
                    availableCapabilities: offlineProcessor.getCurrentCapabilities(),
                    queuedCommandsCount: offlineProcessor.queuedCommandsCount,
                    isDegraded: transitionManager.degradedModeActive
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: transitionManager.currentMode)
            }
        }
    }
    
    private var conversationView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if conversationHistory.isEmpty {
                        emptyStateContent
                    } else {
                        // Show conversation history
                        ForEach(conversationHistory) { message in
                            ConversationBubbleChat(
                                message: message,
                                onTap: {
                                    if !message.isUser {
                                        selectedMessage = message
                                        HapticManager.shared.cardTapped()
                                    }
                                }
                            )
                        }
                    }
                    
                    // Live transcription bubble
                    if !currentTranscription.isEmpty && !conversationHistory.isEmpty {
                        LiveTranscriptionBubbleChat(text: currentTranscription)
                    }
                    
                    // Status indicators when conversation exists
                    if !conversationHistory.isEmpty {
                        statusIndicators
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .onChange(of: conversationHistory.count) { _, _ in
                if let lastMessage = conversationHistory.last {
                    withAnimation(.easeOut(duration: 0.5)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .accessibilityLabel("Conversation history")
            .accessibilityHint("Scrollable list of your conversation with the AI assistant")
        }
        .frame(maxHeight: .infinity)
        .padding(.top, 20)
    }
    
    private var emptyStateContent: some View {
        VStack(spacing: 20) {
            // Simple listening indicator
            if isRecording || currentStatus == .recording {
                Text("I'm listening...")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .animation(.easeInOut(duration: 0.5), value: isRecording)
            }
            
            // Processing indicator
            if currentStatus == .processing {
                Text("Thinking...")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .animation(.easeInOut(duration: 0.5), value: currentStatus)
            }
            
            // Show transcription if available
            if !currentTranscription.isEmpty {
                Text(currentTranscription)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
            }
            
            // Empty state message
            if currentStatus == .idle && currentTranscription.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("Ready to assist you")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Your conversation will appear here")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 60)
            }
        }
    }
    
    private var statusIndicators: some View {
        VStack(spacing: 8) {
            if isRecording || currentStatus == .recording {
                Text("I'm listening...")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            if currentStatus == .processing {
                Text("Thinking...")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            if currentStatus == .playing {
                Text("Speaking...")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.bottom, 20)
    }
    
    private var voiceButtonSection: some View {
        VStack(spacing: 20) {
            voiceButtonContent
            voiceButtonText
        }
        .padding(.bottom, 50)
    }
    
    private var voiceButtonContent: some View {
        Button(action: {}) {
            ZStack {
                voiceButtonBackground
                voiceButtonMain
            }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isRecording {
                        startRecording()
                    }
                }
                .onEnded { _ in
                    if isRecording {
                        stopRecording()
                    }
                }
        )
        .accessibilityLabel("Voice Recording Button")
        .accessibilityHint("Hold to record voice command, release to process")
    }
    
    private var voiceButtonBackground: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.8, green: 0.7, blue: 1.0).opacity(0.3),
                        Color(red: 0.6, green: 0.5, blue: 0.8).opacity(0.1),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: 100
                )
            )
            .frame(width: 200, height: 200)
            .scaleEffect(isRecording ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRecording)
    }
    
    private var voiceButtonMain: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.8, green: 0.7, blue: 1.0),
                        Color(red: 0.6, green: 0.5, blue: 0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 120, height: 120)
            .overlay(voiceButtonOverlay)
            .shadow(color: Color(red: 0.8, green: 0.7, blue: 1.0).opacity(0.5), radius: 20, x: 0, y: 10)
    }
    
    private var voiceButtonOverlay: some View {
        Group {
            if isRecording {
                WaveformVisualizationView(
                    audioLevels: audioLevels.map { Float($0) },
                    isRecording: isRecording,
                    isProcessing: currentStatus == .processing
                )
                .frame(width: 80, height: 80)
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var voiceButtonText: some View {
        Text(isRecording ? "Recording..." : "Hold to speak")
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))
            .animation(.easeInOut(duration: 0.2), value: isRecording)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice Assistant")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    connectionStatusBadge
                }
                
                Spacer()
                
                // Hamburger Menu Button
                Button(action: { showMenu.toggle() }) {
                    Image(systemName: "line.horizontal.3")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color(.systemGray6))
                                .opacity(0.8)
                        )
                }
                .contentShape(Circle()) // Ensure entire frame is tappable
                .accessibilityLabel("Menu")
                .accessibilityHint("Opens the main menu with settings and options")
                
                settingsButton
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var connectionStatusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(isConnected ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isConnected)
            
            Text(connectionStatusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
    
    private var connectionStatusColor: Color {
        if apiClient.isWebSocketConnected {
            return .green
        } else if isConnected {
            return .orange
        } else {
            return .red
        }
    }
    
    private var connectionStatusText: String {
        if apiClient.isWebSocketConnected {
            return "Real-time Connected"
        } else if isConnected {
            return "Watch Connected"
        } else {
            return "iPhone Mode"
        }
    }
    
    private var settingsButton: some View {
        Button(action: { showSettings = true }) {
            Image(systemName: "gear")
                .font(.title2)
                .foregroundColor(.secondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                        .opacity(0.8)
                )
        }
    }
    
    
    
    // MARK: - Voice Input Section
    private func voiceInputSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            // Audio Visualization
            if isRecording {
                AudioVisualizationView(levels: audioLevels)
                    .frame(height: 60)
                    .padding(.horizontal, 40)
            }
            
            // Status Text
            statusTextView
            
            // Main Voice Button
            voiceButton
        }
        .padding(.horizontal, 20)
    }
    
    private var statusTextView: some View {
        Text(statusText)
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(statusColor)
            .frame(minHeight: 25)
            .animation(.easeInOut(duration: 0.3), value: currentStatus)
    }
    
    private var voiceButton: some View {
        Button(action: {}) {
            ZStack {
                // Background circles for animation
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (isRecording ? Color.red : Color.blue).opacity(0.1),
                                (isRecording ? Color.red : Color.blue).opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRecording)
                
                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                isRecording ? Color.red : Color.blue,
                                isRecording ? Color.red.opacity(0.8) : Color.blue.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                    )
                    .scaleEffect(isRecording ? 0.95 : 1.0)
                    .shadow(
                        color: (isRecording ? Color.red : Color.blue).opacity(0.3),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isRecording {
                        startRecording()
                    }
                }
                .onEnded { _ in
                    if isRecording {
                        stopRecording()
                    }
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
    }
    
    // MARK: - Computed Properties
    private var statusText: String {
        switch currentStatus {
        case .idle:
            return "Hold to speak"
        case .recording:
            return "Listening..."
        case .transcribing:
            return "Understanding..."
        case .processing:
            return "Thinking..."
        case .playing:
            return "Speaking..."
        case .error:
            return "Something went wrong"
        }
    }
    
    private var statusColor: Color {
        switch currentStatus {
        case .idle:
            return .secondary
        case .recording:
            return .blue
        case .transcribing, .processing:
            return .orange
        case .playing:
            return .purple
        case .error:
            return .red
        }
    }
    
    // MARK: - Functions
    private func setupView() {
        // DEBUG: Print authentication status on startup
        AuthDebugger.printFullAuthStatus()
        AuthDebugger.testAPIKeyFormat()
        AuthDebugger.simulateAuthenticatedRequest()
        
        // Set up watch connector callbacks
        watchConnector.onAudioReceived = { audioData in
            print("📱 iPhone: Received audio from Watch (\(audioData.count) bytes)")
            self.handleAudioFromWatch(audioData, fromWatch: true)
        }
        
        watchConnector.onStatusUpdate = { status in
            DispatchQueue.main.async {
                currentStatus = status
            }
        }
        
        loadWebhookURL()
        setupAudioSession()
        startAudioLevelMonitoring()
    }
    
    private func setupAudioSession() {
        do {
            // Configure audio session with optimized settings
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .default, 
                                       options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay])
            
            // Set preferred sample rate and buffer duration to reduce buffer mismatches
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.023) // ~1024 frames at 44.1kHz
            
            // Activate audio session
            try audioSession.setActive(true)
            
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Failed to set up audio session: \(error)")
        }
    }
    
    private func startAudioLevelMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateAudioLevels()
        }
    }
    
    private func updateAudioLevels() {
        // Simulate audio levels for visualization
        if isRecording {
            audioLevels = (0..<50).map { _ in
                CGFloat.random(in: 0.1...0.9)
            }
        } else {
            audioLevels = Array(repeating: 0.1, count: 50)
        }
    }
    
    private func loadWebhookURL() {
        // Legacy webhook URL handling - keeping for backwards compatibility
        if let savedURL = UserDefaults.standard.string(forKey: Constants.StorageKeys.webhookURL) {
            webhookURL = savedURL
        }
    }
    
    private func startRecording() {
        print("📱 iPhone: startRecording called")
        
        // Set state immediately for instant visual feedback
        isRecording = true
        
        // Haptic and sound feedback
        HapticManager.shared.voiceStarted()
        SoundManager.shared.playRecordingStart()
        
        // Check microphone permission first
        let microphoneStatus = AVAudioApplication.shared.recordPermission
        print("📱 iPhone: Microphone permission status: \(microphoneStatus.rawValue)")
        
        if microphoneStatus == .denied {
            print("❌ iPhone: Microphone permission denied")
            isRecording = false
            currentStatus = .error
            HapticManager.shared.commandError()
            SoundManager.shared.playCommandError()
            return
        }
        
        if microphoneStatus == .undetermined {
            print("📱 iPhone: Requesting microphone permission...")
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("✅ iPhone: Microphone permission granted")
                        self.startRecording()
                    } else {
                        print("❌ iPhone: Microphone permission denied by user")
                        self.isRecording = false
                        self.currentStatus = .error
                        HapticManager.shared.commandError()
                        SoundManager.shared.playCommandError()
                    }
                }
            }
            return
        }
        
        do {
            print("📱 iPhone: Setting up audio session...")
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("recording.m4a")
            
            print("📱 iPhone: Audio file path: \(audioFilename)")
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            print("📱 iPhone: Creating audio recorder with settings: \(settings)")
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            
            currentStatus = .recording
            currentTranscription = ""
            
            print("✅ iPhone: Recording started successfully")
            
        } catch {
            print("❌ iPhone: Failed to start recording: \(error.localizedDescription)")
            print("❌ iPhone: Error details: \(error)")
            isRecording = false
            currentStatus = .error
            HapticManager.shared.commandError()
            SoundManager.shared.playCommandError()
        }
    }
    
    private func stopRecording() {
        print("📱 iPhone: stopRecording called")
        audioRecorder?.stop()
        
        // Set state immediately for instant visual feedback
        isRecording = false
        
        // Haptic and sound feedback
        HapticManager.shared.voiceStopped()
        SoundManager.shared.playRecordingStop()
        
        guard let audioRecorder = audioRecorder else {
            print("❌ iPhone: No audio recorder found")
            currentStatus = .error
            HapticManager.shared.commandError()
            SoundManager.shared.playCommandError()
            return
        }
        
        do {
            let audioData = try Data(contentsOf: audioRecorder.url)
            print("✅ iPhone: Recording stopped, got \(audioData.count) bytes")
            handleAudioFromWatch(audioData, fromWatch: false) // iPhone initiated
        } catch {
            print("❌ iPhone: Failed to read audio file: \(error.localizedDescription)")
            isRecording = false
            currentStatus = .error
            HapticManager.shared.commandError()
            SoundManager.shared.playCommandError()
        }
    }
    
    
    private func handleAudioFromWatch(_ audioData: Data, fromWatch: Bool = false) {
        print("📱 iPhone: handleAudioFromWatch called with \(audioData.count) bytes, fromWatch: \(fromWatch)")
        
        // Check if audio data is too small
        if audioData.count < 1000 {
            print("❌ iPhone: Audio data too small (\(audioData.count) bytes), rejecting")
            if fromWatch {
                watchConnector.sendError("Audio recording too short, please try again")
            }
            currentStatus = .error
            return
        }
        
        currentStatus = .transcribing
        
        // Use real-time transcription for live updates
        speechRecognizer.transcribeRealTime(audioData, 
            partialResultsHandler: { partialText in
                self.currentTranscription = partialText
            },
            completion: { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let transcription):
                        print("✅ iPhone: Transcription successful: \(transcription)")
                        self.currentTranscription = "" // Clear live transcription
                        HapticManager.shared.commandSuccess()
                        SoundManager.shared.playCommandSuccess()
                        self.handleTranscription(transcription, fromWatch: fromWatch)
                    case .failure(let error):
                        print("❌ iPhone: Transcription failed: \(error.localizedDescription)")
                        self.currentTranscription = "" // Clear on error
                        self.handleTranscriptionError(error)
                    }
                }
            }
        )
    }
    
    private func handleTranscription(_ transcription: String, fromWatch: Bool = false) {
        // Add user message to conversation
        let userMessage = ConversationMessage(
            id: UUID(),
            text: transcription,
            isUser: true,
            timestamp: Date(),
            audioBase64: nil,
            isTranscribed: false
        )
        conversationHistory.append(userMessage)
        
        currentStatus = .processing
        
        // Create voice processing context
        let context = createVoiceProcessingContext()
        
        // Use enhanced voice processor for intent classification and routing
        Task {
            do {
                let result = try await enhancedVoiceProcessor.processTextCommand(
                    text: transcription,
                    context: context
                )
                
                DispatchQueue.main.async {
                    self.handleEnhancedVoiceResult(result, fromWatch: fromWatch)
                }
            } catch {
                DispatchQueue.main.async {
                    self.handleProcessingError(error)
                }
            }
        }
    }
    
    // MARK: - Enhanced Voice Processing Support Methods
    
    private func createVoiceProcessingContext() -> VoiceProcessingContext {
        let currentTime = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        
        let timeOfDay: String
        switch hour {
        case 5..<12:
            timeOfDay = "morning"
        case 12..<17:
            timeOfDay = "afternoon"
        case 17..<21:
            timeOfDay = "evening"
        default:
            timeOfDay = "night"
        }
        
        let deviceState = DeviceState(
            batteryLevel: UIDevice.current.batteryLevel,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            isNetworkAvailable: true, // Simplified for now
            isWifiConnected: true, // Simplified for now
            memoryUsage: 0.5 // Simplified for now
        )
        
        let previousIntent = conversationHistory.last?.isUser == false ? nil : nil // Could be enhanced to track actual intents
        
        return VoiceProcessingContext(
            timeOfDay: timeOfDay,
            location: nil, // Could be enhanced with location services
            previousIntent: previousIntent,
            conversationHistory: conversationHistory,
            userPreferences: [:], // Could be enhanced with user settings
            deviceState: deviceState
        )
    }
    
    private func handleEnhancedVoiceResult(_ result: EnhancedVoiceProcessingResult, fromWatch: Bool) {
        print("🧠 Enhanced processing completed:")
        print("   Intent: \(result.intent.displayName)")
        print("   Confidence: \(result.confidence)")
        print("   Method: \(result.processingMethod)")
        print("   Time: \(String(format: "%.2f", result.processingTime))s")
        print("   Offline: \(result.wasProcessedOffline)")
        print("   Explanation: \(result.routingExplanation)")
        
        // Create assistant response message
        let assistantMessage = ConversationMessage(
            id: UUID(),
            text: result.response.text,
            isUser: false,
            timestamp: Date(),
            audioBase64: result.response.audioBase64,
            isTranscribed: false
        )
        conversationHistory.append(assistantMessage)
        
        // Update UI with processing information
        currentStatus = .completed
        
        // Play audio response if available
        if let audioBase64 = result.response.audioBase64 {
            playAudioResponse(audioBase64, fromWatch: fromWatch)
        } else {
            // No audio, just show text response
            currentStatus = .idle
        }
        
        // Send to watch if not from watch
        if !fromWatch {
            watchConnector.sendResponse(result.response.text)
        }
        
        // Log the successful processing
        print("✅ Enhanced voice processing completed successfully")
    }
    
    private func handleProcessingError(_ error: Error) {
        print("❌ Enhanced voice processing failed: \(error.localizedDescription)")
        
        currentStatus = .error
        showError = true
        lastError = "Voice processing failed: \(error.localizedDescription)"
        
        // Send error to watch
        watchConnector.sendError(error.localizedDescription)
        
        // Reset to idle after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.currentStatus = .idle
        }
    }
    
    private func handleAPIResponse(_ response: VoiceResponse, fromWatch: Bool = false) {
        print("📱 iPhone: Received API response: '\(response.text)'")
        print("📱 iPhone: Response success: \(response.success)")
        print("📱 iPhone: Response audioBase64 length: \(response.audioBase64?.count ?? 0)")
        print("📱 iPhone: fromWatch = \(fromWatch)")
        
        // Check if we need to transcribe audio response
        if response.text.isEmpty && response.audioBase64 != nil {
            transcribeAudioResponse(response, fromWatch: fromWatch)
        } else {
            // Process response normally (with existing text)
            processVoiceResponse(response, transcribedText: response.text, fromWatch: fromWatch)
        }
    }
    
    private func handleEnhancedAPIResponse(_ enhancedResponse: EnhancedVoiceResponse, fromWatch: Bool = false) {
        print("📱 iPhone: Received enhanced API response: '\(enhancedResponse.text)'")
        print("📱 iPhone: Response success: \(enhancedResponse.success)")
        print("📱 iPhone: Response audioBase64 length: \(enhancedResponse.audioBase64?.count ?? 0)")
        print("📱 iPhone: Intent: \(enhancedResponse.intent ?? "unknown")")
        print("📱 iPhone: Confidence: \(enhancedResponse.confidence ?? 0.0)")
        print("📱 iPhone: Agent used: \(enhancedResponse.agentUsed ?? "unknown")")
        print("📱 iPhone: Execution time: \(enhancedResponse.executionTime ?? 0.0)s")
        print("📱 iPhone: fromWatch = \(fromWatch)")
        
        // Check if we need to transcribe audio response
        if enhancedResponse.text.isEmpty && enhancedResponse.audioBase64 != nil {
            transcribeEnhancedAudioResponse(enhancedResponse, fromWatch: fromWatch)
        } else {
            // Process response normally (with existing text)
            processEnhancedVoiceResponse(enhancedResponse, fromWatch: fromWatch)
        }
    }
    
    private func transcribeAudioResponse(_ response: VoiceResponse, fromWatch: Bool) {
        guard let audioBase64 = response.audioBase64,
              let audioData = Data(base64Encoded: audioBase64) else {
            print("❌ iPhone: No valid audio data for transcription")
            processVoiceResponse(response, transcribedText: "Audio response", fromWatch: fromWatch)
            return
        }
        
        print("🎤 iPhone: Transcribing audio response (\(audioData.count) bytes)")
        currentStatus = .transcribing
        
        // Add temporary message while transcribing
        let tempMessage = ConversationMessage(
            id: UUID(),
            text: "Transcribing audio...",
            isUser: false,
            timestamp: Date(),
            audioBase64: audioBase64,
            isTranscribed: false
        )
        conversationHistory.append(tempMessage)
        
        speechRecognizer.transcribe(audioData) { result in
            DispatchQueue.main.async {
                // Remove temporary message
                self.conversationHistory.removeAll { $0.id == tempMessage.id }
                
                switch result {
                case .success(let transcribedText):
                    print("✅ iPhone: Audio transcription successful: \(transcribedText)")
                    self.processVoiceResponse(response, transcribedText: transcribedText, fromWatch: fromWatch)
                case .failure(let error):
                    print("❌ iPhone: Audio transcription failed: \(error.localizedDescription)")
                    self.processVoiceResponse(response, transcribedText: "Audio response (transcription failed)", fromWatch: fromWatch)
                }
            }
        }
    }
    
    private func processVoiceResponse(_ response: VoiceResponse, transcribedText: String, fromWatch: Bool) {
        // Add assistant response to conversation with transcribed text and enhanced backend info
        let assistantMessage = ConversationMessage(
            id: UUID(),
            text: transcribedText,
            isUser: false,
            timestamp: Date(),
            audioBase64: response.audioBase64,
            isTranscribed: response.text.isEmpty && response.audioBase64 != nil,
            intent: nil, // Will be populated when using BackendVoiceResponse
            confidence: nil,
            agentUsed: nil,
            executionTime: nil,
            actions: nil,
            suggestions: nil
        )
        conversationHistory.append(assistantMessage)
        
        if fromWatch {
            // Send response back to watch - Watch will handle audio playback
            print("📤 iPhone: Sending response to Watch (Watch will play audio)")
            print("📤 iPhone: Response text being sent: '\(transcribedText)'")
            
            // Create updated response with transcribed text for watch
            let updatedResponse = VoiceResponse(
                text: transcribedText,
                success: response.success,
                audioBase64: response.audioBase64
            )
            watchConnector.sendVoiceResponse(updatedResponse)
            print("📤 iPhone: Response sent to Watch successfully")
        } else {
            // iPhone initiated - iPhone handles audio playback
            print("🔊 iPhone: Playing audio response (iPhone initiated)")
            if let audioBase64 = response.audioBase64 {
                print("🔊 iPhone: Audio base64 available, length: \(audioBase64.count)")
                playAudioResponse(audioBase64)
            } else {
                print("❌ iPhone: No audio data available in response")
            }
        }
        
        currentStatus = .playing
        
        // Status will be updated to idle when audio playback completes
    }
    
    private func transcribeEnhancedAudioResponse(_ enhancedResponse: EnhancedVoiceResponse, fromWatch: Bool = false) {
        print("🎯 Processing enhanced voice response with intent: \(enhancedResponse.intent ?? "none")")
        
        // Add enhanced assistant response to conversation history
        let enhancedMessage = ConversationMessage(
            text: enhancedResponse.text,
            isUser: false,
            audioBase64: enhancedResponse.audioBase64,
            intent: enhancedResponse.intent,
            confidence: enhancedResponse.confidence,
            agentUsed: enhancedResponse.agentUsed,
            executionTime: enhancedResponse.executionTime,
            actions: enhancedResponse.actions,
            suggestions: enhancedResponse.suggestions
        )
        
        conversationHistory.append(enhancedMessage)
        
        // Show result bottom sheet for AI responses (only for iPhone interactions, not Watch)
        if !fromWatch && enhancedResponse.audioBase64 != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                selectedMessage = enhancedMessage
                HapticManager.shared.cardTapped()
            }
        }
        
        if fromWatch {
            // Send response back to watch - Watch will handle audio playback
            print("📤 iPhone: Sending enhanced response to Watch (Watch will play audio)")
            print("📤 iPhone: Response text being sent: '\(enhancedResponse.text)'")
            
            // Create updated response with enhanced metadata for watch
            let updatedResponse = VoiceResponse(
                text: enhancedResponse.text,
                success: enhancedResponse.success,
                audioBase64: enhancedResponse.audioBase64
            )
            watchConnector.sendVoiceResponse(updatedResponse)
            print("📤 iPhone: Enhanced response sent to Watch successfully")
        } else {
            // iPhone initiated - iPhone handles audio playback
            print("🔊 iPhone: Playing enhanced audio response (iPhone initiated)")
            if let audioBase64 = enhancedResponse.audioBase64 {
                playAudioResponse(audioBase64)
            }
        }
        
        currentStatus = .playing
        
        // Status will be updated to idle when audio playback completes
    }
    
    private func processEnhancedVoiceResponse(_ enhancedResponse: EnhancedVoiceResponse, fromWatch: Bool = false) {
        print("🎯 Processing enhanced voice response with metadata")
        print("🎯 Intent: \(enhancedResponse.intent ?? "none")")
        print("🎯 Confidence: \(enhancedResponse.confidence ?? 0.0)")
        print("🎯 Agent used: \(enhancedResponse.agentUsed ?? "none")")
        print("🎯 Execution time: \(enhancedResponse.executionTime ?? 0.0)s")
        print("🎯 Actions: \(enhancedResponse.actions ?? [])")
        print("🎯 Suggestions: \(enhancedResponse.suggestions ?? [])")
        
        // Add enhanced assistant response to conversation history
        let enhancedMessage = ConversationMessage(
            text: enhancedResponse.text,
            isUser: false,
            audioBase64: enhancedResponse.audioBase64,
            intent: enhancedResponse.intent,
            confidence: enhancedResponse.confidence,
            agentUsed: enhancedResponse.agentUsed,
            executionTime: enhancedResponse.executionTime,
            actions: enhancedResponse.actions,
            suggestions: enhancedResponse.suggestions
        )
        
        conversationHistory.append(enhancedMessage)
        
        if fromWatch {
            // Send response back to watch - Watch will handle audio playback
            print("📤 iPhone: Sending enhanced response to Watch (Watch will play audio)")
            print("📤 iPhone: Response text being sent: '\(enhancedResponse.text)'")
            
            // Create updated response with enhanced metadata for watch
            let updatedResponse = VoiceResponse(
                text: enhancedResponse.text,
                success: enhancedResponse.success,
                audioBase64: enhancedResponse.audioBase64
            )
            watchConnector.sendVoiceResponse(updatedResponse)
            print("📤 iPhone: Enhanced response sent to Watch successfully")
        } else {
            // iPhone initiated - iPhone handles audio playback with autoplay
            print("🔊 iPhone: Playing enhanced audio response (iPhone initiated)")
            if let audioBase64 = enhancedResponse.audioBase64 {
                playAudioResponse(audioBase64)
            }
            
            // Show result bottom sheet after starting audio playback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                selectedMessage = enhancedMessage
                HapticManager.shared.cardTapped()
            }
        }
        
        currentStatus = .playing
        
        // Status will be updated to idle when audio playback completes
    }
    
    private func playAudioResponse(_ audioBase64: String) {
        // Check if audio data is empty
        if audioBase64.isEmpty {
            print("❌ Audio base64 string is empty - no audio to play")
            currentStatus = .idle
            return
        }
        
        guard let audioData = Data(base64Encoded: audioBase64) else {
            print("❌ Failed to decode base64 audio")
            currentStatus = .idle
            return
        }
        
        // Check if decoded audio data is empty
        if audioData.isEmpty {
            print("❌ Decoded audio data is empty - no audio to play")
            currentStatus = .idle
            return
        }
        
        print("🔊 Playing audio response (\(audioData.count) bytes)")
        
        // Debug: Check audio format by examining first few bytes
        if audioData.count >= 4 {
            let firstBytes = audioData.prefix(4).map { String(format: "%02x", $0) }.joined()
            print("🔊 Audio format signature: \(firstBytes)")
            
            // Common audio format signatures:
            // MP3: "494433" (ID3) or "FFFB"/"FFF3" (MP3 frame header)
            // WAV: "52494646" (RIFF)
            // M4A: "00000020" or "66747970"
            if firstBytes.hasPrefix("4944") {
                print("🔊 Detected ID3-tagged MP3 format")
            } else if firstBytes.hasPrefix("fff") {
                print("🔊 Detected raw MP3 format")
            } else if firstBytes.hasPrefix("5249") {
                print("🔊 Detected WAV format")
            } else {
                print("⚠️ Unknown audio format - first bytes: \(firstBytes)")
            }
        }
        
        do {
            // Set up audio session for playback
            print("🔊 Setting up audio session for playback...")
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("🔊 Audio session active: \(audioSession.isOtherAudioPlaying ? "Other audio playing" : "Ready")")
            
            // Create audio player
            print("🔊 Creating AVAudioPlayer...")
            audioPlayer = try AVAudioPlayer(data: audioData)
            
            // Set up delegate with callbacks
            audioPlayerDelegate.onFinished = { _ in
                DispatchQueue.main.async {
                    self.cleanupAudioPlayback()
                }
            }
            audioPlayerDelegate.onDecodeError = { _ in
                DispatchQueue.main.async {
                    self.currentStatus = .idle
                    self.cleanupAudioPlayback()
                }
            }
            audioPlayer?.delegate = audioPlayerDelegate
            audioPlayer?.volume = 1.0
            
            // Log audio player properties
            if let player = audioPlayer {
                print("🔊 Audio player created successfully")
                print("🔊 Player URL: \(player.url?.absoluteString ?? "Data-based")")
                print("🔊 Player numberOfChannels: \(player.numberOfChannels)")
                print("🔊 Player format: \(player.format.description)")
            }
            
            // Check if audio player is ready
            if audioPlayer?.prepareToPlay() == true {
                print("🔊 Audio player prepared successfully")
                
                if let duration = audioPlayer?.duration {
                    print("🔊 Audio duration: \(duration) seconds")
                }
                
                let success = audioPlayer?.play()
                print("🔊 Audio playback started: \(success == true ? "SUCCESS" : "FAILED")")
                
                // Check if actually playing
                if let isPlaying = audioPlayer?.isPlaying {
                    print("🔊 Audio player isPlaying: \(isPlaying)")
                }
                
                if let currentTime = audioPlayer?.currentTime {
                    print("🔊 Audio current time: \(currentTime)")
                }
                
                // Double-check playback status after a brief moment
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let isStillPlaying = self.audioPlayer?.isPlaying {
                        print("🔊 Audio still playing after 0.1s: \(isStillPlaying)")
                    }
                }
                
                if let duration = audioPlayer?.duration, duration > 0 {
                    // Schedule cleanup after playback completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) {
                        self.cleanupAudioPlayback()
                    }
                } else {
                    // Fallback cleanup in case duration is invalid
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.cleanupAudioPlayback()
                    }
                }
            } else {
                print("❌ Audio player failed to prepare")
                currentStatus = .idle
            }
            
        } catch {
            print("❌ Failed to play audio: \(error)")
            print("❌ Audio error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ Audio error code: \(nsError.code)")
                print("❌ Audio error domain: \(nsError.domain)")
                print("❌ Audio error userInfo: \(nsError.userInfo)")
            }
            currentStatus = .idle
        }
    }
    
    private func cleanupAudioPlayback() {
        print("🔊 Cleaning up audio playback")
        
        // Stop and cleanup audio player
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Reset audio session back to record mode for next interaction
        do {
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .default, 
                                       options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay])
            try audioSession.setPreferredIOBufferDuration(0.023)
            print("🔊 Audio session reset to record mode")
        } catch {
            print("❌ Failed to reset audio session: \(error)")
        }
        
        // Update status to idle after cleanup
        DispatchQueue.main.async {
            self.currentStatus = .idle
        }
    }
    
    
    private func handleTranscriptionError(_ error: Error) {
        currentStatus = .error
        watchConnector.sendError("Transcription failed: \(error.localizedDescription)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            currentStatus = .idle
        }
    }
    
    private func executeQuickAction(_ action: QuickAction) {
        print("🎯 Executing quick action: \(action.voiceCommand)")
        
        // Haptic feedback
        HapticManager.shared.commandSuccess()
        SoundManager.shared.playCommandSuccess()
        
        // Process the voice command directly
        handleTranscription(action.voiceCommand, fromWatch: false)
    }
    
    private func handleAPIError(_ error: Error) {
        currentStatus = .error
        
        var errorMessage = "API request failed: \(error.localizedDescription)"
        var shouldReturnToIdle = true
        
        // Handle different types of errors with specific responses
        if let voiceError = error as? VoiceAssistantError {
            switch voiceError {
            case .authenticationRequired, .authenticationFailed:
                errorMessage = "Authentication required. Please sign in."
                shouldReturnToIdle = false
                // This will trigger the authentication flow
                return
                
            case .tokenExpired, .tokenRefreshFailed:
                errorMessage = "Session expired. Please sign in again."
                shouldReturnToIdle = false
                // Clear stored tokens and trigger re-authentication
                apiClient.logout { _ in }
                return
                
            case .networkError:
                errorMessage = "Network connection failed. Please check your internet connection."
                
            case .backendUnavailable:
                errorMessage = "Service temporarily unavailable. Please try again later."
                
            case .rateLimitExceeded:
                errorMessage = "Too many requests. Please wait a moment before trying again."
                
            case .webSocketConnectionFailed:
                errorMessage = "Real-time connection failed. Using fallback mode."
                
            case .voiceProcessingFailed:
                errorMessage = "Voice processing failed. Please try again."
                
            case .audioEncodingFailed, .audioDecodingFailed:
                errorMessage = "Audio processing failed. Please try recording again."
                
            case .invalidAudioFormat:
                errorMessage = "Invalid audio format. Please try recording again."
                
            case .serverError(let code):
                errorMessage = "Server error (\(code)). Please try again later."
                
            case .unknownError(let message):
                errorMessage = "Unexpected error: \(message)"
                
            default:
                errorMessage = voiceError.localizedDescription
                if let recovery = voiceError.recoverySuggestion {
                    errorMessage += " \(recovery)"
                }
            }
        }
        
        print("❌ iPhone: API Error - \(errorMessage)")
        
        // Add error message to conversation history
        let errorConversationMessage = ConversationMessage(
            text: errorMessage,
            isUser: false,
            timestamp: Date()
        )
        conversationHistory.append(errorConversationMessage)
        
        // Send error to watch if applicable
        watchConnector.sendError(errorMessage)
        
        if shouldReturnToIdle {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                currentStatus = .idle
            }
        }
    }
}

// MARK: - Supporting Views

struct ConversationBubble: View {
    let message: ConversationMessage
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if !message.text.isEmpty {
                    VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                        Text(message.text)
                            .font(.body)
                            .foregroundColor(message.isUser ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(message.isUser ? Color.blue : Color(.systemGray5))
                            )
                        
                        // Show transcription indicator and replay button for AI responses
                        if !message.isUser && message.isTranscribed {
                            HStack {
                                Image(systemName: "waveform.badge.magnifyingglass")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Transcribed from audio")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                // Small replay button
                                Button(action: { replayAudio() }) {
                                    Image(systemName: isPlaying ? "stop.circle" : "play.circle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("Replay audio")
                                .accessibilityHint("Tap to replay the original audio")
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                } else if !message.isUser {
                        // This case should rarely happen now due to transcription
                    // Show clickable audio indicator for AI responses without text
                    Button(action: {
                        replayAudio()
                    }) {
                        HStack {
                            Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                .foregroundColor(.gray)
                                .font(.title3)
                            Text("Audio response (transcription failed)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if isPlaying {
                                Image(systemName: "waveform")
                                    .foregroundColor(.secondary)
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray5))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("AI audio response")
                    .accessibilityHint("Tap to replay audio response")
                }
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func replayAudio() {
        guard let audioBase64 = message.audioBase64,
              !audioBase64.isEmpty else {
            print("❌ No audio data available for replay")
            return
        }
        
        if isPlaying {
            // Stop current playback
            stopAudioPlayback()
        } else {
            // Start playback
            playAudioResponse(audioBase64)
        }
    }
    
    private func playAudioResponse(_ audioBase64: String) {
        guard let audioData = Data(base64Encoded: audioBase64) else {
            print("❌ Failed to decode base64 audio for replay")
            return
        }
        
        print("🔊 Replaying audio response (\(audioData.count) bytes)")
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.volume = 1.0
            
            if audioPlayer?.prepareToPlay() == true {
                let success = audioPlayer?.play()
                if success == true {
                    isPlaying = true
                    
                    // Schedule cleanup after playback completes
                    if let duration = audioPlayer?.duration {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
                            stopAudioPlayback()
                        }
                    }
                }
            }
        } catch {
            print("❌ Failed to replay audio: \(error)")
        }
    }
    
    private func stopAudioPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        
        // Reset audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .default, 
                                       options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay])
        } catch {
            print("❌ Failed to reset audio session after replay: \(error)")
        }
    }
}

// Chat-optimized bubble for dark theme
struct ConversationBubbleChat: View {
    let message: ConversationMessage
    let onTap: (() -> Void)?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    
    init(message: ConversationMessage, onTap: (() -> Void)? = nil) {
        self.message = message
        self.onTap = onTap
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if !message.text.isEmpty {
                    VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                        Group {
                            if !message.isUser && onTap != nil {
                                // Make AI responses tappable
                                Button(action: { onTap?() }) {
                                    Text(message.text)
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(Color.white.opacity(0.15))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("AI response: \(message.text). Double tap to view details")
                            } else {
                                // User messages (non-tappable)
                                Text(message.text)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(message.isUser ? 
                                                 Color(red: 0.8, green: 0.7, blue: 1.0) : // lilac for user
                                                 Color.white.opacity(0.15)) // semi-transparent white for AI
                                    )
                            }
                        }
                        
                        // Show transcription indicator and replay button for AI responses
                        if !message.isUser && message.isTranscribed {
                            HStack {
                                Image(systemName: "waveform.badge.magnifyingglass")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                                Text("Transcribed from audio")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Spacer()
                                
                                // Small replay button
                                Button(action: { replayAudio() }) {
                                    Image(systemName: isPlaying ? "stop.circle" : "play.circle")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("Replay audio")
                                .accessibilityHint("Tap to replay the original audio")
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    .accessibilityLabel(message.isUser ? "Your message" : (message.isTranscribed ? "AI response (transcribed from audio)" : "AI response"))
                    .accessibilityValue(message.text)
                } else if !message.isUser {
                    // This case should rarely happen now due to transcription
                    // Show clickable audio indicator for AI responses without text
                    Button(action: {
                        replayAudio()
                    }) {
                        HStack {
                            Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.title3)
                            Text("Audio response (transcription failed)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            if isPlaying {
                                Image(systemName: "waveform")
                                    .foregroundColor(.white.opacity(0.5))
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("AI audio response")
                    .accessibilityHint("Tap to replay audio response")
                }
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .accessibilityLabel("Time: \(formatTime(message.timestamp))")
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func replayAudio() {
        guard let audioBase64 = message.audioBase64,
              !audioBase64.isEmpty else {
            print("❌ No audio data available for replay")
            return
        }
        
        if isPlaying {
            // Stop current playback
            stopAudioPlayback()
        } else {
            // Start playback
            playAudioResponse(audioBase64)
        }
    }
    
    private func playAudioResponse(_ audioBase64: String) {
        guard let audioData = Data(base64Encoded: audioBase64) else {
            print("❌ Failed to decode base64 audio for replay")
            return
        }
        
        print("🔊 Replaying audio response (\(audioData.count) bytes)")
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.volume = 1.0
            
            if audioPlayer?.prepareToPlay() == true {
                let success = audioPlayer?.play()
                if success == true {
                    isPlaying = true
                    
                    // Schedule cleanup after playback completes
                    if let duration = audioPlayer?.duration {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
                            stopAudioPlayback()
                        }
                    }
                }
            }
        } catch {
            print("❌ Failed to replay audio: \(error)")
        }
    }
    
    private func stopAudioPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        
        // Reset audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .default, 
                                       options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay])
        } catch {
            print("❌ Failed to reset audio session after replay: \(error)")
        }
    }
}

struct LiveTranscriptionBubble: View {
    let text: String
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(text)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue.opacity(0.7))
                    )
                
                Text("Transcribing...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// Chat-optimized live transcription bubble
struct LiveTranscriptionBubbleChat: View {
    let text: String
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(text)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.8, green: 0.7, blue: 1.0).opacity(0.7)) // lilac with transparency
                    )
                
                Text("Transcribing...")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 8)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
}

struct AudioVisualizationView: View {
    let levels: [CGFloat]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: max(4, levels[index] * 50))
                    .animation(.easeInOut(duration: 0.1), value: levels[index])
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Binding var webhookURL: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    // API Configuration
                    VStack(alignment: .leading, spacing: 12) {
                        Text("API Configuration")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextField("Webhook URL", text: $webhookURL)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal)
                    
                    // Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Information")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SORA")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("AI-powered voice assistant with natural conversation capabilities.")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Done Button
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.blue)
                    )
                    .padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(webhookURL, forKey: Constants.StorageKeys.webhookURL)
        // Legacy webhook URL saving - keeping for backwards compatibility
    }
}

// MARK: - Menu View
struct MenuView: View {
    @Binding var conversationHistory: [ConversationMessage]
    @ObservedObject var apiClient: APIClient
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false
    @State private var showSettings = false
    @State private var showLogoutConfirmation = false
    @State private var webhookURL = Constants.API.webhookURL
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    HStack {
                        Text("Menu")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("Done") {
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Menu Options
                    VStack(spacing: 20) {
                        // Clear Chat History
                        Button(action: {
                            showClearConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                Text("Clear Chat History")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .confirmationDialog(
                            "Clear Chat History",
                            isPresented: $showClearConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Clear All Messages", role: .destructive) {
                                conversationHistory.removeAll()
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will permanently delete all messages in your conversation history.")
                        }
                        
                        // Enhanced Settings
                        Button(action: {
                            showSettings = true
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Settings")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        
                        // Logout
                        Button(action: {
                            showLogoutConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                Text("Logout")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .confirmationDialog(
                            "Logout",
                            isPresented: $showLogoutConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Logout", role: .destructive) {
                                handleLogout()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Are you sure you want to logout?")
                        }
                        
                        // Stats
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Statistics")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Total Messages: \(conversationHistory.count)")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            EnhancedSettingsView()
        }
    }
    
    private func handleLogout() {
        apiClient.logout { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Logout successful")
                    dismiss()
                case .failure(let error):
                    print("❌ Logout failed: \(error)")
                    // Still dismiss as we cleared local tokens
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Compact Quick Action Button

struct CompactQuickActionButton: View {
    let action: QuickAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(colorFromString(action.color).opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: action.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(colorFromString(action.color))
                }
                
                // Title
                Text(action.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(colorFromString(action.color).opacity(0.3), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: false)
        .accessibilityLabel(action.title)
        .accessibilityHint("Tap to \(action.voiceCommand.lowercased())")
    }
    
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "pink": return .pink
        case "gray": return .gray
        default: return .blue
        }
    }
}

// MARK: - Audio Player Delegate Helper
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinished: ((Bool) -> Void)?
    var onDecodeError: ((Error?) -> Void)?
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🔊 Audio playback finished successfully: \(flag)")
        onFinished?(flag)
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ Audio decode error occurred: \(error?.localizedDescription ?? "Unknown error")")
        onDecodeError?(error)
    }
    
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        print("🔊 Audio playback interrupted")
    }
    
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        print("🔊 Audio playback interruption ended with options: \(flags)")
    }
}

// MARK: - Offline Status Card
struct OfflineStatusCard: View {
    let mode: OfflineTransitionManager.ProcessingMode
    let connectionQuality: OfflineTransitionManager.ConnectionStatus.ConnectionQuality
    let availableCapabilities: [String]
    let queuedCommandsCount: Int
    let isDegraded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Mode icon and title
                HStack(spacing: 8) {
                    Image(systemName: mode.icon)
                        .foregroundColor(Color(mode.color))
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(mode.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Connection quality indicator
                if mode != .offline {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(connectionQuality == .excellent || connectionQuality == .good ? "green" : 
                                      connectionQuality == .fair ? "yellow" : "red"))
                            .frame(width: 8, height: 8)
                        
                        Text(connectionQuality.description)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            
            // Status message
            Text(getStatusMessage())
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.leading)
            
            // Capabilities and queue info
            if mode == .offline || !availableCapabilities.isEmpty {
                HStack {
                    if mode == .offline && !availableCapabilities.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Available offline:")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(availableCapabilities.prefix(3).joined(separator: ", "))
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    if queuedCommandsCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.badge")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            
                            Text("\(queuedCommandsCount) queued")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(mode.color).opacity(0.3), lineWidth: 1)
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func getStatusMessage() -> String {
        switch mode {
        case .online:
            return "All features available with full internet connectivity"
        case .offline:
            return "Working offline. Commands will sync when connection is restored."
        case .hybrid:
            return "Smart processing - using both online and offline capabilities"
        case .degraded:
            return isDegraded ? "Limited functionality due to connection issues" : "Running in reduced capability mode"
        }
    }
}

extension OfflineTransitionManager.ConnectionStatus.ConnectionQuality {
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}

extension Color {
    init(_ name: String) {
        switch name.lowercased() {
        case "green": self = .green
        case "yellow": self = .yellow
        case "orange": self = .orange
        case "red": self = .red
        case "blue": self = .blue
        case "purple": self = .purple
        default: self = .primary
        }
    }
}

#Preview {
    ContentView()
}
