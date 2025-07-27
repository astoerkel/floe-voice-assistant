import Foundation
import SwiftUI
import Combine

class VoiceResponseHandler: ObservableObject {
    @Published var currentResponse: VoiceResponseDisplay?
    @Published var isDisplayingResponse: Bool = false
    
    private let hapticManager = HapticFeedbackManager.shared
    private var dismissTimer: Timer?
    
    struct VoiceResponseDisplay {
        let text: String
        let actionType: HapticFeedbackManager.ActionType
        let hapticPattern: HapticFeedbackManager.HapticPattern
        let displayDuration: TimeInterval
        let success: Bool
        let timestamp: Date
        
        init(text: String, success: Bool, actionType: HapticFeedbackManager.ActionType? = nil) {
            self.text = text
            self.success = success
            self.timestamp = Date()
            
            let detectedActionType = actionType ?? HapticFeedbackManager.shared.determineActionType(from: text)
            self.actionType = detectedActionType
            self.hapticPattern = success ? .response(detectedActionType) : .error
            self.displayDuration = success ? 5.0 : 3.0
        }
    }
    
    func handleResponse(_ response: VoiceResponse) {
        let responseDisplay = VoiceResponseDisplay(
            text: response.text,
            success: response.success
        )
        
        DispatchQueue.main.async {
            self.currentResponse = responseDisplay
            self.isDisplayingResponse = true
            
            // Trigger haptic feedback
            self.hapticManager.triggerHaptic(for: responseDisplay.hapticPattern)
            
            // Schedule auto-dismiss
            self.scheduleAutoDismiss(after: responseDisplay.displayDuration)
        }
    }
    
    func handleError(_ error: String) {
        let errorResponse = VoiceResponseDisplay(
            text: error,
            success: false
        )
        
        DispatchQueue.main.async {
            self.currentResponse = errorResponse
            self.isDisplayingResponse = true
            
            // Trigger error haptic
            self.hapticManager.triggerHaptic(for: .error)
            
            // Schedule auto-dismiss
            self.scheduleAutoDismiss(after: errorResponse.displayDuration)
        }
    }
    
    func dismissResponse() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        DispatchQueue.main.async {
            self.isDisplayingResponse = false
            
            // Clear response after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.currentResponse = nil
            }
        }
    }
    
    private func scheduleAutoDismiss(after duration: TimeInterval) {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismissResponse()
        }
    }
    
    func getResponseColor() -> Color {
        guard let response = currentResponse else { return .primary }
        
        if !response.success {
            return .red
        }
        
        switch response.actionType {
        case .calendar:
            return .blue
        case .email:
            return .green
        case .task:
            return .orange
        case .reminder:
            return .purple
        case .query:
            return .cyan
        case .general:
            return .primary
        }
    }
    
    func getResponseIcon() -> String {
        guard let response = currentResponse else { return "questionmark.circle" }
        
        if !response.success {
            return "xmark.circle.fill"
        }
        
        switch response.actionType {
        case .calendar:
            return "calendar.circle.fill"
        case .email:
            return "envelope.circle.fill"
        case .task:
            return "checkmark.circle.fill"
        case .reminder:
            return "bell.circle.fill"
        case .query:
            return "questionmark.circle.fill"
        case .general:
            return "checkmark.circle.fill"
        }
    }
}

struct ResponseDisplayView: View {
    @ObservedObject var handler: VoiceResponseHandler
    
    var body: some View {
        if handler.isDisplayingResponse, let response = handler.currentResponse {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: handler.getResponseIcon())
                        .foregroundColor(handler.getResponseColor())
                        .font(.caption)
                    
                    Spacer()
                    
                    Button(action: {
                        handler.dismissResponse()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Text(response.text)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.1))
                    .shadow(radius: 2)
            )
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.3), value: handler.isDisplayingResponse)
        }
    }
}

#Preview {
    let handler = VoiceResponseHandler()
    handler.handleResponse(VoiceResponse(text: "Your next meeting is at 2 PM today", success: true, audioBase64: nil))
    
    return ResponseDisplayView(handler: handler)
        .padding()
}