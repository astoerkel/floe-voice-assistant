import SwiftUI

struct QuickActionsView: View {
    @ObservedObject private var phoneConnector = PhoneConnector.shared
    @ObservedObject private var hapticManager = HapticFeedbackManager.shared
    @State private var selectedAction: QuickAction?
    
    private let quickActions: [QuickAction] = [
        QuickAction(
            id: "calendar-next",
            title: "Next Meeting",
            icon: "calendar.circle.fill",
            voiceCommand: "What's my next meeting?",
            color: "blue"
        ),
        QuickAction(
            id: "task-add",
            title: "Add Task",
            icon: "plus.circle.fill",
            voiceCommand: "Add a task",
            color: "orange"
        ),
        QuickAction(
            id: "email-check",
            title: "Check Email",
            icon: "envelope.circle.fill",
            voiceCommand: "Check my emails",
            color: "green"
        ),
        QuickAction(
            id: "reminder-set",
            title: "Set Reminder",
            icon: "bell.circle.fill",
            voiceCommand: "Set a reminder",
            color: "purple"
        ),
        QuickAction(
            id: "schedule-today",
            title: "Today's Schedule",
            icon: "list.bullet.circle.fill",
            voiceCommand: "What's my schedule today?",
            color: "cyan"
        ),
        QuickAction(
            id: "task-complete",
            title: "Mark Complete",
            icon: "checkmark.circle.fill",
            voiceCommand: "Mark task as complete",
            color: "mint"
        )
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(quickActions) { action in
                    QuickActionButton(
                        action: action,
                        isSelected: selectedAction?.id == action.id,
                        isEnabled: phoneConnector.isConnected
                    ) {
                        handleQuickAction(action)
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ConnectionStatusView(isConnected: phoneConnector.isConnected)
            }
        }
    }
    
    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }
    
    private func handleQuickAction(_ action: QuickAction) {
        guard phoneConnector.isConnected else {
            hapticManager.triggerHaptic(for: .error)
            return
        }
        
        selectedAction = action
        hapticManager.triggerHaptic(for: .listening)
        
        // Simulate voice command by sending the text directly
        sendQuickCommand(action.voiceCommand)
        
        // Reset selection after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            selectedAction = nil
        }
    }
    
    private func sendQuickCommand(_ command: String) {
        // Update phone connector status
        phoneConnector.currentStatus = .transcribing
        
        // Send command to phone
        let message: [String: Any] = [
            "type": "quickAction",
            "command": command,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let watchSession = phoneConnector.session, watchSession.isReachable {
            watchSession.sendMessage(message, replyHandler: { response in
                print("📥 Watch: Quick action acknowledgment received")
            }, errorHandler: { error in
                print("❌ Watch: Quick action failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.phoneConnector.currentStatus = .error
                    self.phoneConnector.errorMessage = "Failed to send quick action"
                }
            })
        }
    }
}


struct QuickActionButton: View {
    let action: QuickAction
    let isSelected: Bool
    let isEnabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                
                Text(action.title)
                    .font(.caption2)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(backgroundColor)
            .cornerRadius(12)
            .scaleEffect(isSelected ? 0.95 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
            .animation(.easeInOut(duration: 0.1), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(action.title)
        .accessibilityHint("Double tap to execute \(action.voiceCommand)")
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return colorFromString(action.color).opacity(0.8)
        } else {
            return colorFromString(action.color).opacity(0.2)
        }
    }
    
    private var iconColor: Color {
        if isSelected {
            return .white
        } else {
            return colorFromString(action.color)
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else {
            return .primary
        }
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
        case "cyan": return .cyan
        case "mint": return .mint
        default: return .blue
        }
    }
}

struct ConnectionStatusView: View {
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? .green : .red)
                .frame(width: 6, height: 6)
            
            Text(isConnected ? "Connected" : "Offline")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    QuickActionsView()
}