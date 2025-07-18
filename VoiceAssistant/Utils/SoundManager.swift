//
//  SoundManager.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import AVFoundation
import UIKit

class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var audioSession = AVAudioSession.sharedInstance()
    
    @Published var isSoundEnabled = true
    @Published var soundVolume: Float = 0.5
    
    init() {
        setupAudioSession()
        loadSounds()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func loadSounds() {
        // Load system sounds or custom sounds
        loadSystemSounds()
    }
    
    private func loadSystemSounds() {
        // Using system sounds for now - in a real app, you'd load custom audio files
        // System sounds are played through AudioServicesPlaySystemSound
    }
    
    // MARK: - Voice Interaction Sounds
    
    func playRecordingStart() {
        guard isSoundEnabled else { return }
        
        // Play subtle recording start sound
        playSystemSound(.recordingStart)
    }
    
    func playRecordingStop() {
        guard isSoundEnabled else { return }
        
        // Play recording stop sound
        playSystemSound(.recordingStop)
    }
    
    func playVoiceListening() {
        guard isSoundEnabled else { return }
        
        // Play gentle listening sound
        playSystemSound(.voiceListening)
    }
    
    func playVoiceProcessing() {
        guard isSoundEnabled else { return }
        
        // Play processing sound
        playSystemSound(.processing)
    }
    
    // MARK: - Command Result Sounds
    
    func playCommandSuccess() {
        guard isSoundEnabled else { return }
        
        // Play success sound
        playSystemSound(.success)
    }
    
    func playCommandError() {
        guard isSoundEnabled else { return }
        
        // Play error sound
        playSystemSound(.error)
    }
    
    func playCommandWarning() {
        guard isSoundEnabled else { return }
        
        // Play warning sound
        playSystemSound(.warning)
    }
    
    // MARK: - Action-Specific Sounds
    
    func playCalendarEventCreated() {
        guard isSoundEnabled else { return }
        
        // Play calendar event created sound
        playSystemSound(.calendarEvent)
    }
    
    func playEmailSent() {
        guard isSoundEnabled else { return }
        
        // Play email sent sound
        playSystemSound(.emailSent)
    }
    
    func playTaskCompleted() {
        guard isSoundEnabled else { return }
        
        // Play task completed sound
        playSystemSound(.taskCompleted)
    }
    
    func playTaskCreated() {
        guard isSoundEnabled else { return }
        
        // Play task created sound
        playSystemSound(.taskCreated)
    }
    
    func playReminderSet() {
        guard isSoundEnabled else { return }
        
        // Play reminder set sound
        playSystemSound(.reminderSet)
    }
    
    // MARK: - UI Interaction Sounds
    
    func playButtonTap() {
        guard isSoundEnabled else { return }
        
        // Play button tap sound
        playSystemSound(.buttonTap)
    }
    
    func playButtonLongPress() {
        guard isSoundEnabled else { return }
        
        // Play button long press sound
        playSystemSound(.buttonLongPress)
    }
    
    func playMenuOpen() {
        guard isSoundEnabled else { return }
        
        // Play menu open sound
        playSystemSound(.menuOpen)
    }
    
    func playPageSwipe() {
        guard isSoundEnabled else { return }
        
        // Play page swipe sound
        playSystemSound(.pageSwipe)
    }
    
    func playCardTap() {
        guard isSoundEnabled else { return }
        
        // Play card tap sound
        playSystemSound(.cardTap)
    }
    
    func playQuickActionTap() {
        guard isSoundEnabled else { return }
        
        // Play quick action tap sound
        playSystemSound(.quickActionTap)
    }
    
    // MARK: - Connection Status Sounds
    
    func playWatchConnected() {
        guard isSoundEnabled else { return }
        
        // Play watch connected sound
        playSystemSound(.watchConnected)
    }
    
    func playWatchDisconnected() {
        guard isSoundEnabled else { return }
        
        // Play watch disconnected sound
        playSystemSound(.watchDisconnected)
    }
    
    func playNetworkError() {
        guard isSoundEnabled else { return }
        
        // Play network error sound
        playSystemSound(.networkError)
    }
    
    // MARK: - Authentication Sounds
    
    func playAuthenticationSuccess() {
        guard isSoundEnabled else { return }
        
        // Play authentication success sound
        playSystemSound(.authSuccess)
    }
    
    func playAuthenticationFailed() {
        guard isSoundEnabled else { return }
        
        // Play authentication failed sound
        playSystemSound(.authFailed)
    }
    
    // MARK: - Onboarding Sounds
    
    func playOnboardingStepCompleted() {
        guard isSoundEnabled else { return }
        
        // Play onboarding step completed sound
        playSystemSound(.onboardingStep)
    }
    
    func playOnboardingCompleted() {
        guard isSoundEnabled else { return }
        
        // Play onboarding completed sound
        playSystemSound(.onboardingComplete)
    }
    
    // MARK: - Dashboard Sounds
    
    func playDashboardRefresh() {
        guard isSoundEnabled else { return }
        
        // Play dashboard refresh sound
        playSystemSound(.dashboardRefresh)
    }
    
    func playDataLoaded() {
        guard isSoundEnabled else { return }
        
        // Play data loaded sound
        playSystemSound(.dataLoaded)
    }
    
    // MARK: - Settings Sounds
    
    func playSettingToggle() {
        guard isSoundEnabled else { return }
        
        // Play setting toggle sound
        playSystemSound(.settingToggle)
    }
    
    func playSettingsSaved() {
        guard isSoundEnabled else { return }
        
        // Play settings saved sound
        playSystemSound(.settingsSaved)
    }
    
    // MARK: - Notification Sounds
    
    func playNotification() {
        guard isSoundEnabled else { return }
        
        // Play notification sound
        playSystemSound(.notification)
    }
    
    func playAlert() {
        guard isSoundEnabled else { return }
        
        // Play alert sound
        playSystemSound(.alert)
    }
    
    // MARK: - Private Methods
    
    private func playSystemSound(_ sound: SystemSound) {
        guard isSoundEnabled else { return }
        
        // Play system sound with volume control
        AudioServicesPlaySystemSound(sound.rawValue)
    }
    
    private func playCustomSound(_ soundName: String) {
        guard isSoundEnabled else { return }
        
        // Play custom sound file
        guard let player = audioPlayers[soundName] else {
            print("Sound not found: \(soundName)")
            return
        }
        
        player.volume = soundVolume
        player.play()
    }
    
    private func loadCustomSound(named soundName: String, withExtension ext: String) {
        guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: ext) else {
            print("Sound file not found: \(soundName).\(ext)")
            return
        }
        
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer.prepareToPlay()
            audioPlayers[soundName] = audioPlayer
        } catch {
            print("Failed to load sound \(soundName): \(error)")
        }
    }
    
    // MARK: - Settings Management
    
    func enableSound(_ enabled: Bool) {
        isSoundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "soundEnabled")
    }
    
    func setSoundVolume(_ volume: Float) {
        soundVolume = max(0.0, min(1.0, volume))
        UserDefaults.standard.set(soundVolume, forKey: "soundVolume")
        
        // Update all audio players
        for player in audioPlayers.values {
            player.volume = soundVolume
        }
    }
    
    func loadSettings() {
        isSoundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        soundVolume = UserDefaults.standard.float(forKey: "soundVolume")
        
        // Set default values if not set
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil {
            isSoundEnabled = true
        }
        
        if UserDefaults.standard.object(forKey: "soundVolume") == nil {
            soundVolume = 0.5
        }
    }
    
    // MARK: - Context-Aware Sound Management
    
    func playContextualSound(for commandType: VoiceCommandType) {
        switch commandType {
        case .calendar:
            playCalendarEventCreated()
        case .email:
            playEmailSent()
        case .task:
            playTaskCreated()
        case .weather:
            playDataLoaded()
        case .general:
            playCommandSuccess()
        }
    }
    
    func playAdaptiveSound(for appState: VoiceAssistantStatus) {
        switch appState {
        case .idle:
            break // No sound for idle state
        case .recording:
            playRecordingStart()
        case .transcribing:
            playVoiceListening()
        case .processing:
            playVoiceProcessing()
        case .playing:
            playCommandSuccess()
        case .error:
            playCommandError()
        }
    }
}

// MARK: - System Sound Definitions

enum SystemSound: UInt32 {
    // Voice interaction sounds
    case recordingStart = 1103  // Camera shutter
    case recordingStop = 1104   // Camera shutter
    case voiceListening = 1105  // Gentle beep
    case processing = 1106      // Processing sound
    
    // Command result sounds
    case success = 1107         // Success sound
    case error = 1108           // Error sound
    case warning = 1109         // Warning sound
    
    // Action-specific sounds
    case calendarEvent = 1110   // Calendar event sound
    case emailSent = 1111       // Email sent sound
    case taskCompleted = 1112   // Task completed sound
    case taskCreated = 1113     // Task created sound
    case reminderSet = 1114     // Reminder set sound
    
    // UI interaction sounds
    case buttonTap = 1115       // Button tap sound
    case buttonLongPress = 1116 // Button long press sound
    case menuOpen = 1117        // Menu open sound
    case pageSwipe = 1118       // Page swipe sound
    case cardTap = 1119         // Card tap sound
    case quickActionTap = 1120  // Quick action tap sound
    
    // Connection status sounds
    case watchConnected = 1121  // Watch connected sound
    case watchDisconnected = 1122 // Watch disconnected sound
    case networkError = 1123    // Network error sound
    
    // Authentication sounds
    case authSuccess = 1124     // Authentication success sound
    case authFailed = 1125      // Authentication failed sound
    
    // Onboarding sounds
    case onboardingStep = 1126  // Onboarding step sound
    case onboardingComplete = 1127 // Onboarding complete sound
    
    // Dashboard sounds
    case dashboardRefresh = 1128 // Dashboard refresh sound
    case dataLoaded = 1129      // Data loaded sound
    
    // Settings sounds
    case settingToggle = 1130   // Setting toggle sound
    case settingsSaved = 1131   // Settings saved sound
    
    // Notification sounds
    case notification = 1132    // Notification sound
    case alert = 1133          // Alert sound
}

// MARK: - Audio Session Management

extension SoundManager {
    
    func configureAudioSession(for category: AVAudioSession.Category) {
        do {
            try audioSession.setCategory(category, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func pauseAllSounds() {
        for player in audioPlayers.values {
            if player.isPlaying {
                player.pause()
            }
        }
    }
    
    func resumeAllSounds() {
        for player in audioPlayers.values {
            if !player.isPlaying {
                player.play()
            }
        }
    }
    
    func stopAllSounds() {
        for player in audioPlayers.values {
            player.stop()
        }
    }
}

// MARK: - Accessibility Support

extension SoundManager {
    
    func playAccessibilitySound(for element: AccessibilityElement) {
        guard isSoundEnabled else { return }
        
        switch element {
        case .voiceButton:
            playButtonTap()
        case .menuButton:
            playMenuOpen()
        case .settingsButton:
            playButtonTap()
        case .quickAction:
            playQuickActionTap()
        case .dashboardCard:
            playCardTap()
        case .onboardingNext:
            playOnboardingStepCompleted()
        case .onboardingComplete:
            playOnboardingCompleted()
        }
    }
}

enum AccessibilityElement {
    case voiceButton
    case menuButton
    case settingsButton
    case quickAction
    case dashboardCard
    case onboardingNext
    case onboardingComplete
}