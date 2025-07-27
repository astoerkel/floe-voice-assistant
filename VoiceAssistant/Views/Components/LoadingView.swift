//
//  LoadingView.swift
//  VoiceAssistant
//
//  A beautiful loading view with circular progress indicator
//

import SwiftUI

struct LoadingView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isAnimating = false
    @State private var progress: CGFloat = 0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            Group {
                if themeManager.themeMode == .dark || 
                   (themeManager.themeMode == .system && UITraitCollection.current.userInterfaceStyle == .dark) {
                    Color.black
                } else {
                    Color(red: 0.98, green: 0.98, blue: 0.98)
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Circular Progress
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(
                            Color.gray.opacity(0.2),
                            lineWidth: 8
                        )
                        .frame(width: 100, height: 100)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(
                                lineWidth: 8,
                                lineCap: .round
                            )
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(Angle(degrees: -90))
                        .animation(.easeInOut(duration: 1.5), value: progress)
                    
                    // Rotating accent dots
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                            .offset(y: -50)
                            .rotationEffect(Angle(degrees: Double(index) * 120 + rotationAngle))
                            .opacity(isAnimating ? 1 : 0.3)
                            .animation(
                                Animation.easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.1),
                                value: isAnimating
                            )
                    }
                    
                    // App icon or logo
                    Image(systemName: "mic.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                
                // Loading text
                VStack(spacing: 8) {
                    Text("Floe")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text("Loading")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Animated dots
                        HStack(spacing: 2) {
                            ForEach(0..<3) { index in
                                Text(".")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .opacity(isAnimating ? 1 : 0.3)
                                    .animation(
                                        Animation.easeInOut(duration: 0.6)
                                            .repeatForever()
                                            .delay(Double(index) * 0.2),
                                        value: isAnimating
                                    )
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
            
            // Animate progress
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                progress = 0.8
            }
            
            // Rotate the accent dots
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// Compact loading indicator for inline use
struct CompactLoadingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isAnimating ? 1 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    LoadingView()
}