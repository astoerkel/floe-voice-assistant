import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioRecorder = MinimalAudioRecorder()
    @State private var transcribedText = ""
    @State private var statusMessage = "Tap to record"
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("VoiceAssistant - Phase 1")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Permission Status
            if !audioRecorder.hasPermission {
                Label("Microphone permission required", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }
            
            // Status Message
            Text(statusMessage)
                .foregroundColor(.gray)
                .font(.subheadline)
            
            // Recording Button with Visual Feedback
            ZStack {
                // Audio level indicator
                if audioRecorder.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 120 + (audioRecorder.audioLevel * 40), 
                               height: 120 + (audioRecorder.audioLevel * 40))
                        .animation(.easeInOut(duration: 0.1), value: audioRecorder.audioLevel)
                }
                
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
                .disabled(!audioRecorder.hasPermission)
            }
            
            // Recording Time
            if audioRecorder.isRecording {
                Text(timeString(from: audioRecorder.recordingTime))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundColor(.red)
            }
            
            // Audio Level Meter
            if audioRecorder.isRecording {
                HStack(spacing: 2) {
                    ForEach(0..<20) { index in
                        Rectangle()
                            .fill(audioLevelColor(for: index))
                            .frame(width: 8, height: 20)
                            .opacity(Double(index) / 20.0 <= Double(audioRecorder.audioLevel) ? 1.0 : 0.3)
                    }
                }
                .frame(height: 20)
                .padding(.horizontal)
            }
            
            // Transcribed Text
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
            
            Spacer()
            
            // Circuit Breaker Status (Debug)
            #if DEBUG
            Button("Check Circuit Breakers") {
                FeatureCircuitBreakers.printStatus()
            }
            .font(.caption)
            .foregroundColor(.gray)
            #endif
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
    
    func toggleRecording() {
        if audioRecorder.isRecording {
            // Stop recording with circuit breaker
            FeatureCircuitBreakers.audioRecording.executeFeature {
                statusMessage = "Processing..."
                if let audioURL = audioRecorder.stopRecording() {
                    Task {
                        do {
                            let response = try await MinimalAPIClient.shared.processAudio(url: audioURL)
                            await MainActor.run {
                                transcribedText = response
                                statusMessage = "Tap to record"
                            }
                        } catch {
                            await MainActor.run {
                                transcribedText = "Error: \(error.localizedDescription)"
                                statusMessage = "Tap to record"
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
    
    // Helper function for audio level color
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