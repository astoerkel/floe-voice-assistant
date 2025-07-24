import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioRecorder = MinimalAudioRecorder()
    @State private var transcribedText = ""
    @State private var statusMessage = "Tap to record"
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 20) {
            headerView
            permissionView
            statusView
            recordingButton
            recordingTimeView
            audioLevelMeter
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
        Text("VoiceAssistant - Phase 1")
            .font(.largeTitle)
            .fontWeight(.bold)
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
    
    private var transcriptionView: some View {
        Group {
            if !transcribedText.isEmpty {
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
                                    transcribedText = response
                                    statusMessage = "Tap to record"
                                }
                            } catch {
                                await MainActor.run {
                                    // Provide user-friendly error messages
                                    switch error {
                                    case APIError.httpError(let code) where code == 401:
                                        transcribedText = "Authentication required. Please sign in."
                                    case APIError.httpError(let code) where code == 429:
                                        transcribedText = "Rate limit exceeded. Please try again later."
                                    case APIError.httpError(let code) where code >= 500:
                                        transcribedText = "Server error. Please try again later."
                                    case APIError.fileReadError:
                                        transcribedText = "Failed to read audio file."
                                    case APIError.noResponseText:
                                        transcribedText = "No response from server. Please try again."
                                    default:
                                        transcribedText = "Connection error: \(error.localizedDescription)"
                                    }
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
}

// MARK: - Recording Button Component

struct RecordingButtonView: View {
    let isRecording: Bool
    let audioLevel: Float
    let hasPermission: Bool
    let action: () -> Void
    
    var body: some View {
        ZStack {
            // Audio level indicator
            if isRecording {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: buttonSize + (CGFloat(audioLevel) * 40),
                           height: buttonSize + (CGFloat(audioLevel) * 40))
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
            
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.blue)
                        .frame(width: buttonSize, height: buttonSize)
                    
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }
            .disabled(!hasPermission)
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