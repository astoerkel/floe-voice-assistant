//
//  ResultBottomSheet.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI
import AVFoundation

struct ResultBottomSheet: View {
    let message: ConversationMessage
    @State private var detentHeight: PresentationDetent = .medium
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Audio playback state
    @State private var isPlayingAudio = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playbackProgress: Double = 0.0
    @State private var playbackTimer: Timer?
    
    // Interaction state
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Drag indicator with rubber band effect
                        dragIndicator
                        
                        // Main response content
                        responseContentView
                        
                        // Audio controls (if audio is available)
                        if message.audioBase64 != nil {
                            audioControlsView
                        }
                        
                        // Action buttons
                        actionButtonsView
                        
                        // Follow-up suggestions
                        followUpSuggestionsView
                        
                        // Response metadata
                        responseMetadataView
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationBarHidden(true)
            .background(backgroundView)
        }
        .presentationDetents([.medium, .large], selection: $detentHeight)
        .presentationDragIndicator(.hidden) // We have our own custom indicator
        .presentationBackgroundInteraction(.enabled)
        .presentationCornerRadius(28)
        .interactiveDismissDisabled(isDragging)
        .onAppear {
            setupHapticFeedback()
            HapticManager.shared.cardTapped()
        }
        .onDisappear {
            stopAudioPlayback()
        }
    }
    
    // MARK: - View Components
    
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 40, height: 6)
            .padding(.top, 8)
            .scaleEffect(isDragging ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isDragging)
    }
    
    private var backgroundView: some View {
        (colorScheme == .dark ? Color(.systemBackground) : Color(.secondarySystemBackground))
            .ignoresSafeArea()
    }
    
    private var responseContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Response header
            HStack {
                Image(systemName: iconForResponse)
                    .font(.title2)
                    .foregroundColor(colorForResponse)
                    .frame(width: 32, height: 32)
                    .background(colorForResponse.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Response")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if message.confidence != nil {
                    confidenceBadge
                }
            }
            
            // Response text with Dynamic Type support
            Text(message.text)
                .font(.body)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
            
            // Transcription indicator
            if message.isTranscribed {
                transcriptionIndicator
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI response: \(message.text)")
        .accessibilityHint("Double tap to select text, swipe up for more actions")
    }
    
    private var confidenceBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            
            Text("\(Int((message.confidence ?? 0.0) * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .clipShape(Capsule())
    }
    
    private var transcriptionIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.caption)
                .foregroundColor(.blue)
            
            Text("Transcribed from audio")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private var audioControlsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Audio Response")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let duration = getAudioDuration() {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Audio playback controls
            HStack(spacing: 16) {
                // Play/Pause button
                Button(action: toggleAudioPlayback) {
                    Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel(isPlayingAudio ? "Pause audio" : "Play audio")
                .scaleEffect(isPlayingAudio ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isPlayingAudio)
                
                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: playbackProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .tint(.blue)
                    
                    HStack {
                        Text(formatDuration(playbackProgress * (getAudioDuration() ?? 0)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let duration = getAudioDuration() {
                            Text(formatDuration(duration))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
    }
    
    private var actionButtonsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                // Copy to clipboard
                ActionButton(
                    icon: "doc.on.doc",
                    title: "Copy",
                    color: .blue,
                    action: copyToClipboard
                )
                .accessibilityLabel("Copy response to clipboard")
                
                // Share
                ActionButton(
                    icon: "square.and.arrow.up",
                    title: "Share",
                    color: .green,
                    action: shareResponse
                )
                .accessibilityLabel("Share response")
                
                // Replay audio (if available)
                if message.audioBase64 != nil {
                    ActionButton(
                        icon: "speaker.wave.2",
                        title: "Replay",
                        color: .orange,
                        action: replayAudio
                    )
                    .accessibilityLabel("Replay audio response")
                }
                
                // More actions
                ActionButton(
                    icon: "ellipsis.circle",
                    title: "More",
                    color: .purple,
                    action: showMoreActions
                )
                .accessibilityLabel("Show more actions")
            }
        }
    }
    
    private var followUpSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Follow-up Suggestions")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let suggestions = message.suggestions, !suggestions.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(Array(suggestions.prefix(4)), id: \.self) { suggestion in
                        SuggestionButton(suggestion: suggestion) {
                            handleFollowUpSuggestion(suggestion)
                        }
                    }
                }
            } else {
                // Default suggestions based on intent
                LazyVStack(spacing: 8) {
                    ForEach(defaultSuggestions, id: \.self) { suggestion in
                        SuggestionButton(suggestion: suggestion) {
                            handleFollowUpSuggestion(suggestion)
                        }
                    }
                }
            }
        }
    }
    
    private var responseMetadataView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response Details")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            VStack(spacing: 6) {
                if let agentUsed = message.agentUsed {
                    MetadataRow(label: "Agent", value: agentUsed.capitalized)
                }
                
                if let executionTime = message.executionTime {
                    MetadataRow(label: "Response Time", value: String(format: "%.2fs", executionTime))
                }
                
                if let intent = message.intent {
                    MetadataRow(label: "Intent", value: intent.capitalized)
                }
                
                MetadataRow(label: "Time", value: formattedTimestamp)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Computed Properties
    
    private var iconForResponse: String {
        switch message.intent?.lowercased() {
        case "calendar": return "calendar"
        case "email": return "envelope"
        case "task", "todo": return "checkmark.circle"
        case "weather": return "cloud.sun"
        case "time": return "clock"
        default: return "bubble.left.fill"
        }
    }
    
    private var colorForResponse: Color {
        switch message.intent?.lowercased() {
        case "calendar": return .blue
        case "email": return .red
        case "task", "todo": return .green
        case "weather": return .orange
        case "time": return .purple
        default: return .gray
        }
    }
    
    private var confidenceColor: Color {
        guard let confidence = message.confidence else { return .gray }
        if confidence > 0.8 { return .green }
        else if confidence > 0.6 { return .yellow }
        else { return .red }
    }
    
    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
    
    private var defaultSuggestions: [String] {
        switch message.intent?.lowercased() {
        case "calendar":
            return ["Add reminder", "Invite others", "Change time", "Get details"]
        case "email":
            return ["Reply", "Forward", "Mark important", "Archive"]
        case "task":
            return ["Set due date", "Add subtask", "Set priority", "Mark complete"]
        case "weather":
            return ["Tomorrow's forecast", "Weather alerts", "Other locations", "Radar"]
        default:
            return ["Ask follow-up", "Get more info", "Related topics", "Save response"]
        }
    }
    
    // MARK: - Audio Playback Methods
    
    private func toggleAudioPlayback() {
        if isPlayingAudio {
            pauseAudioPlayback()
        } else {
            playAudioResponse()
        }
    }
    
    private func playAudioResponse() {
        guard let audioBase64 = message.audioBase64,
              let audioData = Data(base64Encoded: audioBase64) else {
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            isPlayingAudio = true
            HapticManager.shared.commandSuccess()
            
            startPlaybackTimer()
        } catch {
            print("Failed to play audio: \(error)")
            HapticManager.shared.commandError()
        }
    }
    
    private func pauseAudioPlayback() {
        audioPlayer?.pause()
        isPlayingAudio = false
        stopPlaybackTimer()
        HapticManager.shared.buttonPressed()
    }
    
    private func stopAudioPlayback() {
        audioPlayer?.stop()
        isPlayingAudio = false
        playbackProgress = 0.0
        stopPlaybackTimer()
    }
    
    private func replayAudio() {
        stopAudioPlayback()
        playAudioResponse()
    }
    
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = audioPlayer else { return }
            
            if player.isPlaying {
                playbackProgress = player.currentTime / player.duration
            } else {
                // Playback finished
                isPlayingAudio = false
                playbackProgress = 0.0
                stopPlaybackTimer()
            }
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func getAudioDuration() -> TimeInterval? {
        guard let audioBase64 = message.audioBase64,
              let audioData = Data(base64Encoded: audioBase64) else {
            return nil
        }
        
        do {
            let player = try AVAudioPlayer(data: audioData)
            return player.duration
        } catch {
            return nil
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Action Methods
    
    private func copyToClipboard() {
        UIPasteboard.general.string = message.text
        HapticManager.shared.commandSuccess()
    }
    
    private func shareResponse() {
        let activityVC = UIActivityViewController(activityItems: [message.text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // iPad support
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityVC, animated: true)
        }
        
        HapticManager.shared.buttonPressed()
    }
    
    private func showMoreActions() {
        // TODO: Implement more actions menu
        HapticManager.shared.buttonPressed()
    }
    
    private func handleFollowUpSuggestion(_ suggestion: String) {
        dismiss()
        // TODO: Send suggestion as new voice command
        HapticManager.shared.quickActionTapped()
    }
    
    private func setupHapticFeedback() {
        hapticFeedback.prepare()
    }
}

// MARK: - Supporting Views

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct SuggestionButton: View {
    let suggestion: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(suggestion)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Follow-up suggestion: \(suggestion)")
    }
}

struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(minWidth: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ResultBottomSheet(
        message: ConversationMessage(
            text: "I've successfully scheduled your team meeting for tomorrow at 2:00 PM in Conference Room A. The meeting is set for 1 hour with John Doe, Jane Smith, and Bob Johnson invited.",
            isUser: false,
            audioBase64: nil,
            isTranscribed: false,
            intent: "calendar",
            confidence: 0.95,
            agentUsed: "calendar",
            executionTime: 1.2,
            actions: ["Edit", "Share", "Delete", "Details"],
            suggestions: ["Add reminder", "Invite others", "Change time", "Get details"]
        )
    )
}