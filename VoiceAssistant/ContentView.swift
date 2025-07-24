import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioRecorder = MinimalAudioRecorder()
    @State private var transcribedText = ""
    @State private var statusMessage = "Tap to record"
    @State private var showError = false
    @State private var responseText = ""
    @State private var showResponse = false
    
    var body: some View {
        VStack(spacing: 20) {
            headerView
            permissionView
            statusView
            recordingButton
            recordingTimeView
            audioLevelMeter
            quickActionsView
            responseView
            transcriptionView
            Spacer()
            debugView
        }
        .padding()
        .alert("Recording Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(audioRecorder.error?.errorDescription ?? "Unknown error occurred")
        }
        .onChange(of: audioRecorder.error) { error in
            showError = (error != nil)
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Voice Assistant")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your AI-powered assistant")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
        Text(statusMessage)
            .foregroundColor(.gray)
            .font(.subheadline)
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
                .foregroundColor(.secondary)
            
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
    
    private var responseView: some View {
        Group {
            if showResponse && !responseText.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text("AI Response")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: { showResponse = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(responseText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showResponse)
            }
        }
    }
    
    private var transcriptionView: some View {
        Group {
            if !transcribedText.isEmpty && !showResponse {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Transcription", systemImage: "text.bubble")
                        .font(.headline)
                    
                    Text(transcribedText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var debugView: some View {
        Group {
            #if DEBUG
            Button("Check Circuit Breakers") {
                FeatureCircuitBreakers.printStatus()
            }
            .font(.caption)
            .foregroundColor(.gray)
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
                        // Use API connection circuit breaker for network calls
                        await FeatureCircuitBreakers.apiConnection.executeFeature {
                            do {
                                let response = try await MinimalAPIClient.shared.processAudio(url: audioURL)
                                await MainActor.run {
                                    responseText = response
                                    showResponse = true
                                    statusMessage = "Tap to record"
                                }
                            } catch {
                                await MainActor.run {
                                    // Provide user-friendly error messages
                                    switch error {
                                    case APIError.httpError(let code) where code == 401:
                                        responseText = "Authentication required. Please sign in."
                                    case APIError.httpError(let code) where code == 429:
                                        responseText = "Rate limit exceeded. Please try again later."
                                    case APIError.httpError(let code) where code >= 500:
                                        responseText = "Server error. Please try again later."
                                    case APIError.fileReadError:
                                        responseText = "Failed to read audio file."
                                    case APIError.noResponseText:
                                        responseText = "No response from server. Please try again."
                                    case APIError.invalidAudioFormat(let message):
                                        responseText = "Audio format issue: \(message)"
                                    default:
                                        responseText = "Connection error: \(error.localizedDescription)"
                                    }
                                    showResponse = true
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
            }
            
            if !success {
                statusMessage = "Recording temporarily disabled"
                transcribedText = "Audio recording has been disabled due to repeated failures. Please try again later."
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
        transcribedText = action.voiceCommand
        showResponse = false
        
        Task {
            await FeatureCircuitBreakers.apiConnection.executeFeature {
                do {
                    let response = try await MinimalAPIClient.shared.processText(action.voiceCommand)
                    await MainActor.run {
                        responseText = response
                        showResponse = true
                        statusMessage = "Tap to record"
                    }
                } catch {
                    await MainActor.run {
                        responseText = "Failed to process: \(error.localizedDescription)"
                        showResponse = true
                        statusMessage = "Tap to record"
                    }
                }
            }
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
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
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