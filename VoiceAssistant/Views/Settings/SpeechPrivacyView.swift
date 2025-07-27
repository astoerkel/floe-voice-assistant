//
//  SpeechPrivacyView.swift
//  VoiceAssistant
//
//  Created by Claude Code on 2025-07-24.
//  Privacy settings for speech recognition
//

import SwiftUI

struct SpeechPrivacyView: View {
    let speechRecognizer: SpeechRecognizer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Privacy & Data") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Speech Recognition Privacy")
                            .font(.headline)
                        
                        Text("Your speech data is processed with privacy in mind. We use on-device processing whenever possible.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("• On-device processing keeps your data private")
                        Text("• Speech patterns are encrypted locally")
                        Text("• No audio is sent to servers without permission")
                        Text("• You can clear learned patterns anytime")
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Data Management") {
                    Button("Clear Speech Patterns") {
                        // Clear speech patterns
                    }
                    .foregroundColor(.red)
                    
                    Button("Export Privacy Report") {
                        // Export privacy report
                    }
                }
            }
            .navigationTitle("Speech Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SpeechPrivacyView(speechRecognizer: SpeechRecognizer())
}