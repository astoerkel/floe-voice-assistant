//
//  NavigationDrawer.swift
//  VoiceAssistant
//
//  Navigation drawer component that slides in from the right
//

import SwiftUI

struct NavigationDrawer<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    
    // Configuration
    private let drawerWidth: CGFloat = UIScreen.main.bounds.width * 0.85
    private let animationDuration: Double = 0.3
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Semi-transparent overlay
                if isPresented {
                    Color.black
                        .opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: animationDuration)) {
                                isPresented = false
                            }
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: animationDuration), value: isPresented)
                }
                
                // Drawer content
                HStack(spacing: 0) {
                    // Spacer to push drawer to the right
                    Spacer()
                    
                    // Drawer
                    VStack(spacing: 0) {
                        content
                    }
                    .frame(width: drawerWidth)
                    .frame(maxHeight: .infinity)
                    .background(
                        Group {
                            if let colorScheme = ThemeManager.shared.currentTheme {
                                switch colorScheme {
                                case .light:
                                    Color(red: 0.98, green: 0.98, blue: 0.98)
                                case .dark:
                                    Color.black
                                @unknown default:
                                    Color.black
                                }
                            } else {
                                Color(UIColor.systemBackground)
                            }
                        }
                        .ignoresSafeArea()
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: -5, y: 0)
                    .offset(x: isPresented ? 0 : drawerWidth)
                    .animation(.easeInOut(duration: animationDuration), value: isPresented)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                // If dragged more than halfway to the right, dismiss
                                if value.translation.width > drawerWidth / 2 {
                                    withAnimation(.easeInOut(duration: animationDuration)) {
                                        isPresented = false
                                    }
                                }
                            }
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

// Modifier for easier use
extension View {
    func navigationDrawer<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self
            NavigationDrawer(isPresented: isPresented, content: content)
        }
    }
}