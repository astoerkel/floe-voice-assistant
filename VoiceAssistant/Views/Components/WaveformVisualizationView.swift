//
//  WaveformVisualizationView.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI

struct WaveformVisualizationView: View {
    let audioLevels: [Float]
    let isRecording: Bool
    let isProcessing: Bool
    
    @State private var animationOffset: CGFloat = 0
    @State private var processingAnimation: Bool = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(audioLevels.enumerated()), id: \.offset) { index, level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: 4, height: max(4, CGFloat(level) * 100))
                    .scaleEffect(y: isRecording ? 1.0 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.1)
                            .delay(Double(index) * 0.01),
                        value: level
                    )
                    .opacity(isProcessing ? processingOpacity(for: index) : 1.0)
            }
        }
        .overlay(
            // Processing indicator
            Group {
                if isProcessing {
                    ProcessingWaveOverlay()
                }
            }
        )
        .onAppear {
            startAnimations()
        }
        .onChange(of: isProcessing) { oldValue, newValue in
            if newValue {
                startProcessingAnimation()
            } else {
                stopProcessingAnimation()
            }
        }
    }
    
    private var barColor: Color {
        if isProcessing { return .orange }
        if isRecording { return .green }
        return .blue.opacity(0.3)
    }
    
    private func processingOpacity(for index: Int) -> Double {
        guard isProcessing else { return 1.0 }
        
        let phase = (animationOffset + Double(index) * 0.2).truncatingRemainder(dividingBy: 2.0)
        return 0.3 + 0.7 * abs(sin(phase * .pi))
    }
    
    private func startAnimations() {
        withAnimation(.linear(duration: 0.1).repeatForever(autoreverses: false)) {
            animationOffset += 2.0
        }
    }
    
    private func startProcessingAnimation() {
        processingAnimation = true
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            animationOffset += 1.0
        }
    }
    
    private func stopProcessingAnimation() {
        processingAnimation = false
        withAnimation(.easeOut(duration: 0.3)) {
            animationOffset = 0
        }
    }
}

struct ProcessingWaveOverlay: View {
    @State private var waveOffset: CGFloat = 0
    @State private var waveAmplitude: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            WaveShape(
                offset: waveOffset,
                amplitude: waveAmplitude * 20,
                wavelength: geometry.size.width / 2
            )
            .stroke(
                LinearGradient(
                    colors: [
                        .orange.opacity(0.8),
                        .orange.opacity(0.4),
                        .orange.opacity(0.1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: waveAmplitude)
        }
        .onAppear {
            startWaveAnimation()
        }
    }
    
    private func startWaveAnimation() {
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            waveOffset += 2 * .pi
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            waveAmplitude = 0.5
        }
    }
}

struct WaveShape: Shape {
    let offset: CGFloat
    let amplitude: CGFloat
    let wavelength: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 1) {
            let y = midHeight + amplitude * sin((x / wavelength) * 2 * .pi + offset)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

// MARK: - Enhanced Waveform with Multiple Styles

struct AnimatedWaveformView: View {
    let audioLevels: [Float]
    let isRecording: Bool
    let isProcessing: Bool
    let style: WaveformStyle
    
    @State private var animationTimer: Timer?
    @State private var currentFrame: Int = 0
    
    var body: some View {
        Group {
            switch style {
            case .bars:
                WaveformBarsView(
                    audioLevels: audioLevels,
                    isRecording: isRecording,
                    isProcessing: isProcessing
                )
            case .circular:
                WaveformCircularView(
                    audioLevels: audioLevels,
                    isRecording: isRecording,
                    isProcessing: isProcessing
                )
            case .line:
                WaveformLineView(
                    audioLevels: audioLevels,
                    isRecording: isRecording,
                    isProcessing: isProcessing
                )
            case .particles:
                WaveformParticlesView(
                    audioLevels: audioLevels,
                    isRecording: isRecording,
                    isProcessing: isProcessing
                )
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            currentFrame = (currentFrame + 1) % 60
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

struct WaveformBarsView: View {
    let audioLevels: [Float]
    let isRecording: Bool
    let isProcessing: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(audioLevels.enumerated()), id: \.offset) { index, level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: max(2, CGFloat(level) * 60))
                    .scaleEffect(y: isRecording ? 1.0 : 0.2)
                    .animation(
                        .easeInOut(duration: 0.1)
                            .delay(Double(index) * 0.005),
                        value: level
                    )
            }
        }
    }
    
    private var gradientColors: [Color] {
        if isProcessing {
            return [.orange, .red]
        } else if isRecording {
            return [.green, .blue]
        } else {
            return [.blue.opacity(0.3), .purple.opacity(0.3)]
        }
    }
}

struct WaveformCircularView: View {
    let audioLevels: [Float]
    let isRecording: Bool
    let isProcessing: Bool
    
    var body: some View {
        ZStack {
            ForEach(Array(audioLevels.enumerated()), id: \.offset) { index, level in
                let angle = Double(index) * (360.0 / Double(audioLevels.count))
                let radius = 30.0 + Double(level) * 20.0
                
                Circle()
                    .fill(dotColor)
                    .frame(width: 4, height: 4)
                    .offset(
                        x: cos(angle * .pi / 180) * radius,
                        y: sin(angle * .pi / 180) * radius
                    )
                    .scaleEffect(isRecording ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.1)
                            .delay(Double(index) * 0.01),
                        value: level
                    )
            }
        }
    }
    
    private var dotColor: Color {
        if isProcessing { return .orange }
        if isRecording { return .green }
        return .blue.opacity(0.6)
    }
}

struct WaveformLineView: View {
    let audioLevels: [Float]
    let isRecording: Bool
    let isProcessing: Bool
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let stepWidth = width / CGFloat(audioLevels.count - 1)
                
                for (index, level) in audioLevels.enumerated() {
                    let x = CGFloat(index) * stepWidth
                    let y = height / 2 + (CGFloat(level) - 0.5) * height * 0.8
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: lineColors,
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            .scaleEffect(y: isRecording ? 1.0 : 0.3)
            .animation(.easeInOut(duration: 0.2), value: isRecording)
        }
    }
    
    private var lineColors: [Color] {
        if isProcessing {
            return [.orange, .red, .orange]
        } else if isRecording {
            return [.green, .blue, .green]
        } else {
            return [.blue.opacity(0.3), .purple.opacity(0.3), .blue.opacity(0.3)]
        }
    }
}

struct WaveformParticlesView: View {
    let audioLevels: [Float]
    let isRecording: Bool
    let isProcessing: Bool
    
    @State private var particles: [WaveformParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particleColor)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                        .animation(.easeOut(duration: 0.5), value: particle.opacity)
                }
            }
            .onAppear {
                generateParticles(in: geometry.size)
            }
            .onChange(of: audioLevels) { oldValue, newValue in
                updateParticles()
            }
        }
    }
    
    private var particleColor: Color {
        if isProcessing { return .orange }
        if isRecording { return .green }
        return .blue.opacity(0.6)
    }
    
    private func generateParticles(in size: CGSize) {
        particles = (0..<30).map { index in
            WaveformParticle(
                id: index,
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 2...6),
                opacity: 0.5,
                baseY: CGFloat.random(in: 0...size.height)
            )
        }
    }
    
    private func updateParticles() {
        guard !audioLevels.isEmpty else { return }
        
        for i in 0..<particles.count {
            let levelIndex = i % audioLevels.count
            let level = audioLevels[levelIndex]
            
            particles[i].opacity = Double(level) * 0.8 + 0.2
            particles[i].size = CGFloat(level) * 8 + 2
            
            if isRecording {
                particles[i].position.y = particles[i].baseY + CGFloat(level) * 20 - 10
            }
        }
    }
}

struct WaveformParticle: Identifiable {
    let id: Int
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
    let baseY: CGFloat
}

enum WaveformStyle {
    case bars
    case circular
    case line
    case particles
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Bars style
        WaveformVisualizationView(
            audioLevels: (0..<30).map { _ in Float.random(in: 0.1...0.9) },
            isRecording: true,
            isProcessing: false
        )
        .frame(height: 100)
        
        // Circular style
        AnimatedWaveformView(
            audioLevels: (0..<20).map { _ in Float.random(in: 0.1...0.9) },
            isRecording: true,
            isProcessing: false,
            style: .circular
        )
        .frame(height: 120)
        
        // Line style
        AnimatedWaveformView(
            audioLevels: (0..<50).map { _ in Float.random(in: 0.1...0.9) },
            isRecording: true,
            isProcessing: false,
            style: .line
        )
        .frame(height: 80)
        
        // Processing state
        WaveformVisualizationView(
            audioLevels: (0..<25).map { _ in Float.random(in: 0.3...0.7) },
            isRecording: false,
            isProcessing: true
        )
        .frame(height: 100)
    }
    .padding()
    .background(Color.black)
}