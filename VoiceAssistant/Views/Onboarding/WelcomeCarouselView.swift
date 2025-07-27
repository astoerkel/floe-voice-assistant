//
//  WelcomeCarouselView.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI

struct WelcomeCarouselView: View {
    let onContinue: () -> Void
    @State private var currentPage = 0
    
    private let carouselItems: [CarouselItem] = [
        CarouselItem(
            icon: "waveform.circle.fill",
            title: "Voice-first productivity",
            description: "Interact naturally with your AI assistant using voice commands. Get things done faster with conversational AI.",
            gradient: [Color.blue, Color.purple]
        ),
        CarouselItem(
            icon: "applewatch",
            title: "Apple Watch seamless sync",
            description: "Start conversations on your iPhone and continue on your Apple Watch. Your assistant is always with you.",
            gradient: [Color.green, Color.blue]
        ),
        CarouselItem(
            icon: "lock.shield.fill",
            title: "Privacy-first assistant",
            description: "Your conversations are processed securely with end-to-end encryption. Your data stays private.",
            gradient: [Color.purple, Color.pink]
        )
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    onContinue()
                }
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .padding(.trailing, 20)
            }
            .padding(.top, 60)
            
            // Main content
            VStack(spacing: 30) {
                // Logo
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Floe")
                    .font(.custom("Corinthia", size: 64))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                // Carousel
                TabView(selection: $currentPage) {
                    ForEach(0..<carouselItems.count, id: \.self) { index in
                        CarouselItemView(item: carouselItems[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 280)
                
                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<carouselItems.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 20)
            }
            
            Spacer()
            
            // Get Started button
            Button(action: onContinue) {
                HStack {
                    Text("Get Started")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Image(systemName: "arrow.right")
                        .font(.title2)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(30)
                .shadow(color: Color.blue.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .padding(.bottom, 50)
        }
        .onAppear {
            // Auto-advance pages
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentPage = (currentPage + 1) % carouselItems.count
                }
            }
        }
    }
}

struct CarouselItem {
    let icon: String
    let title: String
    let description: String
    let gradient: [Color]
}

struct CarouselItemView: View {
    let item: CarouselItem
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: item.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .opacity(0.2)
                
                Image(systemName: item.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            
            // Title
            Text(item.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Description
            Text(item.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 20)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ParticleBackgroundView(isVoiceActive: false, isAudioPlaying: false)
        WelcomeCarouselView(onContinue: {})
    }
}