import SwiftUI

struct VoiceButton: View {
    let state: VoiceState
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundGradient)
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
                    .scaleEffect(scaleEffect)
                    .animation(.easeInOut(duration: 0.2), value: state)
                
                Image(systemName: buttonIcon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundColor(iconColor)
                    .animation(.easeInOut(duration: 0.2), value: state)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    private var backgroundGradient: LinearGradient {
        switch state {
        case .idle:
            return LinearGradient(
                gradient: Gradient(colors: [.blue, .purple]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .listening:
            return LinearGradient(
                gradient: Gradient(colors: [.red, .orange]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .processing:
            return LinearGradient(
                gradient: Gradient(colors: [.orange, .yellow]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .responding:
            return LinearGradient(
                gradient: Gradient(colors: [.green, .mint]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .error:
            return LinearGradient(
                gradient: Gradient(colors: [.red, .red]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var strokeColor: Color {
        switch state {
        case .idle:
            return .clear
        case .listening:
            return .white.opacity(0.8)
        case .processing:
            return .white.opacity(0.6)
        case .responding:
            return .white.opacity(0.4)
        case .error:
            return .white.opacity(0.8)
        }
    }
    
    private var strokeWidth: CGFloat {
        switch state {
        case .idle:
            return 0
        case .listening:
            return 3
        case .processing:
            return 2
        case .responding:
            return 1
        case .error:
            return 3
        }
    }
    
    private var scaleEffect: CGFloat {
        switch state {
        case .idle:
            return 1.0
        case .listening:
            return 1.1
        case .processing:
            return 0.95
        case .responding:
            return 1.05
        case .error:
            return 0.9
        }
    }
    
    private var buttonIcon: String {
        switch state {
        case .idle:
            return "mic.fill"
        case .listening:
            return "stop.circle.fill"
        case .processing:
            return "waveform.circle.fill"
        case .responding:
            return "speaker.wave.2.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
    
    private var iconSize: CGFloat {
        switch state {
        case .idle:
            return 20
        case .listening:
            return 16
        case .processing:
            return 18
        case .responding:
            return 16
        case .error:
            return 16
        }
    }
    
    private var iconColor: Color {
        return .white
    }
    
    private var accessibilityLabel: String {
        switch state {
        case .idle:
            return "Voice recording button"
        case .listening:
            return "Stop recording"
        case .processing:
            return "Processing voice"
        case .responding:
            return "Playing response"
        case .error:
            return "Error occurred"
        }
    }
    
    private var accessibilityHint: String {
        switch state {
        case .idle:
            return "Tap to start voice recording"
        case .listening:
            return "Tap to stop recording"
        case .processing:
            return "Voice is being processed"
        case .responding:
            return "Response is being played"
        case .error:
            return "An error occurred, tap to retry"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        VoiceButton(state: .idle, action: {})
            .frame(width: 80, height: 80)
        
        VoiceButton(state: .listening, action: {})
            .frame(width: 80, height: 80)
        
        VoiceButton(state: .processing, action: {})
            .frame(width: 80, height: 80)
        
        VoiceButton(state: .responding, action: {})
            .frame(width: 80, height: 80)
        
        VoiceButton(state: .error, action: {})
            .frame(width: 80, height: 80)
    }
    .padding()
}