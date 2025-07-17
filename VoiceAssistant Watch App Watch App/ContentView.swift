//
//  ContentView.swift
//  VoiceAssistantWatch Watch App
//
//  Created by Amit Störkel on 16.07.25.
//
import SwiftUI

struct ContentView: View {
    @State private var isConnected = false
    @State private var statusText = "Open iPhone app first"
    
    var body: some View {
        VStack(spacing: 20) {
            // Connection status
            HStack {
                Circle()
                    .fill(isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(isConnected ? "Connected" : "No iPhone")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Main microphone button
            Button(action: {
                // TODO: Implement voice recording
            }) {
                ZStack {
                    Circle()
                        .fill(.blue)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Status text
            Text(statusText)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
