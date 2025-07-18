import SwiftUI

struct ContextHintsView: View {
    let state: VoiceState
    let isConnected: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            if shouldShowHints {
                Text(hintText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .opacity(hintOpacity)
                    .animation(.easeInOut(duration: 0.3), value: state)
            }
        }
        .frame(height: 30)
    }
    
    private var shouldShowHints: Bool {
        switch state {
        case .idle, .error:
            return true
        case .listening, .processing, .responding:
            return false
        }
    }
    
    private var hintText: String {
        let canProcess = isConnected || WatchAPIClient.shared.isConnected
        
        if !canProcess {
            return "No connection"
        }
        
        switch state {
        case .idle:
            if isConnected {
                return "Tap to ask (iPhone)"
            } else if WatchAPIClient.shared.isConnected {
                return "Tap to ask (Direct)"
            } else {
                return "Tap to ask"
            }
        case .error:
            return "Tap to retry"
        default:
            return ""
        }
    }
    
    private var hintOpacity: Double {
        switch state {
        case .idle:
            return 0.8
        case .error:
            return 0.9
        default:
            return 0.0
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ContextHintsView(state: .idle, isConnected: true)
        ContextHintsView(state: .listening, isConnected: true)
        ContextHintsView(state: .processing, isConnected: true)
        ContextHintsView(state: .responding, isConnected: true)
        ContextHintsView(state: .error, isConnected: false)
    }
    .padding()
}