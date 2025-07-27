//
//  ConversationBubbles.swift
//  VoiceAssistant
//
//  Created by Claude on 24.07.25.
//

import SwiftUI
import AVFoundation

// MARK: - Conversation Bubble for Chat Messages
struct ConversationBubbleChat: View {
    let message: ConversationMessage
    let onTap: (() -> Void)?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    
    init(message: ConversationMessage, onTap: (() -> Void)? = nil) {
        self.message = message
        self.onTap = onTap
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if !message.text.isEmpty {
                    VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                        Group {
                            if !message.isUser && onTap != nil {
                                // Make AI responses tappable
                                Button(action: { onTap?() }) {
                                    Text(message.text)
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(Color.white.opacity(0.15))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("AI response: \(message.text). Double tap to view details")
                            } else {
                                // User messages (non-tappable)
                                Text(message.text)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(message.isUser ? 
                                                 Color(red: 0.8, green: 0.7, blue: 1.0) : // lilac for user
                                                 Color.white.opacity(0.15)) // semi-transparent white for AI
                                    )
                            }
                        }
                        
                        // Show metadata for AI responses
                        if !message.isUser {
                            HStack(spacing: 8) {
                                // Offline indicator
                                if message.confidence != nil && message.confidence! < 1.0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "wifi.slash")
                                            .font(.caption2)
                                        Text("Processed offline")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.orange.opacity(0.6))
                                }
                                
                                // Transcription indicator
                                if message.isTranscribed {
                                    HStack(spacing: 4) {
                                        Image(systemName: "waveform.badge.magnifyingglass")
                                            .font(.caption2)
                                        Text("Transcribed")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.white.opacity(0.5))
                                }
                                
                                Spacer()
                                
                                // Replay button if audio available
                                if message.audioBase64 != nil {
                                    Button(action: { replayAudio() }) {
                                        Image(systemName: isPlaying ? "stop.circle" : "play.circle")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .accessibilityLabel("Replay audio")
                                    .accessibilityHint("Tap to replay the original audio")
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    .accessibilityLabel(message.isUser ? "Your message" : (message.isTranscribed ? "AI response (transcribed from audio)" : "AI response"))
                    .accessibilityValue(message.text)
                } else if !message.isUser && message.audioBase64 != nil {
                    // Show clickable audio indicator for AI responses without text
                    Button(action: {
                        replayAudio()
                    }) {
                        HStack {
                            Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.title3)
                            Text("Audio response")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            if isPlaying {
                                Image(systemName: "waveform")
                                    .foregroundColor(.white.opacity(0.5))
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Timestamp
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 8)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal)
        .transition(.scale.combined(with: .opacity))
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func replayAudio() {
        guard let audioBase64 = message.audioBase64,
              let audioData = Data(base64Encoded: audioBase64) else {
            print("❌ No audio data available for replay")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            // Note: Delegate not set as it would be immediately deallocated
            // Using completion detection through isPlaying state
            
            if isPlaying {
                audioPlayer?.stop()
                isPlaying = false
            } else {
                audioPlayer?.play()
                isPlaying = true
                HapticManager.shared.buttonPressed()
            }
        } catch {
            print("❌ Failed to play audio: \(error)")
        }
    }
}

// MARK: - Live Transcription Bubble
struct LiveTranscriptionBubbleChat: View {
    let text: String
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(text)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.8, green: 0.7, blue: 1.0).opacity(0.7)) // lilac with transparency
                    )
                
                HStack(spacing: 4) {
                    Image(systemName: "mic.fill")
                        .font(.caption2)
                    Text("Transcribing...")
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal)
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Empty State View
struct ConversationEmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Start a conversation")
                .font(.title3)
                .foregroundColor(.white.opacity(0.6))
            
            Text("Hold the button and speak")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 60)
    }
}

