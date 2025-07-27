import SwiftUI
import AVFoundation

struct MinimalContentView: View {
    @StateObject private var audioRecorder = MinimalAudioRecorder()
    @State private var transcribedText = ""
    @State private var statusMessage = "Tap to record"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("VoiceAssistant")
                .font(.largeTitle)
            
            Text(statusMessage)
                .foregroundColor(.gray)
            
            Button(action: toggleRecording) {
                Image(systemName: audioRecorder.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 60))
                    .foregroundColor(audioRecorder.isRecording ? .red : .blue)
            }
            
            if !transcribedText.isEmpty {
                Text("You said: \(transcribedText)")
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
    
    func toggleRecording() {
        if audioRecorder.isRecording {
            // Stop recording
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
            }
        } else {
            // Start recording
            audioRecorder.startRecording()
            statusMessage = "Recording..."
            transcribedText = ""
        }
    }
}