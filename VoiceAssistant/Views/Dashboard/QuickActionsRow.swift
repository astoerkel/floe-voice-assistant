//
//  QuickActionsRow.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI

struct QuickActionsRow: View {
    @State private var showingVoiceInterface = false
    
    private let quickActions: [QuickAction] = [
        QuickAction(
            id: "calendar",
            title: "Schedule",
            icon: "calendar.badge.plus",
            voiceCommand: "Schedule a meeting",
            color: "blue"
        ),
        QuickAction(
            id: "email",
            title: "Email",
            icon: "envelope",
            voiceCommand: "Check my emails",
            color: "red"
        ),
        QuickAction(
            id: "tasks",
            title: "Tasks",
            icon: "checkmark.circle",
            voiceCommand: "Add a new task",
            color: "green"
        ),
        QuickAction(
            id: "reminder",
            title: "Reminder",
            icon: "bell",
            voiceCommand: "Set a reminder",
            color: "orange"
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(quickActions) { action in
                        QuickActionButton(
                            action: action,
                            onTap: { executeQuickAction(action) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .sheet(isPresented: $showingVoiceInterface) {
            ContentView()
        }
    }
    
    private func executeQuickAction(_ action: QuickAction) {
        // Simulate executing the voice command
        print("Executing quick action: \(action.voiceCommand)")
        
        // For now, just show the voice interface
        showingVoiceInterface = true
    }
}


struct QuickActionButton: View {
    let action: QuickAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(colorFromString(action.color).opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: action.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(colorFromString(action.color))
                }
                
                // Title
                Text(action.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(colorFromString(action.color).opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(QuickActionButtonStyle())
        .accessibilityLabel(action.title)
        .accessibilityHint("Tap to \(action.voiceCommand.lowercased())")
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

struct QuickActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct RecentCommandsSection: View {
    @State private var recentCommands: [RecentCommand] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Commands")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 4)
            
            if recentCommands.isEmpty {
                EmptyRecentCommandsView()
            } else {
                VStack(spacing: 12) {
                    ForEach(recentCommands) { command in
                        RecentCommandRow(command: command)
                    }
                }
            }
        }
        .onAppear {
            loadRecentCommands()
        }
    }
    
    private func loadRecentCommands() {
        // Simulate loading recent commands
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            recentCommands = [
                RecentCommand(
                    id: "1",
                    text: "Schedule a meeting with the team tomorrow at 2 PM",
                    timestamp: Date().addingTimeInterval(-3600),
                    intent: "calendar",
                    result: "Meeting scheduled successfully"
                ),
                RecentCommand(
                    id: "2",
                    text: "Check my emails",
                    timestamp: Date().addingTimeInterval(-7200),
                    intent: "email",
                    result: "You have 12 unread emails"
                ),
                RecentCommand(
                    id: "3",
                    text: "Add a task to review the project proposal",
                    timestamp: Date().addingTimeInterval(-10800),
                    intent: "tasks",
                    result: "Task added to your list"
                )
            ]
        }
    }
}

struct RecentCommand: Identifiable {
    let id: String
    let text: String
    let timestamp: Date
    let intent: String
    let result: String
}

struct RecentCommandRow: View {
    let command: RecentCommand
    
    var body: some View {
        HStack(spacing: 12) {
            // Intent icon
            Image(systemName: iconForIntent(command.intent))
                .font(.title2)
                .foregroundColor(colorForIntent(command.intent))
                .frame(width: 24, height: 24)
            
            // Command details
            VStack(alignment: .leading, spacing: 4) {
                Text(command.text)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(formatTimestamp(command.timestamp))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Success indicator
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundColor(.green)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func iconForIntent(_ intent: String) -> String {
        switch intent {
        case "calendar": return "calendar"
        case "email": return "envelope"
        case "tasks": return "checkmark.circle"
        default: return "bubble.left"
        }
    }
    
    private func colorForIntent(_ intent: String) -> Color {
        switch intent {
        case "calendar": return .blue
        case "email": return .red
        case "tasks": return .green
        default: return .gray
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct EmptyRecentCommandsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No recent commands")
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
            
            Text("Your conversation history will appear here")
                .font(.body)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            QuickActionsRow()
            
            Spacer()
            
            RecentCommandsSection()
        }
        .padding()
    }
}