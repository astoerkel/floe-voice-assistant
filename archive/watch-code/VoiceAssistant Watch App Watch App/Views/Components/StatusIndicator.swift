import SwiftUI

struct StatusIndicator: View {
    let state: VoiceState
    let isConnected: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 6, height: 6)
                
                Text(connectionText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
    
    private var connectionColor: Color {
        if isConnected {
            return .green
        } else if WatchAPIClient.shared.isConnected {
            return .blue
        } else {
            return .red
        }
    }
    
    private var connectionText: String {
        if isConnected {
            return "iPhone"
        } else if WatchAPIClient.shared.isConnected {
            return "Direct"
        } else {
            return "Offline"
        }
    }
    
    private var statusText: String {
        switch state {
        case .idle:
            return "Tap to speak"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .responding:
            return "Playing..."
        case .error:
            return "Error"
        }
    }
    
    private var statusColor: Color {
        switch state {
        case .idle:
            return .primary
        case .listening:
            return .blue
        case .processing:
            return .orange
        case .responding:
            return .green
        case .error:
            return .red
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StatusIndicator(state: .idle, isConnected: true)
        StatusIndicator(state: .listening, isConnected: true)
        StatusIndicator(state: .processing, isConnected: true)
        StatusIndicator(state: .responding, isConnected: true)
        StatusIndicator(state: .error, isConnected: false)
    }
    .padding()
}