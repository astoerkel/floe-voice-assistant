//
//  PermissionsFlowView.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI
import AVFoundation
import Speech

struct PermissionsFlowView: View {
    let onComplete: () -> Void
    @State private var microphonePermission: PermissionStatus = .unknown
    @State private var speechPermission: PermissionStatus = .unknown
    @State private var isCheckingPermissions = false
    
    var body: some View {
        VStack(spacing: 40) {
            // Back button
            HStack {
                Button("Back") {
                    // Handle back navigation
                }
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .padding(.leading, 20)
                
                Spacer()
            }
            .padding(.top, 60)
            
            // Header
            VStack(spacing: 20) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Voice Permissions")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("We need access to your microphone and speech recognition to provide the best voice assistant experience.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Permission cards
            VStack(spacing: 20) {
                PermissionCard(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required to record your voice commands",
                    status: microphonePermission,
                    action: requestMicrophonePermission
                )
                
                PermissionCard(
                    icon: "waveform.badge.mic",
                    title: "Speech Recognition",
                    description: "Converts your voice to text for processing",
                    status: speechPermission,
                    action: requestSpeechPermission
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Continue button
            Button(action: {
                if allPermissionsGranted {
                    onComplete()
                } else {
                    requestAllPermissions()
                }
            }) {
                HStack {
                    if isCheckingPermissions {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(allPermissionsGranted ? "Continue" : "Grant Permissions")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if allPermissionsGranted {
                        Image(systemName: "arrow.right")
                            .font(.title2)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: allPermissionsGranted ? [Color.green, Color.blue] : [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(30)
                .shadow(color: (allPermissionsGranted ? Color.green : Color.blue).opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .disabled(isCheckingPermissions)
            .padding(.bottom, 50)
        }
        .onAppear {
            checkCurrentPermissions()
        }
    }
    
    private var allPermissionsGranted: Bool {
        microphonePermission == .granted && speechPermission == .granted
    }
    
    private func checkCurrentPermissions() {
        // Check microphone permission
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        microphonePermission = PermissionStatus(from: micStatus)
        
        // Check speech recognition permission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        speechPermission = PermissionStatus(from: speechStatus)
    }
    
    private func requestMicrophonePermission() {
        isCheckingPermissions = true
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.microphonePermission = granted ? .granted : .denied
                self.isCheckingPermissions = false
            }
        }
    }
    
    private func requestSpeechPermission() {
        isCheckingPermissions = true
        
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.speechPermission = PermissionStatus(from: status)
                self.isCheckingPermissions = false
            }
        }
    }
    
    private func requestAllPermissions() {
        guard !isCheckingPermissions else { return }
        
        isCheckingPermissions = true
        
        let group = DispatchGroup()
        
        // Request microphone permission
        if microphonePermission != .granted {
            group.enter()
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.microphonePermission = granted ? .granted : .denied
                    group.leave()
                }
            }
        }
        
        // Request speech recognition permission
        if speechPermission != .granted {
            group.enter()
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.speechPermission = PermissionStatus(from: status)
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            self.isCheckingPermissions = false
        }
    }
}

enum PermissionStatus {
    case unknown
    case granted
    case denied
    case restricted
    
    init(from micPermission: AVAudioSession.RecordPermission) {
        switch micPermission {
        case .granted:
            self = .granted
        case .denied:
            self = .denied
        case .undetermined:
            self = .unknown
        @unknown default:
            self = .unknown
        }
    }
    
    init(from speechPermission: SFSpeechRecognizerAuthorizationStatus) {
        switch speechPermission {
        case .authorized:
            self = .granted
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .notDetermined:
            self = .unknown
        @unknown default:
            self = .unknown
        }
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Status/Action
            Button(action: action) {
                statusView
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .unknown:
            Text("Allow")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(20)
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
        case .denied, .restricted:
            VStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.body)
                    .foregroundColor(.red)
                Text("Denied")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ParticleBackgroundView(isVoiceActive: false, isAudioPlaying: false)
        PermissionsFlowView(onComplete: {})
    }
}