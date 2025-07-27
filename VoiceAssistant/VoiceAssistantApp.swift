import SwiftUI

@main
struct VoiceAssistantApp: App {
    @StateObject private var apiClient = SimpleAPIClient.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isLoading = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoading {
                    LoadingView()
                        .transition(.opacity)
                } else {
                    SimpleContentView()
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(themeManager.currentTheme)
            .onAppear {
                // Simulate loading time for app initialization
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isLoading = false
                    }
                }
            }
        }
    }
}