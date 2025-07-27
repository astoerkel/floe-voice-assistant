import SwiftUI

struct EnhancedVoiceView: View {
    @StateObject private var voiceManager = WatchVoiceManager()
    @StateObject private var responseHandler = VoiceResponseHandler()
    @ObservedObject private var phoneConnector = PhoneConnector.shared
    
    @State private var isRecording = false
    @State private var currentState: VoiceState = .idle
    
    var body: some View {
        ZStack {
            // Main voice interface
            VStack(spacing: 4) {
                // Status indicator
                StatusIndicator(
                    state: currentState,
                    isConnected: phoneConnector.isConnected
                )
                .frame(height: 28)
                
                Spacer(minLength: 2)
                
                // Enhanced waveform visualization
                WaveformView(
                    levels: voiceManager.audioLevels,
                    state: currentState
                )
                .frame(height: 25)
                
                Spacer(minLength: 2)
                
                // Main voice button with state-based styling
                VoiceButton(
                    state: currentState,
                    action: handleVoiceInput
                )
                .frame(width: 60, height: 60)
                
                Spacer(minLength: 2)
                
                // Context hints
                ContextHintsView(
                    state: currentState,
                    isConnected: phoneConnector.isConnected
                )
                .frame(height: 20)
                
                // Error message
                if let errorMessage = phoneConnector.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            
            // Response overlay
            VStack {
                Spacer()
                ResponseDisplayView(handler: responseHandler)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .onReceive(voiceManager.$currentState) { state in
            withAnimation(.easeInOut(duration: 0.2)) {
                currentState = state
            }
        }
        .onReceive(voiceManager.$isRecording) { recording in
            isRecording = recording
        }
        .onReceive(voiceManager.$responseReceived) { response in
            if !response.isEmpty {
                // Create a VoiceResponse object for the handler
                let voiceResponse = VoiceResponse(
                    text: response,
                    success: true,
                    audioBase64: nil
                )
                responseHandler.handleResponse(voiceResponse)
            }
        }
        .onReceive(phoneConnector.$lastResponse) { response in
            if let response = response {
                responseHandler.handleResponse(response)
            }
        }
        .onReceive(phoneConnector.$errorMessage) { errorMessage in
            if let error = errorMessage {
                responseHandler.handleError(error)
            }
        }
        .onAppear {
            // Reset state when view appears
            voiceManager.reset()
            currentState = .idle
        }
    }
    
    private func handleVoiceInput() {
        voiceManager.handleVoiceInput()
    }
}

#Preview {
    EnhancedVoiceView()
}