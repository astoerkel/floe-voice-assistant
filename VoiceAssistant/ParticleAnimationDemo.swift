import SwiftUI

// Demo view to showcase the particle animation in different states
struct ParticleAnimationDemo: View {
    @State private var isVoiceActive = false
    @State private var isAudioPlaying = false
    @State private var audioLevel: CGFloat = 0.0
    @State private var selectedTheme = ThemeManager.ThemeMode.system
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Particle animation
            ParticleBackgroundView(
                isVoiceActive: isVoiceActive,
                isAudioPlaying: isAudioPlaying,
                audioLevel: audioLevel
            )
            .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Controls
                VStack(spacing: 20) {
                    // Voice Active Toggle
                    Toggle("Voice Active", isOn: $isVoiceActive)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .foregroundColor(.white)
                    
                    // Audio Playing Toggle
                    Toggle("Audio Playing", isOn: $isAudioPlaying)
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                        .foregroundColor(.white)
                    
                    // Audio Level Slider
                    VStack(alignment: .leading) {
                        Text("Audio Level: \(String(format: "%.1f", audioLevel))")
                            .foregroundColor(.white)
                        
                        Slider(value: $audioLevel, in: 0...1)
                            .accentColor(.cyan)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // Theme Picker
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(ThemeManager.ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedTheme) { newValue in
                        ThemeManager.shared.themeMode = newValue
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.7))
                )
                .padding()
            }
        }
        .preferredColorScheme(selectedTheme == .system ? nil : 
                            selectedTheme == .light ? .light : .dark)
    }
}

#Preview {
    ParticleAnimationDemo()
}