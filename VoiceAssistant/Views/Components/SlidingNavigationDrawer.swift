//
//  SlidingNavigationDrawer.swift
//  VoiceAssistant
//
//  Navigation drawer that pushes the main content to the side
//

import SwiftUI

struct SlidingNavigationDrawer<MainContent: View, DrawerContent: View>: View {
    @Binding var isOpen: Bool
    let mainContent: MainContent
    let drawerContent: DrawerContent
    @StateObject private var themeManager = ThemeManager.shared
    
    // Configuration
    private let drawerWidth: CGFloat = UIScreen.main.bounds.width * 0.8  // Changed to 80%
    private let animationDuration: Double = 0.3
    private let cornerRadius: CGFloat = 38  // iPhone corner radius
    
    init(isOpen: Binding<Bool>, @ViewBuilder mainContent: () -> MainContent, @ViewBuilder drawerContent: () -> DrawerContent) {
        self._isOpen = isOpen
        self.mainContent = mainContent()
        self.drawerContent = drawerContent()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Main content - slides to the left when drawer opens
                mainContent
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: isOpen ? -drawerWidth : 0)
                    .animation(.easeInOut(duration: animationDuration), value: isOpen)
                    .overlay(
                        // Dark overlay on main content when drawer is open
                        Group {
                            if isOpen {
                                // Use different opacity for light/dark mode
                                Color.black
                                    .opacity(themeManager.currentTheme == .dark || 
                                           (themeManager.currentTheme == nil && UITraitCollection.current.userInterfaceStyle == .dark) ? 0.6 : 0.3)
                                    .ignoresSafeArea()
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: animationDuration)) {
                                            isOpen = false
                                        }
                                    }
                                    .animation(.easeInOut(duration: animationDuration), value: isOpen)
                            }
                        }
                    )
                
                // Drawer content - slides in from the right
                HStack(spacing: 0) {
                    Spacer()
                    
                    drawerContent
                        .frame(width: drawerWidth)
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(backgroundColorForTheme())
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .shadow(color: Color.black.opacity(0.2), radius: 20, x: -10, y: 0)
                }
                .offset(x: isOpen ? 0 : geometry.size.width)
                .animation(.easeInOut(duration: animationDuration), value: isOpen)
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let threshold = drawerWidth * 0.3
                        
                        if isOpen {
                            // If drawer is open and user swipes right
                            if value.translation.width > threshold {
                                withAnimation(.easeInOut(duration: animationDuration)) {
                                    isOpen = false
                                }
                            }
                        } else {
                            // If drawer is closed and user swipes left (anywhere on screen)
                            if value.translation.width < -threshold {
                                withAnimation(.easeInOut(duration: animationDuration)) {
                                    isOpen = true
                                }
                            }
                        }
                    }
            )
        }
        .ignoresSafeArea()
    }
    
    private func backgroundColorForTheme() -> Color {
        if let colorScheme = themeManager.currentTheme {
            switch colorScheme {
            case .light:
                return Color(red: 0.98, green: 0.98, blue: 0.98)
            case .dark:
                return Color(white: 0.1)  // Match main screen dark gray
            @unknown default:
                return Color(white: 0.1)
            }
        } else {
            return Color(UIColor.systemBackground)
        }
    }
}

// Modifier for easier use
extension View {
    func slidingNavigationDrawer<DrawerContent: View>(
        isOpen: Binding<Bool>,
        @ViewBuilder drawerContent: @escaping () -> DrawerContent
    ) -> some View {
        SlidingNavigationDrawer(
            isOpen: isOpen,
            mainContent: { self },
            drawerContent: drawerContent
        )
    }
}