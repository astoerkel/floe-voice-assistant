//
//  EnhancedVoiceInterface.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI

struct EnhancedVoiceInterface: View {
    @StateObject private var voiceViewModel = EnhancedVoiceViewModel()
    @ObservedObject private var apiClient = APIClient.shared
    @State private var showingFollowUps = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black.ignoresSafeArea()
                
                // Particle effect background
                ParticleBackgroundView(
                    isVoiceActive: voiceViewModel.isRecording,
                    isAudioPlaying: voiceViewModel.isPlaying
                )
                
                VStack(spacing: 30) {
                    // Header
                    headerView
                    
                    Spacer()
                    
                    // Main voice interaction area
                    VStack(spacing: 40) {
                        // Status and waveform
                        VoiceStatusView(
                            status: voiceViewModel.currentStatus,
                            isRecording: voiceViewModel.isRecording,
                            audioLevels: voiceViewModel.audioLevels
                        )
                        
                        // Voice button
                        VoiceInteractionButton(
                            isRecording: voiceViewModel.isRecording,
                            onToggleRecording: voiceViewModel.toggleRecording
                        )
                        
                        // Follow-up suggestions
                        if !voiceViewModel.suggestedFollowUps.isEmpty {
                            FollowUpSuggestionsView(
                                suggestions: voiceViewModel.suggestedFollowUps,
                                onSelect: { suggestion in
                                    voiceViewModel.processTextCommand(suggestion)
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Quick action buttons
                        QuickActionButtonsView(
                            onActionSelected: { action in
                                voiceViewModel.processTextCommand(action.voiceCommand)
                            }
                        )
                    }
                    
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            voiceViewModel.setup()
        }
    }
    
    private var headerView: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text("Voice Assistant")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
}

struct VoiceStatusView: View {
    let status: VoiceStatus
    let isRecording: Bool
    let audioLevels: [Float]
    
    var body: some View {
        VStack(spacing: 20) {
            // Status text
            Text(statusText)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .animation(.easeInOut(duration: 0.3), value: status)
            
            // Audio visualization
            if isRecording {
                WaveformVisualization(levels: audioLevels)
                    .frame(height: 60)
                    .padding(.horizontal, 40)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 120)
    }
    
    private var statusText: String {
        switch status {
        case .idle:
            return "Ready to assist you"
        case .listening:
            return "I'm listening..."
        case .processing:
            return "Processing your request..."
        case .responding:
            return "Here's what I found"
        case .error:
            return "Something went wrong"
        }
    }
}

struct VoiceInteractionButton: View {
    let isRecording: Bool
    let onToggleRecording: () -> Void
    
    var body: some View {
        Button(action: onToggleRecording) {
            ZStack {
                // Outer glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (isRecording ? Color.red : Color.blue).opacity(0.3),
                                (isRecording ? Color.red : Color.blue).opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRecording)
                
                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                isRecording ? Color.red : Color.blue,
                                isRecording ? Color.red.opacity(0.8) : Color.blue.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                    )
                    .scaleEffect(isRecording ? 0.95 : 1.0)
                    .shadow(
                        color: (isRecording ? Color.red : Color.blue).opacity(0.5),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
        .accessibilityHint("Tap to \(isRecording ? "stop" : "start") voice recording")
    }
}

struct FollowUpSuggestionsView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try saying:")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: {
                            onSelect(suggestion)
                        }) {
                            Text(suggestion)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct QuickActionButtonsView: View {
    let onActionSelected: (QuickAction) -> Void
    
    private let quickActions: [QuickAction] = [
        QuickAction(
            id: "calendar",
            title: "Schedule",
            icon: "calendar.badge.plus",
            voiceCommand: "What's on my calendar today?",
            color: "blue"
        ),
        QuickAction(
            id: "email",
            title: "Email",
            icon: "envelope",
            voiceCommand: "Check my unread emails",
            color: "red"
        ),
        QuickAction(
            id: "tasks",
            title: "Tasks",
            icon: "checkmark.circle",
            voiceCommand: "Show me my tasks for today",
            color: "green"
        )
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 20) {
                ForEach(quickActions) { action in
                    Button(action: {
                        onActionSelected(action)
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: action.icon)
                                .font(.system(size: 24))
                                .foregroundColor(colorFromString(action.color))
                                .frame(width: 48, height: 48)
                                .background(
                                    Circle()
                                        .fill(colorFromString(action.color).opacity(0.2))
                                )
                            
                            Text(action.title)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
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
        default: return .blue
        }
    }
}

struct WaveformVisualization: View {
    let levels: [Float]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: CGFloat(levels[index]) * 50)
                    .animation(.easeInOut(duration: 0.1), value: levels[index])
            }
        }
    }
}

// MARK: - Voice Status

enum VoiceStatus {
    case idle
    case listening
    case processing
    case responding
    case error
}

// MARK: - Enhanced Voice ViewModel

@MainActor
class EnhancedVoiceViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var currentStatus: VoiceStatus = .idle
    @Published var suggestedFollowUps: [String] = []
    @Published var audioLevels: [Float] = Array(repeating: 0.1, count: 30)
    @Published var conversationContext: ConversationContext?
    
    private var lastCommand: ProcessedCommand?
    private var audioLevelTimer: Timer?
    
    func setup() {
        startAudioLevelMonitoring()
    }
    
    func toggleRecording() {
        isRecording.toggle()
        
        if isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    func processTextCommand(_ text: String) {
        currentStatus = .processing
        
        // Simulate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.handleCommandResult(text)
        }
    }
    
    private func startRecording() {
        currentStatus = .listening
        generateSuggestedFollowUps()
    }
    
    private func stopRecording() {
        currentStatus = .processing
        
        // Simulate processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.handleCommandResult("Sample voice command")
        }
    }
    
    private func handleCommandResult(_ command: String) {
        currentStatus = .responding
        
        // Create processed command
        let processedCommand = ProcessedCommand(
            text: command,
            intent: detectIntent(command),
            confidence: 0.85,
            timestamp: Date()
        )
        
        lastCommand = processedCommand
        generateSuggestedFollowUps()
        
        // Reset to idle after response
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.currentStatus = .idle
        }
    }
    
    private func generateSuggestedFollowUps() {
        guard let lastCommand = lastCommand else {
            suggestedFollowUps = []
            return
        }
        
        switch lastCommand.intent {
        case .calendar:
            suggestedFollowUps = [
                "Add attendees to this meeting",
                "Set a reminder for this event",
                "Change the meeting location",
                "Move this meeting to tomorrow"
            ]
        case .email:
            suggestedFollowUps = [
                "Reply to the latest email",
                "Forward this to my team",
                "Schedule a follow-up meeting",
                "Mark all as read"
            ]
        case .tasks:
            suggestedFollowUps = [
                "Set a due date for this task",
                "Add more details to this task",
                "Create a subtask",
                "Mark task as high priority"
            ]
        default:
            suggestedFollowUps = [
                "Tell me more about this",
                "What else can you help with?",
                "Show me my schedule",
                "Check my notifications"
            ]
        }
    }
    
    private func detectIntent(_ text: String) -> CommandIntent {
        let lowercased = text.lowercased()
        
        if lowercased.contains("calendar") || lowercased.contains("meeting") || lowercased.contains("schedule") {
            return .calendar
        } else if lowercased.contains("email") || lowercased.contains("mail") {
            return .email
        } else if lowercased.contains("task") || lowercased.contains("todo") {
            return .tasks
        } else {
            return .general
        }
    }
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.updateAudioLevels()
            }
        }
    }
    
    private func updateAudioLevels() {
        if isRecording {
            audioLevels = (0..<30).map { _ in Float.random(in: 0.1...0.9) }
        } else {
            audioLevels = Array(repeating: 0.1, count: 30)
        }
    }
    
    deinit {
        audioLevelTimer?.invalidate()
    }
}

// MARK: - Supporting Models

// QuickAction is now defined in SharedModels.swift

// CalendarEvent is now defined in SharedModels.swift

struct ConversationContext {
    let lastCommand: ProcessedCommand?
    let activeCalendarEvent: CalendarEvent?
    let currentTask: QuickTaskItem?
    let sessionId: String
}

struct ProcessedCommand {
    let text: String
    let intent: CommandIntent
    let confidence: Double
    let timestamp: Date
}

enum CommandIntent {
    case calendar
    case email
    case tasks
    case general
}

struct QuickTaskItem {
    let id: String
    let title: String
    let isCompleted: Bool
    let dueDate: Date?
}

#Preview {
    EnhancedVoiceInterface()
}