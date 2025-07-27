import SwiftUI
import AVFoundation
import Speech

struct SimpleContentView: View {
    @ObservedObject private var apiClient = SimpleAPIClient.shared
    @StateObject private var speechRecognizer = SimpleSpeechRecognizer()
    @StateObject private var conversationManager = SimpleConversationManager()
    @StateObject private var audioRecorder = MinimalAudioRecorder()
    @StateObject private var audioLevelDetector = AudioLevelDetector()
    @StateObject private var themeManager = ThemeManager.shared
    
    @State private var isRecording = false
    @State private var statusMessage = "Tap to record"
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isAudioPlaying = false
    @State private var audioPlayerDelegate: AudioPlayerDelegate?
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Adaptive background
                Group {
                    if themeManager.themeMode == .dark || 
                       (themeManager.themeMode == .system && UITraitCollection.current.userInterfaceStyle == .dark) {
                        Color.black
                    } else {
                        Color(red: 0.98, green: 0.98, blue: 0.98)
                    }
                }
                .ignoresSafeArea()
                
                // Particle animation background
                ParticleBackgroundView(
                    isVoiceActive: isRecording,
                    isAudioPlaying: isAudioPlaying,
                    audioLevel: audioLevelDetector.audioLevel
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Floe")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.themeMode == .light ? .black : .white)
                        
                        Text("Simple Voice Assistant")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Conversation History
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(conversationManager.conversationHistory) { message in
                                MessageBubble(message: message)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 400)
                    
                    Spacer()
                    
                    // Status Message with Loading Indicator
                    VStack(spacing: 12) {
                        if isProcessing {
                            CompactLoadingIndicator()
                        }
                        
                        Text(statusMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Recording Button
                    Button(action: {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red : Color.blue)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isProcessing || !apiClient.isAuthenticated)
                    .scaleEffect(isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isRecording)
                    
                    // Authentication Status
                    if !apiClient.isAuthenticated {
                        Text("Please authenticate to use voice assistant")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal)
                    } else {
                        // Debug logout button (for testing)
                        #if DEBUG
                        Button("Logout (Debug)") {
                            apiClient.forceLogout()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        #endif
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(false)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: 
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSettings = true 
                    }
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(themeManager.themeMode == .light ? .black : .white)
                }
            )
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .fullScreenCover(isPresented: .constant(!apiClient.isAuthenticated)) {
            SimpleAuthenticationView(apiClient: apiClient)
        }
        .navigationDrawer(isPresented: $showSettings) {
            SimpleSettingsView(conversationManager: conversationManager, isPresented: $showSettings)
        }
    }
    
    // MARK: - Recording Functions
    private func startRecording() {
        guard speechRecognizer.isAuthorized else {
            showError(message: "Speech recognition not authorized")
            return
        }
        
        guard audioRecorder.hasPermission else {
            showError(message: "Microphone permission not granted")
            return
        }
        
        isRecording = true
        statusMessage = "Listening..."
        audioRecorder.startRecording()
        audioLevelDetector.startMonitoring()
    }
    
    private func stopRecording() {
        audioLevelDetector.stopMonitoring()
        
        guard let audioURL = audioRecorder.stopRecording() else {
            showError(message: "Failed to stop recording")
            resetState()
            return
        }
        
        isRecording = false
        statusMessage = "Processing..."
        isProcessing = true
        
        // Convert URL to Data for transcription
        do {
            let audioData = try Data(contentsOf: audioURL)
            transcribeAudio(audioData)
        } catch {
            showError(message: "Failed to read audio file: \(error.localizedDescription)")
            resetState()
        }
    }
    
    private func transcribeAudio(_ audioData: Data) {
        speechRecognizer.transcribe(audioData) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transcription):
                    self.handleTranscription(transcription)
                case .failure(let error):
                    self.showError(message: "Transcription failed: \(error.localizedDescription)")
                    self.resetState()
                }
            }
        }
    }
    
    private func handleTranscription(_ text: String) {
        guard !text.isEmpty else {
            showError(message: "No speech detected")
            resetState()
            return
        }
        
        // Add user message to conversation
        let userMessage = ConversationMessage(
            text: text,
            isUser: true,
            isTranscribed: true
        )
        conversationManager.addMessage(userMessage)
        
        // Process with simple backend
        processWithSimpleBackend(text)
    }
    
    private func processWithSimpleBackend(_ text: String) {
        apiClient.processTextSimple(text: text) { result in
            DispatchQueue.main.async {
                isProcessing = false
                
                switch result {
                case .success(let voiceResponse):
                    // Add AI response to conversation
                    let aiMessage = ConversationMessage(
                        text: voiceResponse.text,
                        isUser: false,
                        audioBase64: voiceResponse.audioBase64,
                        isTranscribed: false
                    )
                    conversationManager.addMessage(aiMessage)
                    
                    // Play audio if available
                    if let audioBase64 = voiceResponse.audioBase64, !audioBase64.isEmpty {
                        playAudioResponse(audioBase64: audioBase64)
                    }
                    
                    statusMessage = "Tap to record"
                    
                case .failure(let error):
                    showError(message: "Processing failed: \(error.localizedDescription)")
                    resetState()
                }
            }
        }
    }
    
    private func playAudioResponse(audioBase64: String) {
        guard let audioData = Data(base64Encoded: audioBase64) else {
            print("❌ Failed to decode audio data")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayerDelegate = AudioPlayerDelegate { [self] in
                DispatchQueue.main.async {
                    isAudioPlaying = false
                }
            }
            audioPlayer?.delegate = audioPlayerDelegate
            
            isAudioPlaying = true
            audioPlayer?.play()
            
        } catch {
            print("❌ Failed to play audio: \(error)")
            isAudioPlaying = false
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
        resetState()
    }
    
    private func resetState() {
        isRecording = false
        isProcessing = false
        statusMessage = "Tap to record"
    }
}

struct MessageBubble: View {
    let message: ConversationMessage
    @Environment(\.colorScheme) var colorScheme
    
    private var userBubbleColor: Color {
        colorScheme == .dark ? Color(white: 0.9) : Color(white: 0.95)
    }
    
    private var aiBubbleColor: Color {
        colorScheme == .dark ? Color.blue : Color.blue.opacity(0.9)
    }
    
    private var userTextColor: Color {
        colorScheme == .dark ? .black : .black
    }
    
    private var aiTextColor: Color {
        .white
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(message.isUser ? userTextColor : aiTextColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isUser ? userBubbleColor : aiBubbleColor)
                    )
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

// Helper for audio playback delegation
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

#Preview {
    SimpleContentView()
}