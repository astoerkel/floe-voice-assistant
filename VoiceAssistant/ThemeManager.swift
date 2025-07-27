import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("themeMode") private var storedThemeMode: String = "system"
    @Published var currentTheme: ColorScheme?
    
    var themeMode: ThemeMode {
        get {
            ThemeMode(rawValue: storedThemeMode) ?? .system
        }
        set {
            storedThemeMode = newValue.rawValue
            updateCurrentTheme(newValue)
        }
    }
    
    enum ThemeMode: String, CaseIterable {
        case system = "system"
        case light = "light"
        case dark = "dark"
        
        var displayName: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
        
        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }
    }
    
    private init() {
        updateCurrentTheme(themeMode)
    }
    
    private func updateCurrentTheme(_ mode: ThemeMode) {
        switch mode {
        case .system:
            currentTheme = nil
        case .light:
            currentTheme = .light
        case .dark:
            currentTheme = .dark
        }
    }
}

// Theme-aware colors
extension Color {
    // Removed duplicate color definitions that conflict with GeneratedAssetSymbols
    static let adaptiveText = Color("AdaptiveText")
    static let adaptiveSecondaryText = Color("AdaptiveSecondaryText")
}